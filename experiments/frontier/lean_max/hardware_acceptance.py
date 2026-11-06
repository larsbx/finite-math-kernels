"""Fail-closed, local NVIDIA GPU conformance acceptance; never promotion.

This entry point creates fresh evidence itself. It accepts no uploaded report,
simulated runner, cached build or pre-existing profiler export as evidence.
See HARDWARE_ACCEPTANCE.md for commands, trust boundary and limitations.
"""
from __future__ import annotations

import argparse
from collections import Counter
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

from . import benchmark as bench
from . import gpu_bridge as gpu
from . import reference as ref
from . import trace_codec as codec
from .corpus import documents

ROOT = bench.ROOT
MODULE = "experiments.frontier.lean_max.hardware_acceptance"
CORPUS_SHA256 = "c21b0cb4215c490a825d7972db4efef3a176b8ecffff0ee7d84c535b0f891aa3"
MOJO_VERSION = "1.1.0.dev2026090805"
MODULAR_VERSION = "26.6.0.dev2026090805"


class Rejected(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def digest(path):
    h = sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def repository_snapshot(expected_revision):
    require(re.fullmatch(r"[0-9a-f]{40}", expected_revision) is not None,
            "--expected-revision must be a full reviewed commit SHA")
    def git(*args):
        return subprocess.check_output(["git", "-C", str(ROOT), *args])
    revision = git("rev-parse", "HEAD").decode().strip()
    require(revision == expected_revision, "checkout does not match expected revision")
    require(not git("status", "--porcelain", "--untracked-files=all"), "checkout is dirty or has untracked files")
    paths = [p.decode() for p in git("ls-files", "-z").split(b"\0") if p]
    require(paths, "empty source inventory")
    return {"revision": revision, "tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
            "source_sha256": {p: digest(ROOT / p) for p in paths}}


def executable(name):
    value = shutil.which(str(name))
    require(value is not None, f"required executable unavailable: {name}")
    path = Path(value).resolve()
    require(path.is_file() and os.access(path, os.X_OK), f"not an executable file: {path}")
    return path


def run_command(argv, directory, label, commands, *, timeout=60, env=None, allowed=(0,)):
    """Archive complete stdout/stderr and kill descendant processes on timeout."""
    out, err = directory / (label + ".stdout"), directory / (label + ".stderr")
    record = {"argv": list(map(str, argv)), "stdout": out.name, "stderr": err.name}
    commands.append(record)
    start = time.perf_counter_ns()
    with out.open("wb") as stdout, err.open("wb") as stderr:
        proc = subprocess.Popen(record["argv"], cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                                start_new_session=True)
        try:
            record["code"] = proc.wait(timeout=timeout)
        except BaseException:
            record["status"] = "interrupted_or_timeout"
            raise
        finally:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait()
            record["wall_ns"] = time.perf_counter_ns() - start
    require(record["code"] in allowed, f"{label} failed (exit {record['code']}); see archived logs")
    record["status"] = "ok"
    return out.read_text(errors="replace")


def validate_junit(path):
    cases = list(ET.parse(path).iter("testcase"))
    require(len(cases) >= 10, "hardware suite missing cases")
    require(not any(c.find(tag) is not None for c in cases for tag in ("skipped", "failure", "error")),
            "hardware suite contains skips, failures or errors")
    return {"cases": len(cases), "skips": 0, "failures": 0}


def validate_report(report, directory, repeats):
    """Recompute expectations and replay every retained byte, never trust totals."""
    corpus = documents()
    corpus_bytes = json.dumps(corpus, sort_keys=True, separators=(",", ":")).encode()
    require(len(corpus) == 34 and sha256(corpus_bytes).hexdigest() == CORPUS_SHA256,
            "acceptance corpus changed; review and version the acceptance policy")
    require(report["schema"] == "lean-max-comparison-v1" and report["corpus_sha256"] == CORPUS_SHA256,
            "comparison schema or corpus mismatch")
    require((directory / "corpus.json").read_bytes() == corpus_bytes, "retained corpus mismatch")
    require(report["budgets"]["max_records"] == 64 and report["budgets"]["max_rounds"] == 32,
            "acceptance budgets must be 64 records / 32 rounds")
    expected_keys = {(lane, case, repeat) for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind")
                     for case in range(34) for repeat in range(repeats)}
    rows = report["rows"]
    keys = [(r["lane"], r["case"], r["repeat"]) for r in rows]
    require(len(keys) == len(expected_keys) and set(keys) == expected_keys, "missing or duplicate comparison rows")
    proofs, controls, launches = 0, 0, Counter()
    gpu_proofs = 0
    for row in rows:
        lane, case, repeat = row["lane"], row["case"], row["repeat"]
        p = ref.Problem.parse(corpus[case])
        expected = ref.construct(p, max_records=64, max_rounds=32)
        require(expected["status"] in {"derived", "not_derived"}, "unexpected reference search refusal")
        require(type(row["end_to_end_ns"]) is int and row["end_to_end_ns"] > 0, "missing comparison timing")
        if lane == "lean_grind":
            status = "lean_baseline_accepted" if expected["status"] == "derived" else "lean_failed"
            require(row["status"] == status, "Lean grind comparison missing or inconsistent")
            check = row["verification"]
            require(check["status"] == ("accepted" if expected["status"] == "derived" else "lean_failed")
                    and check["code"] == (0 if expected["status"] == "derived" else 1),
                    "Lean grind checking evidence missing or inconsistent")
            continue
        require(row.get("result") == expected, f"{lane}/{case}/{repeat}: complete CPU result parity failed")
        if expected["status"] == "derived":
            require(row["status"] == "proof_accepted" and row["proof_accepted"] is True
                    and row["verification"]["status"] == "accepted" and row["verification"]["code"] == 0,
                    f"{lane}/{case}/{repeat}: missing Lean kernel acceptance")
            name = f"{lane}-{case}-{repeat}"
            wire = (directory / (name + ".trace")).read_bytes()
            require(sha256(wire).hexdigest() == row["trace_sha256"], "trace digest mismatch")
            decoded = codec.decode_trace(p, wire)
            ref.replay(p, decoded)
            require(wire == codec.encode_trace(p, expected), "noncanonical or inconsistent version-one trace")
            require((directory / (name + ".lean")).read_text() == ref.lean_source(p, decoded),
                    "Lean source does not bind complete replayed proof")
            proofs += 1
            if lane == "mojo_gpu" and row.get("device_launches", 0) > 0:
                gpu_proofs += 1
        else:
            require(row["status"] == "not_derived" and row["proof_accepted"] is False
                    and row["trace_sha256"] is None, "failed search was counted as a proof")
            controls += 1
        if lane == "mojo_gpu":
            observed = 0
            for metric in row["telemetry"]:
                require(metric.get("candidate_parity") is True and metric.get("launches") == 1,
                        "missing successful full candidate CPU parity or device launch")
                pid = metric["runner_pid"]
                require(type(pid) is int and 0 < pid < 2**24, "missing runner process identity")
                require(all(re.fullmatch(r"[0-9a-f]{64}", metric[k]) for k in ("input_sha256", "output_sha256")),
                        "missing input/output binding")
                launches[pid] += 1
                observed += 1
            require(row["device_launches"] == observed, "inconsistent device launch accounting")
            seed = gpu.construct(p, Path("unused"), enabled=True, max_rounds=0)
            require(seed["status"] == "derived" or observed > 0, "missing launches for a device-dependent search")
            require(row["gpu_assisted"] is (observed > 0), "inconsistent GPU-assisted classification")
    require(proofs == 28 * 3 * repeats and controls == 6 * 3 * repeats,
            "unexpected corpus proof/control coverage")
    require(gpu_proofs > 0 and launches, "no kernel-accepted construction actually used the GPU")
    return {"accepted_constructions": proofs, "expected_nonderived_controls": controls,
            "gpu_assisted_accepted_constructions": gpu_proofs}, launches


def normalize_uuid(value):
    require(isinstance(value, str), "missing GPU UUID")
    value = value.lower().removeprefix("gpu-").replace("-", "")
    require(re.fullmatch(r"[0-9a-f]{32}", value) is not None, "invalid or unsupported GPU UUID")
    return value


def validate_profile(path, expected_launches, gpu_uuid):
    """Nsight SQLite: match kernel/PID/CUDA-device UUID, not inventory alone.

    Required columns are deliberately explicit. Unsupported schemas fail closed.
    https://docs.nvidia.com/nsight-systems/AnalysisGuide/index.html
    """
    require(path.is_file(), "missing independent device profile")
    gpu_uuid = normalize_uuid(gpu_uuid)
    observed = Counter()
    events = []
    with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) as db:
        devices = list(db.execute("SELECT pid, cudaId, uuid FROM TARGET_INFO_CUDA_DEVICE"))
        rows = db.execute("""SELECT k.globalPid, k.deviceId, k.start, k.end, s.value
                             FROM CUPTI_ACTIVITY_KIND_KERNEL k
                             LEFT JOIN StringIds s ON k.demangledName = s.id""")
        for global_pid, device, start, end, name in rows:
            pid = (global_pid >> 24) & 0xFFFFFF
            if not isinstance(name, str) or "candidates_kernel" not in name:
                continue
            require(pid in expected_launches, "candidate kernel from an unbound process")
            matches = [uuid for proc, cuda, uuid in devices if proc == pid and cuda == device]
            require(len(matches) == 1 and normalize_uuid(matches[0]) == gpu_uuid,
                    "profiler device identity missing, ambiguous or different from approved UUID")
            require(type(start) is int and type(end) is int and 0 <= start < end,
                    "missing completed device kernel interval")
            observed[pid] += 1
            events.append({"runner_pid": pid, "cuda_device_id": device, "start_ns": start,
                           "end_ns": end, "kernel": name, "gpu_uuid": matches[0]})
    require(observed == expected_launches and sum(observed.values()) > 0,
            "independent device launches do not match runner/parity observations")
    return {"observer": "nsight-systems-cupti", "launches": sum(observed.values()), "events": events}


def accept(args):
    out = args.out.resolve()
    require(not out.is_relative_to(ROOT), "evidence directory must be outside the checkout")
    # Refuse reuse, including stale success receipts and profiler exports.
    out.mkdir(parents=True, exist_ok=False)
    receipt_path = out / "hardware-acceptance.json"
    receipt = {"schema": "lean-max-hardware-acceptance-v1", "accepted": False, "status": "incomplete",
               "authority": "bounded_hardware_conformance_only_no_promotion_or_speedup_claim",
               "requested_revision": args.expected_revision, "requested_gpu_uuid": args.gpu_uuid,
               "commands": [], "started_unix_ns": time.time_ns()}
    write_json(receipt_path, receipt)
    try:
        before = repository_snapshot(args.expected_revision)
        receipt["repository"] = before
        require(args.gpu_runner is not None, "hardware acceptance requires explicit --gpu-runner build destination")
        gpu_runner = args.gpu_runner.resolve()
        require(gpu_runner.is_relative_to(out) and not gpu_runner.exists(),
                "GPU runner must be a fresh build destination inside the new evidence directory")
        require(2 <= args.repeats <= 10, "acceptance requires 2..10 complete repetitions")
        normalize_uuid(args.gpu_uuid)
        names = {"mojo": args.mojo, "lean": args.lean, "nsys": args.nsys,
                 "nvidia-smi": "nvidia-smi", "pixi": "pixi", "python": sys.executable}
        tools = {key: executable(value) for key, value in names.items()}
        tool_hashes = {key: digest(path) for key, path in tools.items()}
        receipt["tools"] = {key: {"path": str(path), "sha256": tool_hashes[key]} for key, path in tools.items()}
        def run(argv, label, **kwargs):
            return run_command(argv, out, label, receipt["commands"], **kwargs)
        versions = {key: run([tools[key], "--version"], key + "-version") for key in ("mojo", "lean", "nsys", "pixi")}
        receipt["versions"] = versions
        require(re.search(r"(?<![\w.])" + re.escape(MOJO_VERSION) + r"(?![\w.])", versions["mojo"]), "Mojo version mismatch")
        require(re.search(r"\bversion 4\.35\.0(?:,|\s|\))", versions["lean"]), "Lean version mismatch")
        packages = json.loads(run([tools["pixi"], "list", "--json"], "pixi-packages"))
        for name, version in (("modular", MODULAR_VERSION), ("max", MODULAR_VERSION), ("mojo", MOJO_VERSION)):
            require(any(p["name"] == name and p["version"] == version for p in packages), f"installed {name} pin mismatch")
        inventory = run([tools["nvidia-smi"], "--query-gpu=name,uuid,driver_version,memory.total", "--format=csv,noheader"], "gpu-inventory")
        require(any(normalize_uuid(line.split(",")[1].strip()) == normalize_uuid(args.gpu_uuid)
                    for line in inventory.splitlines() if len(line.split(",")) == 4), "approved GPU unavailable")
        receipt["hardware_inventory"] = inventory
        negative = out / "Invalid.lean"
        negative.write_text("example : False := by\n  exact True.intro\n")
        diagnostic = run([tools["lean"], negative], "lean-negative-control", allowed=(1,))
        diagnostic += (out / "lean-negative-control.stderr").read_text(errors="replace")
        require("error:" in diagnostic.lower(), "Lean negative control lacked a checker diagnostic")
        cpu_runner = out / "mojo_cpu"
        for lane, source, target in (("cpu", "candidates.mojo", cpu_runner), ("gpu", "gpu_candidates.mojo", gpu_runner)):
            run([tools["mojo"], "build", "-O3", ROOT / "experiments/frontier/lean_max/mojo" / source, "-o", target],
                lane + "-build", timeout=600)
            require(target.is_file() and os.access(target, os.X_OK), f"{lane} build produced no executable")
        binary_hashes = {"cpu": digest(cpu_runner), "gpu": digest(gpu_runner)}
        receipt["runner_sha256"] = binary_hashes
        environment = dict(os.environ, LEAN_MAX_GPU_RUNNER=str(gpu_runner), LEAN_MAX_GPU_REQUIRED="1",
                           CUDA_VISIBLE_DEVICES=args.gpu_uuid)
        run([tools["python"], "-m", "pytest", "-q", "tests/frontier/test_lean_max_gpu_hardware.py",
             "--junitxml=" + str(out / "hardware-tests.xml")], "hardware-tests", env=environment, timeout=1800)
        receipt["hardware_suite"] = validate_junit(out / "hardware-tests.xml")
        comparison = out / "comparison"
        run([tools["nsys"], "profile", "--trace=cuda", "--sample=none", "--cpuctxsw=none",
             "--wait=all", "--output=" + str(out / "device"), tools["python"], "-m", bench.MODULE,
             "--enable-gpu", "--cpu-runner", cpu_runner, "--gpu-runner", gpu_runner,
             "--mojo", tools["mojo"], "--lean", tools["lean"], "--repeats", str(args.repeats),
             "--out", comparison], "profiled-comparison", env=environment, timeout=3600)
        report = json.loads((comparison / "report.json").read_text())
        metadata = report["metadata"]
        require(metadata["repository_revision"]["status"] == "ok"
                and metadata["repository_revision"]["stdout"].strip() == args.expected_revision
                and metadata["working_tree"]["status"] == "ok" and not metadata["working_tree"]["stdout"],
                "comparison revision/working tree binding failed")
        require(metadata["runner_sha256"] == {"mojo_cpu": binary_hashes["cpu"], "mojo_gpu": binary_hashes["gpu"]},
                "comparison runner binding failed")
        require(metadata["lean_negative_control"]["status"] == "failed"
                and metadata["lean_negative_control"]["code"] == 1, "comparison Lean negative control failed")
        receipt["coverage"], launches = validate_report(report, comparison, args.repeats)
        run([tools["nsys"], "export", "--type=sqlite", "--output=" + str(out / "device.sqlite"),
             out / "device.nsys-rep"], "profile-export", timeout=300)
        receipt["device_observations"] = validate_profile(out / "device.sqlite", launches, args.gpu_uuid)
        require(repository_snapshot(args.expected_revision) == before, "repository changed during acceptance")
        require({"cpu": digest(cpu_runner), "gpu": digest(gpu_runner)} == binary_hashes, "runner changed during acceptance")
        require({key: digest(path) for key, path in tools.items()} == tool_hashes, "tool executable changed during acceptance")
        receipt.update(accepted=True, status="accepted")
    except (Exception, KeyboardInterrupt) as exc:
        receipt.update(accepted=False, status="rejected", error=f"{type(exc).__name__}: {exc}")
    finally:
        receipt["finished_unix_ns"] = time.time_ns()
        # The receipt binds every retained log, source, trace, binary and profile.
        receipt["artifact_sha256"] = {str(p.relative_to(out)): digest(p) for p in sorted(out.rglob("*"))
                                     if p.is_file() and p != receipt_path}
        write_json(receipt_path, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-revision", required=True)
    parser.add_argument("--gpu-uuid", required=True)
    parser.add_argument("--gpu-runner", type=Path, help="explicit destination for a fresh build; mandatory for acceptance")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--mojo", default="mojo")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--nsys", default="nsys")
    args = parser.parse_args()
    try:
        receipt = accept(args)
    except (OSError, Rejected) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps({key: receipt[key] for key in ("accepted", "status")}))
    return 0 if receipt["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
