"""Only this opt-in lane can produce GPU parity evidence. No CPU substitutes."""
import os
from pathlib import Path
import subprocess

import pytest

from experiments.frontier.lean_max import cpu_bridge as cpu
from experiments.frontier.lean_max import gpu_bridge as gpu
from experiments.frontier.lean_max import reference as ref
from experiments.frontier.lean_max import trace_codec as codec
from experiments.frontier.lean_max.corpus import problems

RUNNER = os.environ.get("LEAN_MAX_GPU_RUNNER")
pytestmark = pytest.mark.skipif(not RUNNER, reason="genuine GPU runner not configured")


def test_device_parity_and_deterministic_trace_bytes():
    runner = Path(RUNNER).resolve()
    for p in problems():
        steps = [ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(p.premises)]
        metrics = []
        for _ in range(3):
            observed = gpu.read_candidates(p, steps, runner, enabled=True, telemetry=metrics)
            assert observed == cpu.expected_candidates(p, steps)
        assert all(m["launches"] == 1 and m["device"] for m in metrics)
        expected = ref.construct(p, max_records=64, max_rounds=32)
        for _ in range(2):
            actual = gpu.construct(p, runner, enabled=True)
            assert actual == expected
            if actual["status"] == "derived":
                trace = codec.encode_trace(p, actual)
                assert trace == codec.encode_trace(p, expected)
                assert codec.decode_trace(p, trace) == expected


def test_device_boundary_slots():
    p = ref.Problem.parse({"atoms": ["a"], "functions": [f"f{i}" for i in range(16)],
        "terms": [{"atom": "a"}] + [{"fn": f"f{i}", "arg": 0} for i in range(16)],
        "premises": [], "goal": [0, 0]})
    steps = [ref.Step(0, 0, "refl")] * 64
    assert gpu.read_candidates(p, steps, Path(RUNNER).resolve(), enabled=True) == cpu.expected_candidates(p, steps)


@pytest.mark.parametrize("case", ["forward", "endpoint", "duplicate_term", "overflow", "arity", "cap", "padding"])
def test_device_driver_refuses_malformed_cli(case):
    args = cpu.arguments(problems()[0], [])
    if case == "forward": args[4 + 3 * 3 + 2] = "3"
    elif case == "endpoint":
        args[3] = "1"
        args.extend(["128", "0"])
    elif case == "duplicate_term": args[7:10] = args[4:7]
    elif case == "overflow": args[0] = "18446744073709551616"
    elif case == "arity": args.pop()
    elif case == "cap": args[3] = "65"
    elif case == "padding": args[6] = "1"
    proc = subprocess.run([str(Path(RUNNER).resolve()), "--gpu", *args], capture_output=True, timeout=20)
    assert proc.returncode != 0


def test_driver_requires_opt_in():
    proc = subprocess.run([str(Path(RUNNER).resolve()), *cpu.arguments(problems()[0], [])],
                          capture_output=True, timeout=20)
    assert proc.returncode != 0
