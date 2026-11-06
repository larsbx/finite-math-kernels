"""Opt-in GPU conformance lane. Device proposals have no proof authority.

Fixed int32 slots avoid atomics and scheduling-dependent append order. The
offline slot model is deliberately separate from cpu.expected_candidates.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import selectors
import time

from . import cpu_bridge as cpu
from . import reference as ref

EMPTY = (-1,) * 6
MAX_SLOTS = 64 * 17 + 64 * 64
MAX_OUTPUT_BYTES = 1_000_000
TIMEOUT_S = 20
METRICS = ("allocation_ns", "h2d_ns", "device_compile_ns", "launch_sync_ns", "d2h_ns",
           "device_buffer_bytes", "h2d_bytes", "d2h_bytes", "launches")
INTEGER = re.compile(r"(?:0|[1-9][0-9]*|-[1-9][0-9]*)\Z")


def validate_input(problem: ref.Problem, snapshot: list[ref.Step]) -> None:
    # Reparse even direct dataclass inputs, before building a device table.
    parsed = ref.Problem.parse({"atoms": list(problem.atoms), "functions": list(problem.functions),
        "terms": [{"atom": t.name} if t.kind == "atom" else {"fn": t.name, "arg": t.child}
                  if t.kind == "app" else {} for t in problem.terms],
        "premises": [list(p) for p in problem.premises], "goal": list(problem.goal)})
    if parsed != problem:
        raise ref.InvalidProblem("noncanonical problem dataclass")
    cpu.arguments(problem, snapshot)  # same narrow lane caps; never truncate
    for i in range(len(snapshot)):
        ref.check_step(problem, snapshot, i)


def slot_count(m: int, f: int) -> int:
    if type(m) is not int or type(f) is not int or not 0 <= m <= 64 or not 0 <= f <= 16:
        raise cpu.CpuFrontierLimit("GPU frontier cap reached")
    return m * (1 + f) + m * m


def offline_slots(problem: ref.Problem, snapshot: list[ref.Step]) -> list[tuple[int, ...]]:
    """Executable specification, NOT GPU execution or a GPU fallback."""
    validate_input(problem, snapshot)
    m, f = len(snapshot), len(problem.functions)
    records = []
    for slot in range(slot_count(m, f)):
        if slot < m * (1 + f):
            sid, kind = divmod(slot, 1 + f)
            s = snapshot[sid]
            if kind == 0:
                row = (2, s.rhs, s.lhs, sid, -1, -1)
            else:
                fn = problem.functions[kind - 1]
                left = right = -1
                for i, t in enumerate(problem.terms):
                    if t.kind == "app" and t.name == fn:
                        if t.child == s.lhs:
                            left = i
                        if t.child == s.rhs:
                            right = i
                row = (3, left, right, sid, -1, kind - 1) if min(left, right) >= 0 else EMPTY
        else:
            sid, tid = divmod(slot - m * (1 + f), m)
            s, t = snapshot[sid], snapshot[tid]
            row = (4, s.lhs, t.rhs, sid, tid, -1) if s.rhs == t.lhs else EMPTY
        records.append(row)
    return records


def decode_slots(problem: ref.Problem, snapshot: list[ref.Step], records: list[tuple[int, ...]]) -> list[ref.Step]:
    validate_input(problem, snapshot)
    if len(records) != slot_count(len(snapshot), len(problem.functions)):
        raise ref.InvalidProblem("GPU slot count mismatch")
    candidates = []
    seen = set()
    for row in records:
        if len(row) != 6 or any(type(x) is not int or not -(2**31) <= x < 2**31 for x in row):
            raise ref.InvalidProblem("GPU int32 record overflow or framing")
        if tuple(row) == EMPTY:
            continue
        if tuple(row) in seen:
            raise ref.InvalidProblem("duplicate GPU candidate")
        seen.add(tuple(row))
        rule, lhs, rhs, first, second, fn = row
        if rule == 2 and second == fn == -1:
            step = ref.Step(lhs, rhs, "symm", (first,))
        elif rule == 3 and second == -1 and 0 <= fn < len(problem.functions):
            step = ref.Step(lhs, rhs, "congr", (first,), problem.functions[fn])
        elif rule == 4 and fn == -1:
            step = ref.Step(lhs, rhs, "trans", (first, second))
        else:
            raise ref.InvalidProblem("GPU opcode or padding mismatch")
        # References must be in the frozen input, not another GPU proposal.
        ref.check_step(problem, snapshot + [step], len(snapshot))
        candidates.append(step)
    if records != offline_slots(problem, snapshot):
        raise ref.InvalidProblem("GPU slot ordering or contents mismatch")
    if candidates != cpu.expected_candidates(problem, snapshot):
        raise ref.InvalidProblem("GPU candidates diverged from CPU reference")
    return candidates


def parse_output(problem: ref.Problem, snapshot: list[ref.Step], output: bytes) -> tuple[list[ref.Step], dict]:
    if len(output) > MAX_OUTPUT_BYTES:
        raise ref.InvalidProblem("GPU output cap reached")
    try:
        lines = output.decode("ascii", errors="strict").splitlines()
        count = slot_count(len(snapshot), len(problem.functions))
        if len(lines) != count + 3 or lines[0] != f"LMGPU1 {count}" or not lines[1].startswith("DEVICE "):
            raise ValueError("framing")
        device = lines[1][7:]
        if not 1 <= len(device) <= 200 or any(ord(c) < 32 for c in device):
            raise ValueError("device")
        def numbers(line):
            parts = line.split(" ")
            if any(len(p) > 20 or not INTEGER.fullmatch(p) for p in parts):
                raise ValueError("noncanonical integer")
            return tuple(int(p) for p in parts)
        if not lines[2].startswith("METRICS "):
            raise ValueError("metrics")
        values = numbers(lines[2][8:])
        if len(values) != len(METRICS) or any(x < 0 or x >= 2**63 for x in values):
            raise ValueError("metrics range")
        metrics = dict(zip(METRICS, values))
        input_bytes = 4 * (3 * len(problem.terms) + 2 * len(snapshot))
        if (metrics["h2d_bytes"] != input_bytes or metrics["d2h_bytes"] != count * 24
                or metrics["device_buffer_bytes"] != input_bytes + max(4, count * 24)
                or metrics["launches"] != int(count > 0)):
            raise ValueError("inconsistent accounting")
        records = [numbers(line) for line in lines[3:]]
    except (UnicodeError, ValueError, IndexError) as exc:
        raise ref.InvalidProblem(f"malformed GPU output: {exc}") from exc
    return decode_slots(problem, snapshot, records), {"device": device, **metrics}


def read_candidates(problem: ref.Problem, snapshot: list[ref.Step], runner: Path,
                    *, enabled: bool = False, telemetry: list | None = None,
                    output_path: Path | None = None) -> list[ref.Step]:
    if not enabled:
        raise ref.InvalidProblem("GPU execution requires explicit opt-in")
    validate_input(problem, snapshot)
    # Drain bounded pipes with backpressure. Never capture arbitrary output in
    # memory or let a failed driver grow a temporary file without a hard bound.
    start = time.perf_counter_ns()
    try:
        proc = subprocess.Popen([str(runner), "--gpu", *cpu.arguments(problem, snapshot)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    except OSError as exc:
        raise ref.InvalidProblem(f"GPU runner unavailable: {exc}") from exc
    buffers = {"stdout": bytearray(), "stderr": bytearray()}
    deadline = time.monotonic() + TIMEOUT_S
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ, "stdout")
            selector.register(proc.stderr, selectors.EVENT_READ, "stderr")
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ref.InvalidProblem("GPU runner timeout")
                for key, _ in selector.select(min(remaining, 0.05)):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                    else:
                        target = buffers[key.data]
                        if len(target) + len(chunk) > MAX_OUTPUT_BYTES:
                            raise ref.InvalidProblem("GPU runner output cap")
                        target.extend(chunk)
        try:
            code = proc.wait(timeout=max(0.001, deadline - time.monotonic()))
        except subprocess.TimeoutExpired as exc:
            raise ref.InvalidProblem("GPU runner timeout") from exc
        if output_path is not None:
            output_path.write_bytes(buffers["stdout"])
            output_path.with_suffix(".stderr").write_bytes(buffers["stderr"])
        if code:
            raise ref.InvalidProblem(f"GPU runner failed (exit {code}); no CPU fallback")
        candidates, metrics = parse_output(problem, snapshot, bytes(buffers["stdout"]))
    finally:
        try:
            os.killpg(proc.pid, 9)
        except ProcessLookupError:
            pass
        proc.wait()
        proc.stdout.close()
        proc.stderr.close()
    metrics["runner_and_parity_ns"] = time.perf_counter_ns() - start
    if telemetry is not None:
        telemetry.append(metrics)
    return candidates


def construct(problem: ref.Problem, runner: Path, *, enabled: bool = False,
              max_records: int = 64, max_rounds: int = 32, telemetry: list | None = None,
              candidate_reader=None) -> dict:
    if not enabled:
        raise ref.InvalidProblem("GPU execution requires explicit opt-in")
    if type(max_records) is not int or not 1 <= max_records <= 64 or type(max_rounds) is not int or not 0 <= max_rounds <= 32:
        raise ValueError("GPU search budget outside bounded lane")
    validate_input(problem, [])
    steps = []
    known = {}
    def add(step):
        key = (step.lhs, step.rhs)
        if key in known:
            return False
        if len(steps) >= max_records:
            raise ref.BudgetReached
        ref.check_step(problem, steps + [step], len(steps))
        known[key] = len(steps)
        steps.append(step)
        return True
    try:
        for i, (a, b) in enumerate(problem.premises):
            add(ref.Step(a, b, "hyp", data=i))
        for i in range(len(problem.terms)):
            add(ref.Step(i, i, "refl"))
        if problem.goal in known:
            return ref._result(problem, steps, known[problem.goal])
        for _ in range(max_rounds):
            proposals = (candidate_reader or read_candidates)(
                problem, list(steps), runner, enabled=True, telemetry=telemetry)
            changed = False
            for step in proposals:
                changed |= add(step)
                if problem.goal in known:
                    return ref._result(problem, steps, known[problem.goal])
            if not changed:
                return {"status": "not_derived", "reason": "finite closure exhausted", "steps": []}
    except ref.BudgetReached:
        return {"status": "inconclusive", "reason": "record cap reached", "steps": []}
    return {"status": "inconclusive", "reason": "round cap reached", "steps": []}
