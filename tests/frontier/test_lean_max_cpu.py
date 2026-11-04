"""Run in the focused Mojo CPU job with LEAN_MAX_CPU_RUNNER set.

A skipped test in the default Python suite is NOT evidence of Mojo compilation.
"""
import importlib
import json
import os
from pathlib import Path
import random
import sys

import pytest

BASE = Path(__file__).resolve().parents[2] / "experiments/frontier/lean_max"
sys.path.insert(0, str(BASE))
ref = importlib.import_module("reference")
cpu = importlib.import_module("cpu_bridge")
codec = importlib.import_module("trace_codec")

RUNNER = os.environ.get("LEAN_MAX_CPU_RUNNER")
pytestmark = pytest.mark.skipif(not RUNNER, reason="experimental Mojo CPU binary not configured")


def demo():
    return ref.Problem.parse(json.loads((BASE / "demo.json").read_text()))


def test_mojo_constructs_same_replayable_proof():
    problem = demo()
    constructed = cpu.construct_with_mojo(problem, Path(RUNNER))
    independent = ref.construct(problem, max_records=64, max_rounds=32)
    assert constructed == independent
    assert constructed["status"] == "derived"
    trace = codec.encode_trace(problem, constructed)
    assert trace == codec.encode_trace(problem, independent)
    decoded = codec.decode_trace(problem, trace)
    assert decoded == constructed
    assert ref.lean_source(problem, decoded) == (BASE / "Demo.lean").read_text()


def test_mojo_batch_matches_python_reference():
    problem = demo()
    steps = [ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(problem.premises)]
    steps.extend(ref.Step(i, i, "refl") for i in range(len(problem.terms)))
    observed = cpu.read_candidates(problem, steps, Path(RUNNER))
    assert observed == cpu.expected_candidates(problem, steps)
    assert any(s.rule == "congr" for s in observed)
    assert any(s.rule == "trans" for s in observed)


def test_randomized_bounded_term_dags():
    rng = random.Random(20261103)
    for case in range(30):
        n_atoms = rng.randrange(1, 5)
        n_functions = rng.randrange(0, 4)
        terms = [{"atom": chr(97 + i)} for i in range(n_atoms)]
        functions = [f"f{i}" for i in range(n_functions)]
        # Each new term can reference atoms and previously added applications.
        if functions:
            used = set()
            for _ in range(7):
                choices = [
                    (fn, child)
                    for fn in functions
                    for child in range(len(terms))
                    if (fn, child) not in used
                ]
                fn, child = rng.choice(choices)
                terms.append({"fn": fn, "arg": child})
                used.add((fn, child))
        premises = [rng.choices(range(len(terms)), k=2) for _ in range(4)]
        goal = premises[0][::-1] if case % 2 == 0 else rng.choices(range(len(terms)), k=2)
        p = ref.Problem.parse({
            "atoms": [chr(97 + i) for i in range(n_atoms)],
            "functions": functions,
            "terms": terms,
            "premises": premises,
            "goal": goal,
        })
        steps = [ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(p.premises)]
        runner = Path(RUNNER)
        assert cpu.read_candidates(p, steps, runner) == cpu.expected_candidates(p, steps)
        constructed = cpu.construct_with_mojo(p, runner)
        independent = ref.construct(p, max_records=64, max_rounds=32)
        assert constructed == independent
        if constructed["status"] == "derived":
            trace = codec.encode_trace(p, constructed)
            assert trace == codec.encode_trace(p, independent)
            assert codec.decode_trace(p, trace) == independent


def test_invalid_runner_output_is_rejected(tmp_path):
    problem = demo()
    runner = tmp_path / "forged.sh"
    runner.write_text("#!/bin/sh\nprintf 'T 0 5 99 88\\n'\n")
    runner.chmod(0o755)
    with pytest.raises(ref.InvalidProblem):
        cpu.read_candidates(problem, [ref.Step(0, 1, "hyp", data=0)], runner)


def test_input_cap_is_explicit():
    problem = demo()
    frontier = [ref.Step(0, 0, "refl") for _ in range(cpu.MAX_INPUT_STEPS + 1)]
    with pytest.raises(cpu.CpuFrontierLimit):
        cpu.arguments(problem, frontier)


def test_cli_rejects_bad_index():
    import subprocess
    args = cpu.arguments(demo(), [])
    # Last field in first application triple is the child reference.
    index = 5 + 3 * 3 + 2
    args[index - 1] = "999"
    proc = subprocess.run([RUNNER, *args], capture_output=True)
    assert proc.returncode != 0
