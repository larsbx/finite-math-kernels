"""Standalone opt-in conformance comparison; no Frontier registry changes.

Only replayed, trace-decoded, pinned-Lean-accepted constructions are successes.
Includes parity overhead and process startup. This is not a speedup benchmark.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
import math
import os
from pathlib import Path
import platform
import resource
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time

from . import cpu_bridge as cpu
from . import gpu_bridge as gpu
from . import reference as ref
from . import trace_codec as codec
from .corpus import documents

ROOT = Path(__file__).resolve().parents[3]
PINNED_LEAN = "4.35.0"
MODULE = "experiments.frontier.lean_max.benchmark"


def command(argv, timeout=60):
    start = time.perf_counter_ns()
    try:
        result = subprocess.run(argv, capture_output=True, timeout=timeout)
        return {"status": "ok" if result.returncode == 0 else "failed", "code": result.returncode,
                "wall_ns": time.perf_counter_ns() - start,
                "stdout": result.stdout.decode(errors="replace"), "stderr": result.stderr.decode(errors="replace")}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"status": "unavailable" if isinstance(exc, OSError) else "timeout",
                "wall_ns": time.perf_counter_ns() - start, "error": str(exc)}


def grind_source(problem: ref.Problem) -> str:
    # Reuse only the theorem statement. Grind constructs its own proof.
    dummy = ref.construct(ref.Problem(problem.atoms, problem.functions, problem.terms, problem.premises, (0, 0)))
    header = ref.lean_source(problem=ref.Problem(problem.atoms, problem.functions, problem.terms, problem.premises, (0, 0)), result=dummy)
    # Replace only the goal line; terms use the same restricted DAG renderer.
    def term(i):
        t = problem.terms[i]
        return t.name if t.kind == "atom" else f"({t.name} {term(t.child)})"
    lines = header.splitlines()
    end = next(i for i, line in enumerate(lines) if line.endswith(":= by"))
    lines[end] = f"    : {term(problem.goal[0])} = {term(problem.goal[1])} := by"
    return "set_option maxHeartbeats 100000\nset_option maxRecDepth 1024\n" + "\n".join(lines[:end + 1]) + "\n  grind\n"


def lean_check(source: str, lean: str | None, version: dict, directory: Path, name: str) -> dict:
    path = directory / (name + ".lean")
    path.write_text(source)
    if version["status"] == "negative_control_failed":
        return {"status": "lean_negative_control_failed", "wall_ns": None}
    if not lean or version["status"] != "ok":
        return {"status": "lean_unavailable", "wall_ns": None}
    if not re.search(r"\bversion 4\.35\.0(?:,|\s|\))", version["stdout"]):
        return {"status": "lean_version_mismatch", "wall_ns": None}
    result = command([lean, str(path)], timeout=30)
    return {**result, "status": "accepted" if result["status"] == "ok" else "lean_" + result["status"]}


def worker():
    request = json.load(sys.stdin)
    p = ref.Problem.parse(request["problem"])
    telemetry = []
    # Let the bridge's finally block kill an active device driver before the
    # outer 40-second worker deadline. A killed parent must not orphan a launch.
    def deadline(signum, frame):
        raise TimeoutError("construction worker deadline")
    signal.signal(signal.SIGALRM, deadline)
    signal.alarm(38)
    start = time.perf_counter_ns()
    try:
        if request["lane"] == "python":
            result = ref.construct(p, max_records=request["records"], max_rounds=request["rounds"])
        elif request["lane"] == "mojo_cpu":
            result = cpu.construct_with_mojo(p, Path(request["runner"]), max_records=request["records"], max_rounds=request["rounds"])
        else:
            result = gpu.construct(p, Path(request["runner"]), enabled=True, max_records=request["records"],
                                   max_rounds=request["rounds"], telemetry=telemetry)
        payload = {"result": result, "status": "ran"}
    except Exception as exc:
        payload = {"status": "construction_error", "error": str(exc)}
    finally:
        signal.alarm(0)
    payload.update(construction_ns=time.perf_counter_ns() - start, telemetry=telemetry,
                   peak_host_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                   child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
    print(json.dumps(payload, sort_keys=True))


def build_runner(mojo: str, source: str, out: Path) -> dict:
    argv = [mojo, "build", "-O3", str(Path(__file__).parent / "mojo" / source), "-o", str(out)]
    return {"command": argv, **command(argv, timeout=600)}


def run(args) -> dict:
    args.out.mkdir(parents=True, exist_ok=True)
    corpus = documents()
    corpus_bytes = json.dumps(corpus, sort_keys=True, separators=(",", ":")).encode()
    (args.out / "corpus.json").write_bytes(corpus_bytes)
    lean = shutil.which(args.lean)
    lean_version = command([args.lean, "--version"])
    negative = args.out / "Invalid.lean"
    negative.write_text("example : False := by\n  exact True.intro\n")
    negative_check = command([args.lean, str(negative)])
    if negative_check["status"] == "ok":
        lean_version["status"] = "negative_control_failed"
    builds = {}
    runners = {"mojo_cpu": args.cpu_runner, "mojo_gpu": args.gpu_runner}
    if args.build:
        for lane, source in (("mojo_cpu", "candidates.mojo"), ("mojo_gpu", "gpu_candidates.mojo")):
            if lane == "mojo_gpu" and not args.enable_gpu:
                continue
            output = (args.out / lane).resolve()
            builds[lane] = build_runner(args.mojo, source, output)
            runners[lane] = output if builds[lane]["status"] == "ok" else None
    metadata = {
        "source_sha256": {str(p.relative_to(ROOT)): sha256(p.read_bytes()).hexdigest()
                          for p in sorted(Path(__file__).parent.rglob("*")) if p.suffix in {".py", ".mojo"}},
        "repository_revision": command(["git", "rev-parse", "HEAD"]),
        "working_tree": command(["git", "status", "--porcelain"]),
        "compiler_versions": {"python": sys.version, "mojo": command([args.mojo, "--version"]), "lean": lean_version},
        "hardware": {"platform": platform.platform(), "cpu": platform.processor(), "logical_cpus": os.cpu_count(),
                     "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
                     "nvidia": command(["nvidia-smi", "--query-gpu=name,uuid,driver_version,memory.total", "--format=csv"]),
                     "amd": command(["rocm-smi", "--showproductname", "--showdriverversion", "--showmeminfo", "vram"])},
        "builds": builds, "lean_negative_control": negative_check,
        "runner_sha256": {lane: sha256(p.read_bytes()).hexdigest() if p and p.is_file() else None for lane, p in runners.items()},
    }
    rows = []
    digests = {}
    for repeat in range(args.repeats):
        for case, doc in enumerate(corpus):
            p = ref.Problem.parse(doc)
            expected = ref.construct(p, max_records=args.records, max_rounds=args.rounds)
            for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind"):
                row = {"lane": lane, "case": case, "repeat": repeat, "status": None,
                       "proof_accepted": False, "end_to_end_ns": None, "trace_sha256": None}
                name = f"{lane}-{case}-{repeat}"
                start = time.perf_counter_ns()
                if lane == "lean_grind":
                    checked = lean_check(grind_source(p), lean, lean_version, args.out, name)
                    row.update(status="lean_baseline_accepted" if checked["status"] == "accepted" else checked["status"], verification=checked)
                    row["end_to_end_ns"] = time.perf_counter_ns() - start
                elif lane == "mojo_gpu" and not args.enable_gpu:
                    row["status"] = "disabled"
                elif lane != "python" and not runners[lane]:
                    row["status"] = "build_failed" if lane in builds and builds[lane]["status"] == "failed" else "no_runner"
                else:
                    request = {"problem": doc, "lane": lane, "runner": str(runners.get(lane) or ""),
                               "records": args.records, "rounds": args.rounds}
                    with tempfile.TemporaryFile() as stdin, tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
                        stdin.write(json.dumps(request).encode()); stdin.seek(0)
                        try:
                            subprocess.run([sys.executable, "-m", MODULE, "--worker"], stdin=stdin, stdout=stdout,
                                           stderr=stderr, check=True, timeout=40, cwd=ROOT)
                            stdout.seek(0)
                            data = json.load(stdout)
                            row.update(data)
                            row["device_launches"] = sum(m["launches"] for m in data.get("telemetry", []))
                            row["gpu_assisted"] = lane == "mojo_gpu" and row["device_launches"] > 0
                            result = data.get("result")
                            if result:
                                if result["status"] != expected["status"]:
                                    raise ref.InvalidProblem("reference outcome divergence")
                                row["status"] = result["status"]
                                if result["status"] == "derived":
                                    verify_start = time.perf_counter_ns()
                                    wire = codec.encode_trace(p, result)
                                    if wire != codec.encode_trace(p, expected):
                                        raise ref.InvalidProblem("reference trace divergence")
                                    decoded = codec.decode_trace(p, wire)
                                    row["trace_sha256"] = sha256(wire).hexdigest()
                                    previous = digests.setdefault((lane, case), row["trace_sha256"])
                                    if previous != row["trace_sha256"]:
                                        raise ref.InvalidProblem("nondeterministic trace")
                                    (args.out / (name + ".trace")).write_bytes(wire)
                                    source = ref.lean_source(p, decoded)
                                    row["replay_and_reconstruction_ns"] = time.perf_counter_ns() - verify_start
                                    checked = lean_check(source, lean, lean_version, args.out, name)
                                    row.update(status="proof_accepted" if checked["status"] == "accepted" else checked["status"],
                                               proof_accepted=checked["status"] == "accepted", verification=checked)
                        except (OSError, subprocess.SubprocessError, ValueError) as exc:
                            row.update(status="error", error=str(exc), proof_accepted=False)
                    row["end_to_end_ns"] = time.perf_counter_ns() - start
                rows.append(row)
    summaries = {}
    for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind"):
        selected = [r for r in rows if r["lane"] == lane]
        accepted = [r for r in selected if r["proof_accepted"]]
        measured = accepted if lane != "lean_grind" else [r for r in selected if r["status"] == "lean_baseline_accepted"]
        times = sorted(r["end_to_end_ns"] for r in measured)
        summaries[lane] = {"attempts": len(selected), "accepted_constructions": len(accepted),
            "gpu_assisted_accepted_constructions": sum(r.get("gpu_assisted", False) for r in accepted),
            "lean_baseline_accepted": sum(r["status"] == "lean_baseline_accepted" for r in selected),
            "p50_time_to_valid_proof_ns": statistics.median(times) if times else None,
            "p95_time_to_valid_proof_ns": times[math.ceil(.95 * len(times)) - 1] if times else None,
            "accepted_proofs_per_second_including_failures": (len(measured) * 1e9 / sum(r["end_to_end_ns"] or 0 for r in selected))
                if any(r["end_to_end_ns"] for r in selected) else None,
            "outcomes": {s: sum(r["status"] == s for r in selected) for s in sorted({r["status"] for r in selected})}}
    report = {"schema": "lean-max-comparison-v1", "authority": "conformance_only_no_speedup_claim",
              "semantic_contract": "bounded-unary-equality-trace-v1", "corpus_sha256": sha256(corpus_bytes).hexdigest(),
              "budgets": {"max_records": args.records, "max_rounds": args.rounds, "grind_heartbeats": 100000,
                          "lean_timeout_s": 30, "construction_timeout_s": 40},
              "phase": "fresh_process_each_attempt; compiler/driver caches uncontrolled",
              "cost_accounting": "wall time and RSS; monetary cost unmeasured; allocated buffer bytes exclude driver/runtime memory",
              "metadata": metadata, "summary": summaries, "rows": rows}
    (args.out / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    receipt = {"schema": "lean-max-comparison-receipt-v1", "authority": report["authority"],
               "corpus_sha256": report["corpus_sha256"], "budgets": report["budgets"], "summary": summaries,
               "source_sha256": metadata["source_sha256"],
               "compiler_status": {k: v["status"] for k, v in metadata["compiler_versions"].items() if isinstance(v, dict)},
               "build_status": {k: v["status"] for k, v in builds.items()},
               "derived_trace_sha256": {str(r["case"]): r["trace_sha256"] for r in rows
                                        if r["lane"] == "python" and r["trace_sha256"]}}
    (args.out / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--cpu-runner", type=Path)
    parser.add_argument("--gpu-runner", type=Path)
    parser.add_argument("--enable-gpu", action="store_true")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--mojo", default="mojo")
    parser.add_argument("--lean", default="lean")
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--records", type=int, default=64)
    parser.add_argument("--rounds", type=int, default=32)
    args = parser.parse_args()
    if args.worker:
        worker(); return
    if args.out is None or not 1 <= args.repeats <= 10 or not 1 <= args.records <= 64 or not 0 <= args.rounds <= 32:
        parser.error("--out required; repeats 1..10, records 1..64, rounds 0..32")
    for key in ("out", "cpu_runner", "gpu_runner"):
        value = getattr(args, key)
        if value is not None:
            setattr(args, key, value.resolve())
    print(json.dumps(run(args)["summary"], sort_keys=True))


if __name__ == "__main__":
    main()
