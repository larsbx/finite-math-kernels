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
    ref.replay(problem, constructed)
    assert ref.lean_source(problem, constructed) == (BASE / "Demo.lean").read_text()


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
    for _ in range(30):
        n_atoms = rng.randrange(1, 5)
        n_functions = rng.randrange(0, 4)
        terms = [{"atom": chr(97 + i)} for i in range(n_atoms)]
        # Generate distinct topologically ordered application nodes.
        choices = [(f"f{i}", j) for i in range(len(terms)) for j in range(n_functions)]
        rng.shuffle(choices)
        used = set()
        for f, c in choices[:7]:
            if (f, c) not in used:
                terms.append({"fn": f, "arg": c})
                used.add((f, c))
        p = ref.Problem.parse({
            "atoms": [chr(97 + i) for i in range(n_atoms)],
            "functions": [f"f{i}" for i in range(n_functions)],
            "terms": terms,
            "premises": [],
            "goal": [0, 0],
        })
        steps = [ref.Step(rng.randrange(len(terms)), rng.randrange(len(terms)), "refl") for _ in range(4)]
        assert cpu.read_candidates(p, steps, Path(RUNNER)) == cpu.expected_candidates(p, steps)


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
