"""Contract and negative tests for experimental equational derivations."""
import json
from pathlib import Path
import shutil
import subprocess

import pytest

from experiments.frontier.lean_max import reference as ref

BASE = Path(__file__).resolve().parents[2] / "experiments/frontier/lean_max"


def problem():
    return ref.Problem.parse(json.loads((BASE / "demo.json").read_text()))


def test_transitivity_and_congruence(tmp_path):
    p = problem()
    result = ref.construct(p)
    assert result["status"] == "derived"
    assert {s["rule"] for s in result["steps"]} >= {"hyp", "trans", "congr"}
    ref.replay(p, result)
    script = ref.lean_source(p, result)
    assert "congrArg f" in script
    assert "Eq.trans" in script
    assert script == ref.lean_source(p, ref.construct(p))
    if shutil.which("lean"):
        f = tmp_path / "Demo.lean"
        f.write_text(script)
        subprocess.run(["lean", str(f)], check=True, capture_output=True, text=True)


def test_forged_trace_fails():
    p = problem()
    result = ref.construct(p)
    forged = json.loads(json.dumps(result))
    forged["steps"][-1]["rhs"] = 0
    with pytest.raises(ref.InvalidProblem):
        ref.replay(p, forged)
    forged = json.loads(json.dumps(result))
    forged["steps"][-1]["refs"] = [len(result["steps"]) + 1]
    with pytest.raises(ref.InvalidProblem):
        ref.replay(p, forged)


def test_valid_intermediate_does_not_establish_goal():
    p = problem()
    steps = [
        ref.Step(0, 1, "hyp", data=0),
        ref.Step(1, 2, "hyp", data=1),
        ref.Step(0, 2, "trans", (0, 1)),
    ]
    ref.check_step(p, steps, 2)
    with pytest.raises(ref.InvalidProblem, match="proof does not establish goal"):
        ref.replay(p, {"status": "derived", "goal_step": 2, "steps": [s.json() for s in steps]})

    steps[2] = ref.Step(0, 2, "trans", (1, 0))
    with pytest.raises(ref.InvalidProblem, match="transitivity chain mismatch"):
        ref.check_step(p, steps, 2)


def test_unsolved_and_capped():
    d = json.loads((BASE / "demo.json").read_text())
    d["premises"] = []
    p = ref.Problem.parse(d)
    assert ref.construct(p)["status"] == "not_derived"
    assert ref.construct(problem(), max_records=1)["status"] == "inconclusive"
    assert ref.construct(problem(), max_rounds=0)["status"] == "inconclusive"


@pytest.mark.parametrize("edit", [
    lambda d: d["terms"].append({"fn": "f", "arg": 99}),
    lambda d: d["terms"].append({"fn": "g", "arg": 0}),
    lambda d: d["terms"].append({"fn": "f", "arg": len(d["terms"])}),
    lambda d: d["terms"].append({"fn": "f", "arg": True}),
    lambda d: d["terms"].append({"atom": "a"}),
    lambda d: d.update({"goal": [True, 2]}),
    lambda d: d.update({"functions": ["f", "f"]}),
    lambda d: d.update({"atoms": ["p0"]}),
])
def test_bad_problem_rejected(edit):
    d = json.loads((BASE / "demo.json").read_text())
    edit(d)
    with pytest.raises(ref.InvalidProblem):
        ref.Problem.parse(d)


def test_cannot_replay_unsolved_as_proof():
    with pytest.raises(ref.InvalidProblem):
        ref.replay(problem(), {"status": "inconclusive", "steps": []})
