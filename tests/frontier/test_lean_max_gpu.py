"""Offline IR/adversarial coverage. These tests do not execute Mojo or a GPU."""
from dataclasses import replace
import json
from pathlib import Path
import sys

import pytest

from experiments.frontier.lean_max import cpu_bridge as cpu
from experiments.frontier.lean_max import gpu_bridge as gpu
from experiments.frontier.lean_max import reference as ref
from experiments.frontier.lean_max import trace_codec as codec
from experiments.frontier.lean_max.corpus import problems


def frontier(p):
    return [ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(p.premises)]


def packet(p, steps, records=None):
    records = gpu.offline_slots(p, steps) if records is None else records
    size = 4 * (3 * len(p.terms) + 2 * len(steps))
    count = gpu.slot_count(len(steps), len(p.functions))
    metrics = [0] * 5 + [size + max(4, count * 24), size, count * 24, int(count > 0)]
    lines = [f"LMGPU1 {len(records)}", "DEVICE offline-test-only",
             "METRICS " + " ".join(map(str, metrics))]
    return ("\n".join(lines + [" ".join(map(str, r)) for r in records]) + "\n").encode()


def test_independent_cpu_enumeration_parity():
    for p in problems():
        for steps in ([], frontier(p), frontier(p) + [ref.Step(i, i, "refl") for i in range(len(p.terms))]):
            proposals, metrics = gpu.parse_output(p, steps, packet(p, steps))
            assert proposals == cpu.expected_candidates(p, steps)
            assert metrics["launches"] == int(bool(steps))
    assert gpu.slot_count(64, 16) == gpu.MAX_SLOTS == 5184


def test_maximum_frontier_and_function_indices():
    p = ref.Problem.parse({"atoms": ["a"], "functions": [f"f{i}" for i in range(16)],
        "terms": [{"atom": "a"}] + [{"fn": f"f{i}", "arg": 0} for i in range(16)],
        "premises": [], "goal": [0, 0]})
    steps = [ref.Step(0, 0, "refl")] * 64
    rows = gpu.offline_slots(p, steps)
    assert len(rows) == 5184
    assert gpu.decode_slots(p, steps, rows) == cpu.expected_candidates(p, steps)


@pytest.mark.parametrize("mutation", ["endpoint", "future", "negative_ref", "overflow", "bool", "padding",
                                    "duplicate", "order", "missing", "absent", "trans_chain", "function"])
def test_rejects_adversarial_device_records(mutation):
    p = problems()[0]
    steps = frontier(p)
    rows = gpu.offline_slots(p, steps)
    row = list(rows[0])
    if mutation == "endpoint": row[1] = len(p.terms)
    elif mutation == "future": row[3] = len(steps)
    elif mutation == "negative_ref": row[3] = -1
    elif mutation == "overflow": row[1] = 2**32
    elif mutation == "bool": row[1] = True
    elif mutation == "padding": row[5] = 0
    elif mutation == "duplicate": rows[-1] = rows[0]
    elif mutation == "order": rows[0], rows[2] = rows[2], rows[0]
    elif mutation == "missing": rows.pop()
    elif mutation == "absent": rows[0] = gpu.EMPTY
    elif mutation == "trans_chain": row = [4, 0, 0, 0, 0, -1]
    elif mutation == "function": row = [3, 0, 0, 0, -1, len(p.functions)]
    if mutation not in {"duplicate", "order", "missing", "absent"}:
        rows[0] = tuple(row)
    with pytest.raises(ref.InvalidProblem):
        gpu.decode_slots(p, steps, rows)


def test_protocol_rejects_noncanonical_and_inconsistent_accounting():
    p = problems()[0]
    steps = frontier(p)
    good = packet(p, steps)
    for bad in (good[:-2], good + b"x\n", b"\xff" + good[1:], good.replace(b"LMGPU1", b"LMGPU2"),
                good.replace(b"METRICS 0 ", b"METRICS -1 "),
                good.replace(b"METRICS 0 ", b"METRICS 00 "),
                good.replace(b"METRICS 0 ", b"METRICS 9999999999999999999999999 "),
                good.replace(b"METRICS 0 0 0 0 0 ", b"METRICS 0 0 0 0 0 999 "),
                b"x" * (gpu.MAX_OUTPUT_BYTES + 1)):
        with pytest.raises(ref.InvalidProblem):
            gpu.parse_output(p, steps, bad)


def test_rejects_bad_inputs_before_device_access():
    p = problems()[0]
    bad = replace(p, terms=(*p.terms, ref.Term("app", p.functions[0], len(p.terms))))
    for value in (bad, replace(p, terms=(*p.terms, p.terms[0]))):
        with pytest.raises(ref.InvalidProblem):
            gpu.validate_input(value, [])
    for steps in ([ref.Step(0, 1, "symm", (0,))], [ref.Step(999, 0, "refl")]):
        with pytest.raises(ref.InvalidProblem):
            gpu.validate_input(p, steps)
    with pytest.raises(cpu.CpuFrontierLimit):
        gpu.validate_input(p, [ref.Step(0, 0, "refl")] * 65)
    for m, f in ((2**32, 0), (0, 17), (-1, 1), (True, 0)):
        with pytest.raises(cpu.CpuFrontierLimit):
            gpu.slot_count(m, f)


def test_no_opt_in_and_no_runner_never_fall_back():
    p = problems()[0]
    with pytest.raises(ref.InvalidProblem, match="opt-in"):
        gpu.construct(p, Path("/nonexistent"))
    with pytest.raises(ref.InvalidProblem, match="unavailable"):
        gpu.read_candidates(p, frontier(p), Path("/nonexistent"), enabled=True)


def test_full_search_trace_parity_with_offline_slot_model(monkeypatch):
    def offline(p, steps, runner, **kwargs):
        return gpu.parse_output(p, steps, packet(p, steps))[0]
    monkeypatch.setattr(gpu, "read_candidates", offline)
    for p in problems():
        for cap, rounds in ((64, 32), (1, 32), (64, 0), (16, 1)):
            observed = gpu.construct(p, Path("offline-test-only"), enabled=True,
                                     max_records=cap, max_rounds=rounds)
            expected = ref.construct(p, max_records=cap, max_rounds=rounds)
            assert observed == expected
            if observed["status"] == "derived":
                trace = codec.encode_trace(p, observed)
                assert trace == codec.encode_trace(p, expected)
                assert codec.decode_trace(p, trace) == observed
    for cap, rounds in ((65, 32), (64, 33), (0, 0)):
        with pytest.raises(ValueError):
            gpu.construct(problems()[0], Path("unused"), enabled=True, max_records=cap, max_rounds=rounds)


def test_runner_failure_and_output_cap(tmp_path, monkeypatch):
    runner = tmp_path / "runner"
    runner.write_text(f"#!{sys.executable}\nraise SystemExit(3)\n")
    runner.chmod(0o755)
    p = problems()[0]
    with pytest.raises(ref.InvalidProblem, match="failed"):
        gpu.read_candidates(p, frontier(p), runner, enabled=True)
    runner.write_text(f"#!{sys.executable}\nprint('x'*2000)\n")
    monkeypatch.setattr(gpu, "MAX_OUTPUT_BYTES", 100)
    with pytest.raises(ref.InvalidProblem, match="cap"):
        gpu.read_candidates(p, frontier(p), runner, enabled=True)


def test_timeout_is_explicit(tmp_path, monkeypatch):
    runner = tmp_path / "runner"
    runner.write_text(f"#!{sys.executable}\nimport time\ntime.sleep(5)\n")
    runner.chmod(0o755)
    monkeypatch.setattr(gpu, "TIMEOUT_S", 0.01)
    with pytest.raises(ref.InvalidProblem, match="timeout"):
        gpu.read_candidates(problems()[0], frontier(problems()[0]), runner, enabled=True)
