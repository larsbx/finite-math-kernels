"""Fail-closed, local NVIDIA GPU conformance acceptance, never promotion.

Offline tests may simulate dependencies; only this CLI writes hardware receipts.
Run --help for the required explicit revision, runner destinations and tools.
"""
from __future__ import annotations

import argparse
from hashlib import sha1, sha256
import json
import os
from pathlib import Path
import re
import signal
import sqlite3
import stat
import subprocess
import sys
import time
from types import SimpleNamespace

from . import benchmark as bench
from . import cpu_bridge as cpu
from . import gpu_bridge as gpu
from . import reference as ref
from . import trace_codec as codec
from .corpus import documents

ROOT = bench.ROOT
MODULE = "experiments.frontier.lean_max.hardware_acceptance"
CORPUS_HASH = "c21b0cb4215c490a825d7972db4efef3a176b8ecffff0ee7d84c535b0f891aa3"
MOJO_VERSION = "1.1.0.dev2026090805"
MODULAR_VERSION = "26.6.0.dev2026090805"
REPEATS = 3


class Rejected(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def digest(path):
    return sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def checked(argv, timeout=60):
    """Trusted local tools; kill descendants on timeout or interruption."""
    start = time.perf_counter_ns()
    proc = subprocess.Popen([str(x) for x in argv], cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, start_new_session=True)
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return {"command": [str(x) for x in argv], "code": proc.returncode,
                "status": "ok" if proc.returncode == 0 else "failed",
                "stdout": stdout.decode(errors="replace"), "stderr": stderr.decode(errors="replace"),
                "wall_ns": time.perf_counter_ns() - start}
    finally:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
        proc.stdout.close()
        proc.stderr.close()


def snapshot(expected_revision, root=ROOT):
    """Verify actual bytes against HEAD, including assume-unchanged files."""
    require(re.fullmatch(r"[0-9a-f]{40}", expected_revision) is not None, "full expected revision required")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root).decode().strip()
    require(head == expected_revision, "repository revision mismatch")
    require(not subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=all"], cwd=root),
            "clean checkout required (including untracked files)")
    manifest = {}
    for entry in subprocess.check_output(["git", "ls-tree", "-rz", "--full-tree", "HEAD"], cwd=root).split(b"\0"):
        if not entry:
            continue
        header, raw_path = entry.split(b"\t", 1)
        mode, kind, blob = header.decode().split()
        name = raw_path.decode()
        path = root / name
        require(kind == "blob" and mode in {"100644", "100755"} and stat.S_ISREG(path.lstat().st_mode),
                f"unsupported source entry: {name}")
        data = path.read_bytes()
        require(sha1(b"blob %d\0" % len(data) + data).hexdigest() == blob, f"source differs from HEAD: {name}")
        require(bool(path.stat().st_mode & 0o111) == (mode == "100755"), f"source mode differs: {name}")
        manifest[name] = sha256(data).hexdigest()
    return {"revision": head, "source_sha256": manifest}


def corpus():
    docs = documents()
    raw = json.dumps(docs, sort_keys=True, separators=(",", ":")).encode()
    require(len(docs) == 34 and sha256(raw).hexdigest() == CORPUS_HASH, "fixed corpus changed")
    return docs, raw


def package_versions():
    """Use Pixi's installed Conda records; metapackages need not have dist-info."""
    names = {"modular", "max", "max-core", "max-serve", "max-benchmark", "mblack",
             "mojo", "mojo-compiler", "mojo-python"}
    records = {}
    for path in (Path(sys.prefix) / "conda-meta").glob("*.json"):
        record = json.loads(path.read_text())
        if record.get("name") in names:
            require(record["name"] not in records, "duplicate installed package record")
            records[record["name"]] = {"version": record["version"], "build": record["build"],
                                      "record_sha256": digest(path)}
    require(set(records) == names, "pinned Pixi package records unavailable")
    require(all(r["version"] == (MOJO_VERSION if name.startswith("mojo") else MODULAR_VERSION)
                for name, r in records.items()), "Modular/MAX package version mismatch")
    return records


def inventory(smi):
    result = checked([smi, "--query-gpu=name,uuid,driver_version,memory.total", "--format=csv,noheader,nounits"])
    require(result["status"] == "ok", "accelerator inventory unavailable")
    rows = [r.split(",") for r in result["stdout"].strip().splitlines()]
    require(len(rows) == 1 and len(rows[0]) == 4 and all(x.strip() for x in rows[0]),
            "acceptance requires one physical NVIDIA GPU; multi-GPU/MIG hosts need a separate adapter")
    name, uuid, driver, memory = [x.strip() for x in rows[0]]
    require(uuid.startswith("GPU-") and memory.isdecimal() and int(memory) > 0, "invalid hardware identity")
    return {"name": name, "uuid": uuid, "driver": driver, "memory_mib": int(memory), "query": result}


def observed_kernels(path, hardware):
    """Read actual CUDA device activity, not runner-reported launch counters.

    Unknown Nsight schema, zero-duration events and unrelated kernels refuse.
    Raw .nsys-rep and SQLite exports remain available for independent review.
    """
    require(path.is_file(), "missing profiler SQLite export")
    with sqlite3.connect(f"{path.as_uri()}?mode=ro", uri=True) as db:
        rows = db.execute("""SELECT k.start, k.end, k.deviceId, k.correlationId, s.value
            FROM CUPTI_ACTIVITY_KIND_KERNEL k JOIN StringIds s ON k.demangledName=s.id
            ORDER BY k.start, k.correlationId""").fetchall()
        total = db.execute("SELECT count(*) FROM CUPTI_ACTIVITY_KIND_KERNEL").fetchone()[0]
        devices = [dict(zip(("id", "name", "uuid"), row)) for row in
                   db.execute("SELECT id, name, uuid FROM TARGET_INFO_GPU").fetchall()]
    require(rows and len(rows) == total, "no complete device-launch observations")
    require(all(type(a) is int and type(b) is int and b > a and type(d) is int
                and type(c) is int and c > 0 and "candidates_kernel" in name for a, b, d, c, name in rows),
            "invalid, unrelated or uncorrelated device activity")
    require(len({r[2] for r in rows}) == 1 and devices, "missing or inconsistent profiler device identity")
    def uuid(value):
        return value.removeprefix("GPU-").replace("-", "").lower()
    require(all(isinstance(d["uuid"], str) and uuid(d["uuid"]) == uuid(hardware["uuid"])
                and d["name"] == hardware["name"] for d in devices), "profiler GPU UUID mismatch")
    return {"launches": len(rows), "events": [dict(zip(
        ("start_ns", "end_ns", "device_id", "correlation_id", "kernel"), row)) for row in rows],
        "profiler_devices": devices}


def probe_worker(request_path):
    """Runs only as a child of the local profiler; never writes an acceptance receipt."""
    def deadline(signum, frame):
        raise TimeoutError("profiled worker deadline")
    signal.signal(signal.SIGALRM, deadline)
    signal.signal(signal.SIGTERM, deadline)
    signal.alarm(110)
    request = json.loads(request_path.read_text())
    p = ref.Problem.parse(request["problem"])
    directory = request_path.parent
    calls = []
    telemetry = []

    def reader(problem, steps, runner, **kwargs):
        name = f"call-{len(calls)}"
        write_json(directory / (name + ".json"), [s.json() for s in steps])
        result = gpu.read_candidates(problem, steps, runner, output_path=directory / (name + ".stdout"), **kwargs)
        calls.append(name)
        return result

    runner = Path(request["runner"])
    # A mandatory nonempty probe makes seed-only goals exercise real device work.
    seeds = [ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(p.premises)]
    seeds += [ref.Step(i, i, "refl") for i in range(len(p.terms))]
    reader(p, seeds, runner, enabled=True, telemetry=telemetry)
    result = gpu.construct(p, runner, enabled=True, telemetry=telemetry, candidate_reader=reader)
    write_json(directory / "result.json", {"result": result, "calls": calls, "telemetry": telemetry})


def validate_probe(directory, doc, hardware):
    p = ref.Problem.parse(doc)
    result = json.loads((directory / "result.json").read_text())
    calls = result["calls"]
    require(calls and calls == [f"call-{i}" for i in range(len(calls))], "incomplete candidate call log")
    require(len(result["telemetry"]) == len(calls), "incomplete device telemetry")
    launches = 0
    for name, recorded in zip(calls, result["telemetry"]):
        raw_steps = json.loads((directory / (name + ".json")).read_text())
        steps = [ref.Step(**{**s, "refs": tuple(s["refs"])}) for s in raw_steps]
        _, metrics = gpu.parse_output(p, steps, (directory / (name + ".stdout")).read_bytes())
        require(all(recorded[k] == v for k, v in metrics.items()), "candidate telemetry divergence")
        require(metrics["device"] == hardware["name"] and metrics["launches"] == 1, "missing launch or device mismatch")
        launches += metrics["launches"]
    expected = ref.construct(p, max_records=64, max_rounds=32)
    require(result["result"] == expected, "GPU full-search CPU parity failed")
    if expected["status"] == "derived":
        wire = codec.encode_trace(p, result["result"])
        require(wire == codec.encode_trace(p, expected), "GPU canonical trace divergence")
        codec.decode_trace(p, wire)  # replays every record, including unused records
        (directory / "proof.trace").write_bytes(wire)
    observed = observed_kernels(directory / "profile.sqlite", hardware)
    require(observed["launches"] == launches, "profiler and candidate launch counts disagree")
    write_json(directory / "observations.json", observed)
    return {"status": expected["status"], "launches": launches, "device": hardware["name"],
            "trace_sha256": digest(directory / "proof.trace") if expected["status"] == "derived" else None}


def validate_comparison(report, directory, docs):
    """No counts-only or partial-corpus acceptance; re-open every retained trace."""
    require(report["schema"] == "lean-max-comparison-v1" and report["corpus_sha256"] == CORPUS_HASH,
            "comparison corpus mismatch")
    require(report["budgets"]["max_records"] == 64 and report["budgets"]["max_rounds"] == 32,
            "comparison budget mismatch")
    rows = report["rows"]
    expected_keys = {(lane, case, repeat) for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind")
                     for case in range(34) for repeat in range(REPEATS)}
    require(len(rows) == len(expected_keys) and {(r["lane"], r["case"], r["repeat"]) for r in rows} == expected_keys,
            "comparison rows missing or duplicated")
    trace_digests = {}
    for row in rows:
        p = ref.Problem.parse(docs[row["case"]])
        expected = ref.construct(p, max_records=64, max_rounds=32)
        if row["lane"] == "mojo_gpu":
            seeds = set(p.premises) | {(i, i) for i in range(len(p.terms))}
            if p.goal not in seeds:
                require(row.get("telemetry") and row.get("device_launches", 0) > 0,
                        "GPU construction has no launches")
        if row["lane"] == "lean_grind":
            if expected["status"] == "derived":
                require(row["status"] == "lean_baseline_accepted", "missing Lean baseline acceptance")
            else:
                require(row["status"] in {"lean_failed", "lean_baseline_accepted"}, "Lean baseline unavailable or timed out")
            continue
        if expected["status"] != "derived":
            require(row["status"] == expected["status"] and row.get("result") == expected
                    and row["proof_accepted"] is False, "unsuccessful-search parity failed")
            continue
        require(row["status"] == "proof_accepted" and row["proof_accepted"] is True
                and row["verification"]["status"] == "accepted" and row["verification"]["code"] == 0,
                "missing Lean kernel acceptance")
        name = f'{row["lane"]}-{row["case"]}-{row["repeat"]}'
        wire = (directory / (name + ".trace")).read_bytes()
        require(wire == codec.encode_trace(p, expected) and sha256(wire).hexdigest() == row["trace_sha256"],
                "inconsistent retained trace")
        codec.decode_trace(p, wire)
        require((directory / (name + ".lean")).read_text() == ref.lean_source(p, codec.decode_trace(p, wire)),
                "Lean source is not reconstructed from the complete trace")
        key = row["case"]
        previous = trace_digests.setdefault(key, row["trace_sha256"])
        require(previous == row["trace_sha256"], "nondeterministic candidate output")
    require(len(trace_digests) == 28, "fixed corpus must retain all 28 derived constructions")
    return trace_digests


def preflight(args, evidence):
    require(args.gpu_runner is not None, "explicit --gpu-runner destination required")
    require(args.cpu_runner is not None, "explicit --cpu-runner destination required")
    require(args.gpu_runner != args.cpu_runner, "CPU/GPU destinations must differ")
    for path in (args.gpu_runner, args.cpu_runner):
        require(path.parent == args.out, "runner destinations must be inside the fresh output directory")
    evidence["source"] = snapshot(args.expected_revision)
    versions = {}
    for name in ("mojo", "lean", "nsys"):
        versions[name] = checked([getattr(args, name), "--version"])
        require(versions[name]["status"] == "ok", f"{name} unavailable")
    require(re.search(r"(?<![\w.])" + re.escape(MOJO_VERSION) + r"(?![\w.])", versions["mojo"]["stdout"]), "Mojo version mismatch")
    require(re.search(r"\bversion 4\.35\.0(?:,|\s|\))", versions["lean"]["stdout"]), "Lean version mismatch")
    # MAX packages live in the same Pixi environment, independently of the Mojo CLI.
    versions["modular_packages"] = package_versions()
    evidence["versions"] = versions
    evidence["hardware"] = inventory(args.smi)
    # Resolve the actual executables once; pin their bytes through completion.
    import shutil
    # Preserve argv[0] for dispatching shims such as elan's `lean` symlink.
    paths = {name: Path(shutil.which(getattr(args, name)) or "").absolute() for name in ("mojo", "lean", "nsys", "smi")}
    paths["python"] = Path(sys.executable).absolute()
    evidence["tools"] = {name: {"path": str(path), "realpath": str(path.resolve()), "sha256": digest(path)}
                         for name, path in paths.items()}
    prefix = checked([str(paths["lean"]), "--print-prefix"])
    require(prefix["status"] == "ok", "Lean toolchain prefix unavailable")
    kernel = Path(prefix["stdout"].strip()) / "bin" / "lean"
    require(kernel.is_absolute() and kernel.is_file(), "Lean toolchain binary unavailable")
    evidence["tools"]["lean_kernel_executable"] = {
        "path": str(kernel), "realpath": str(kernel.resolve()), "sha256": digest(kernel)}
    for name, path in paths.items():
        if name != "python":
            setattr(args, name, str(path))
    positive = args.out / "Positive.lean"
    positive.write_text("example : True := True.intro\n")
    negative = args.out / "Negative.lean"
    negative.write_text("example : False := by\n  exact True.intro\n")
    evidence["lean_positive_control"] = checked([args.lean, positive], timeout=30)
    evidence["lean_negative_control"] = checked([args.lean, negative], timeout=30)
    require(evidence["lean_positive_control"]["code"] == 0 and evidence["lean_negative_control"]["code"] == 1,
            "Lean positive/negative control failed")
    evidence["builds"] = {}
    for lane, source, target in (("mojo_cpu", "candidates.mojo", args.cpu_runner),
                                  ("mojo_gpu", "gpu_candidates.mojo", args.gpu_runner)):
        build = checked([args.mojo, "build", "-O3", Path(__file__).parent / "mojo" / source, "-o", target], timeout=600)
        evidence["builds"][lane] = build
        require(build["status"] == "ok" and target.is_file() and os.access(target, os.X_OK), f"{lane} compiler failure or missing binary")
    evidence["runner_sha256"] = {"mojo_cpu": digest(args.cpu_runner), "mojo_gpu": digest(args.gpu_runner)}


def execute(args, evidence):
    preflight(args, evidence)
    docs, raw = corpus()
    (args.out / "corpus.json").write_bytes(raw)
    evidence["profiled_cases"] = []
    for repeat in range(REPEATS):
        for case, doc in enumerate(docs):
            directory = args.out / f"device-{case}-{repeat}"
            directory.mkdir()
            request = directory / "request.json"
            write_json(request, {"problem": doc, "runner": str(args.gpu_runner)})
            profile = checked([args.nsys, "profile", "--trace=cuda", "--sample=none", "--cpuctxsw=none",
                               "--output=" + str(directory / "profile"), sys.executable, "-m", MODULE,
                               "--probe", request], timeout=120)
            write_json(directory / "profile-command.json", profile)
            require(profile["status"] == "ok", "GPU/profiler execution failed")
            require((directory / "profile.nsys-rep").is_file(), "missing raw profiler report")
            exported = checked([args.nsys, "export", "--type=sqlite", "--output=" + str(directory / "profile.sqlite"),
                                directory / "profile.nsys-rep"], timeout=120)
            write_json(directory / "export-command.json", exported)
            require(exported["status"] == "ok", "profiler export failed")
            summary = validate_probe(directory, doc, evidence["hardware"])
            p = ref.Problem.parse(doc)
            if summary["status"] == "derived":
                decoded = codec.decode_trace(p, (directory / "proof.trace").read_bytes())
                checked_proof = bench.lean_check(ref.lean_source(p, decoded), args.lean,
                    evidence["versions"]["lean"], directory, "proof")
                write_json(directory / "lean-check.json", checked_proof)
                require(checked_proof["status"] == "accepted", "profiled proof missing Lean kernel acceptance")
            evidence["profiled_cases"].append({"case": case, "repeat": repeat, **summary})
            print(f"device corpus {repeat + 1}/{REPEATS}: {case + 1}/34", flush=True)
    comparison_dir = args.out / "comparison"
    report = bench.run(SimpleNamespace(out=comparison_dir, lean=args.lean, mojo=args.mojo, build=False,
        enable_gpu=True, cpu_runner=args.cpu_runner, gpu_runner=args.gpu_runner, repeats=REPEATS, records=64, rounds=32))
    evidence["derived_trace_sha256"] = validate_comparison(report, comparison_dir, docs)
    require(snapshot(args.expected_revision) == evidence["source"], "source changed during acceptance")
    evidence["final_hardware"] = inventory(args.smi)
    require(all(evidence["final_hardware"][k] == evidence["hardware"][k]
                for k in ("name", "uuid", "driver", "memory_mib")), "hardware identity changed during acceptance")
    for tool in evidence["tools"].values():
        require(str(Path(tool["path"]).resolve()) == tool["realpath"] and digest(tool["path"]) == tool["sha256"],
                "tool changed during acceptance")
    require(package_versions() == evidence["versions"]["modular_packages"], "toolchain packages changed during acceptance")
    for name, path in (("mojo_cpu", args.cpu_runner), ("mojo_gpu", args.gpu_runner)):
        require(digest(path) == evidence["runner_sha256"][name], "runner changed during acceptance")
    evidence["comparison_summary"] = report["summary"]


def run(args):
    # A fresh outside-repository directory prevents stale accepted receipts.
    require(not args.out.is_relative_to(ROOT), "output must be outside the repository")
    args.out.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "lean-max-gpu-hardware-acceptance-v1", "status": "rejected", "accepted": False,
               "authority": "local_hardware_conformance_only_no_promotion_or_speedup_claim",
               "corpus_sha256": CORPUS_HASH, "expected_revision": args.expected_revision,
               "repeats": REPEATS, "evidence": {}}
    try:
        execute(args, receipt["evidence"])
        receipt.update(status="accepted", accepted=True)
    except (Exception, KeyboardInterrupt) as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
    # Bind every raw profile, command, trace, Lean source and check log.
    receipt["artifact_sha256"] = {str(p.relative_to(args.out)): digest(p) for p in sorted(args.out.rglob("*")) if p.is_file()}
    write_json(args.out / "hardware-receipt.json", receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--expected-revision")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--gpu-runner", type=Path, help="explicit output path for a mandatory fresh source build")
    parser.add_argument("--cpu-runner", type=Path, help="explicit output path for a mandatory fresh source build")
    parser.add_argument("--mojo", default="mojo")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--nsys", default="nsys")
    parser.add_argument("--smi", default="nvidia-smi")
    args = parser.parse_args()
    if args.probe:
        probe_worker(args.probe.resolve())
        return 0
    if args.out is None or args.expected_revision is None:
        parser.error("--out and --expected-revision are required")
    for name in ("out", "gpu_runner", "cpu_runner"):
        value = getattr(args, name)
        if value is not None:
            setattr(args, name, value.resolve())
    try:
        receipt = run(args)
    except (OSError, Rejected) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps({"status": receipt["status"], "error": receipt.get("error"),
                      "receipt": str(args.out / "hardware-receipt.json")}))
    return 0 if receipt["accepted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
