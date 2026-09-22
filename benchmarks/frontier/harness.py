#!/usr/bin/env python3
"""Frontier benchmark harness (Slice 0 of ``docs/frontier-math-compute-candidates.md``).

It builds each registered implementation of a candidate, runs it on one
canonical corpus per lane, replays the emitted record against the candidate's
spec oracle, and writes one JSON Lines row per (implementation, lane). Rows
that did not run (not implemented, unsupported, no runner, build failure,
timeout) are rows, not omissions. The comparator refuses rows of different
semantic contracts or corpora and reports every digest divergence.

Authority: performance evidence only.

Usage:
    harness.py run <candidate> [--corpus NAME] [--lanes L ...] [--repeats N] [--out FILE]
"""

from __future__ import annotations

import argparse
import functools
import hashlib
import importlib.util
import json
import os
import platform
import re
import statistics
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path
from types import ModuleType

FRONTIER = Path(__file__).resolve().parent
ROOT = FRONTIER.parents[1]
MANIFEST = FRONTIER / "candidates.toml"
BUILD = FRONTIER / ".build"
RESULTS = FRONTIER / "results"
FULL_REPLAY_WORK = 100_000
TIMEOUT_S = 600
RAN = frozenset({"ok", "replay_rejected", "nondeterministic"})
SELF_NAME = Path("/proc/self/comm").read_text().strip() if Path("/proc/self/comm").exists() else ""


class ContractMismatch(ValueError):
    """Rows that answer different questions were handed to the comparator."""


def load_manifest(path: Path = MANIFEST) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def candidate(cid: str) -> dict:
    return next(c for c in load_manifest()["candidate"] if c["id"] == cid)


@functools.cache
def oracle(cid: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(f"{cid}_reference", FRONTIER / cid / "reference.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve annotations through sys.modules
    spec.loader.exec_module(module)
    return module


def load_registry(cid: str) -> dict[str, dict]:
    """Registered implementations, in the manifest's order."""
    table = tomllib.loads((FRONTIER / cid / "implementations.toml").read_text(encoding="utf-8"))
    return {name: table[name] for name in candidate(cid)["implementations"] if name in table}


def expand(argv: list[str], cid: str, build_dir: Path, threads: int | None = None) -> list[str]:
    return [a.format(dir=FRONTIER / cid, build=build_dir, threads=threads) for a in argv]


def command_output(argv: list[str]) -> str | None:
    try:
        return subprocess.run(argv, capture_output=True, text=True, check=True, timeout=60).stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def environment() -> dict:
    cpu = next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines()
                if line.startswith("model name")), platform.processor()) if Path("/proc/cpuinfo").exists() else platform.processor()
    return {
        "repository_revision": {"commit": command_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
                                "dirty": bool(command_output(["git", "-C", str(ROOT), "status", "--porcelain"]))},
        "hardware": {"cpu": cpu, "logical_cpus": os.cpu_count(), "gpu": None, "os": platform.platform(),
                     "machine": platform.machine(), "affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None},
    }


def image_peak_kib(pid: int) -> int | None:
    """The child's own peak RSS (``VmHWM``), once it has exec'd away from this interpreter.

    ``ru_maxrss`` from ``wait4`` is no substitute: Linux carries the forking
    parent's high-water mark across ``exec``, so every child would report at
    least this harness's own footprint.
    """
    try:
        fields = dict(line.split(":", 1) for line in Path(f"/proc/{pid}/status").read_text().splitlines() if ":" in line)
    except OSError:
        return None
    if fields.get("Name", "").strip() == SELF_NAME or "VmHWM" not in fields:
        return None
    return int(fields["VmHWM"].split()[0])


def timed(argv: list[str], timeout: float = TIMEOUT_S) -> dict:
    """Run once; wall time, exit status, output, and the child's peak RSS."""
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        start = time.perf_counter_ns()
        proc = subprocess.Popen(argv, stdout=out, stderr=err)
        deadline = time.monotonic() + timeout
        peak = None
        while (reaped := os.wait4(proc.pid, os.WNOHANG))[0] == 0:
            if time.monotonic() > deadline:
                proc.kill()
                os.wait4(proc.pid, 0)
                return {"timeout": True}
            peak = image_peak_kib(proc.pid) or peak
            time.sleep(0.0005)
        wall = time.perf_counter_ns() - start
        proc.returncode = os.waitstatus_to_exitcode(reaped[1])
        out.seek(0)
        err.seek(0)
        stdout, stderr = out.read(), err.read()
    kernel = re.search(rb"kernel_ns (\d+)", stderr)
    memory = {"max_rss_kib": peak, "method": "VmHWM, polled"} if peak else \
             {"max_rss_kib": reaped[2].ru_maxrss, "method": "rusage, includes the launcher's footprint"}
    return {"timeout": False, "code": proc.returncode, "out": stdout, "err": stderr.decode(errors="replace"),
            "wall_ns": wall, "kernel_ns": int(kernel.group(1)) if kernel else None, "memory": memory}


def build(impl: dict, cid: str, build_dir: Path) -> dict:
    if "build" not in impl:
        return {"ok": True, "cold_compile_ns": None}
    build_dir.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter_ns()
    try:
        done = subprocess.run(expand(impl["build"], cid, build_dir), capture_output=True, text=True, timeout=TIMEOUT_S)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "cold_compile_ns": None, "note": str(exc)}
    return {"ok": done.returncode == 0, "cold_compile_ns": time.perf_counter_ns() - start, "note": done.stderr[-500:]}


def distribution(xs: list[int]) -> dict:
    ordered = sorted(xs)
    return {"min": ordered[0], "median": statistics.median(ordered),
            "p95": ordered[min(len(ordered) - 1, round(0.95 * (len(ordered) - 1)))]} if ordered else {}


def base_row(cid: str, corpus_name: str, corpus, name: str, lane: str, env: dict, impl: dict) -> dict:
    ref = oracle(cid)
    return {
        "candidate": cid, "implementation": name, "lane": lane, "status": None, "note": None,
        "semantic_contract": ref.CONTRACT, "corpus": corpus_name, "corpus_sha256": corpus.sha256(),
        "repository_revision": env["repository_revision"], "hardware": env["hardware"],
        "compiler_versions": {name: command_output(impl["version"]) if "version" in impl else None},
        "threads": None, "cold_compile_time": None, "warm_wall_time_distribution": None, "throughput": None,
        "peak_memory": None, "transfer_time": None, "output_digest": None, "replay_verdict": None,
        "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def measure(row: dict, impl: dict, cid: str, corpus, threads: int, repeats: int, build_dir: Path) -> dict:
    """Fill ``row`` from one warmup and ``repeats`` warm runs of a built implementation."""
    ref = oracle(cid)
    argv = expand(impl["run"], cid, build_dir, threads) + corpus.args() + [str(threads)]
    runs = [timed(argv) for _ in range(repeats + 1)]
    if any(r["timeout"] for r in runs):
        return row | {"status": "timeout", "note": f"exceeded {TIMEOUT_S}s"}
    if bad := next((r for r in runs if r["code"] != 0), None):
        status = "unsupported" if "unsupported" in bad["err"] else "failed"
        return row | {"status": status, "note": bad["err"].strip().splitlines()[-1][:300] if bad["err"].strip() else f"exit {bad['code']}"}
    warm = runs[1:]
    text = runs[0]["out"]
    kernel = [r["kernel_ns"] for r in warm if r["kernel_ns"] is not None]
    full = corpus.work <= FULL_REPLAY_WORK
    try:
        errors = ref.replay(corpus, text, full=full)
    except (ValueError, IndexError) as exc:
        errors = [f"unparseable record: {exc}"]
    status = ("nondeterministic" if any(r["out"] != text for r in runs) else "replay_rejected" if errors else "ok")
    median_kernel = statistics.median(kernel) if kernel else None
    return row | {
        "status": status, "note": "; ".join(errors[:3]) or None, "threads": threads,
        "warm_wall_time_distribution": {"warmup_runs": 1, "wall_ns": [r["wall_ns"] for r in warm], "kernel_ns": kernel,
                                        "wall": distribution([r["wall_ns"] for r in warm]), "kernel": distribution(kernel)},
        "throughput": {"work_units": corpus.work, "per_second_median_kernel": corpus.work / median_kernel * 1e9 if median_kernel else None},
        "peak_memory": max((r["memory"] for r in runs), key=lambda m: (m["method"].startswith("VmHWM"), m["max_rss_kib"])),
        "output_digest": hashlib.sha256(text).hexdigest(),
        "replay_verdict": ("rejected: " + errors[0]) if errors else f"accepted ({'full' if full else 'sampled'})",
    }


def run_candidate(cid: str, corpus_name: str, registry: dict[str, dict], lanes: list[str], repeats: int,
                  build_dir: Path = BUILD) -> list[dict]:
    ref = oracle(cid)
    corpus = ref.Corpus.from_mapping(ref.load_corpora()[corpus_name])
    env = environment()
    rows = []
    for name, impl in registry.items():
        built = None
        for lane in lanes:
            row = base_row(cid, corpus_name, corpus, name, lane, env, impl)
            if "status" in impl:
                rows.append(row | {"status": impl["status"]})
                continue
            if lane.startswith("gpu"):
                rows.append(row | {"status": "no_runner", "note": "no GPU runner identified"})
                continue
            built = built or build(impl, cid, build_dir)
            row |= {"cold_compile_time": {"ns": built["cold_compile_ns"]}}
            if not built["ok"]:
                rows.append(row | {"status": "build_failed", "note": built.get("note")})
                continue
            threads = 1 if lane == "cpu_single" else os.cpu_count() or 1
            rows.append(measure(row, impl, cid, corpus, threads, repeats, build_dir))
    return rows


def compare(rows: list[dict]) -> list[str]:
    """Divergences among rows that produced a record; refuses to compare unlike rows."""
    questions = {(r["semantic_contract"], r["corpus_sha256"]) for r in rows}
    if len(questions) > 1:
        raise ContractMismatch(f"rows answer {len(questions)} different (contract, corpus) questions: {sorted(questions)}")
    produced = [r for r in rows if r["status"] in RAN]
    if not produced:
        return []
    first = produced[0]
    return [f"{r['implementation']}/{r['lane']} digest {r['output_digest']} != {first['implementation']}/{first['lane']} digest {first['output_digest']}"
            for r in produced[1:] if r["output_digest"] != first["output_digest"]]


def table(rows: list[dict]) -> str:
    """Markdown summary; speedup is against the fastest correct Rust row of the same lane, never Python."""
    def median_ms(r: dict) -> float | None:
        k = (r.get("warm_wall_time_distribution") or {}).get("kernel") or {}
        return k.get("median") / 1e6 if k else None
    best = {}
    for r in rows:
        if r["implementation"] == "rust" and r["status"] == "ok" and median_ms(r):
            best[r["lane"]] = min(best.get(r["lane"], float("inf")), median_ms(r))
    lines = ["| implementation | lane | threads | status | kernel median ms | kernel p95 ms | Mwords/s | vs rust | replay |",
             "|---|---|---:|---|---:|---:|---:|---:|---|"]
    for r in rows:
        m, k = median_ms(r), ((r.get("warm_wall_time_distribution") or {}).get("kernel") or {})
        tp = (r.get("throughput") or {}).get("per_second_median_kernel")
        cells = [r["implementation"], r["lane"], r["threads"] or "", r["status"],
                 f"{m:.2f}" if m else "", f"{k['p95'] / 1e6:.2f}" if k else "", f"{tp / 1e6:.1f}" if tp else "",
                 f"{best[r['lane']] / m:.2f}x" if m and r["status"] == "ok" and r["lane"] in best else "",
                 r["replay_verdict"] or r["note"] or ""]
        lines.append("| " + " | ".join(map(str, cells)) + " |")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run")
    run.add_argument("candidate")
    run.add_argument("--corpus", default="smoke")
    run.add_argument("--lanes", nargs="+")
    run.add_argument("--repeats", type=int, default=5)
    run.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    lanes = args.lanes or candidate(args.candidate)["lanes"]
    rows = run_candidate(args.candidate, args.corpus, load_registry(args.candidate), lanes, args.repeats)
    out = args.out or RESULTS / f"{args.candidate}-{args.corpus}-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(json.dumps(r, sort_keys=True) + "\n" for r in rows), encoding="utf-8")
    divergences = compare(rows)
    print(table(rows))
    print(f"\nrows: {out}")
    for d in divergences:
        print(f"DIVERGENCE {d}")
    bad = [r for r in rows if r["status"] in {"replay_rejected", "nondeterministic"}]
    return 1 if divergences or bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
