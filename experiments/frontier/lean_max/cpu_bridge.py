"""CPU-only Mojo candidate interface for the bounded Lean-MAX reference.

Every returned candidate is checked against the independently computed Python
frontier (expensive on purpose); final proofs are replayed and reconstructed by
reference.py. This is *not* a performance path or a GPU implementation.
"""
from __future__ import annotations

import subprocess
from pathlib import Path

import reference as ref

MAX_INPUT_STEPS = 64
MAX_ATOMS = 128
MAX_FUNCTIONS = 16
MAX_TERMS = 128
MAX_STDOUT_BYTES = 1_000_000


class CpuFrontierLimit(Exception):
    pass


def arguments(problem: ref.Problem, snapshot: list[ref.Step]) -> list[str]:
    if (len(problem.atoms) < 1 or len(problem.atoms) > MAX_ATOMS
            or len(problem.functions) > MAX_FUNCTIONS
            or len(problem.terms) > MAX_TERMS
            or len(snapshot) > MAX_INPUT_STEPS):
        raise CpuFrontierLimit("input exceeds experimental Mojo CPU lane")
    atoms = {name: i for i, name in enumerate(problem.atoms)}
    functions = {name: i for i, name in enumerate(problem.functions)}
    args = [str(len(problem.atoms)), str(len(problem.functions)), str(len(problem.terms)), str(len(snapshot))]
    for t in problem.terms:
        if t.kind == "atom":
            args.extend(["0", str(atoms[t.name]), "0"])
        else:
            args.extend(["1", str(functions[t.name]), str(t.child)])
    for s in snapshot:
        args.extend([str(s.lhs), str(s.rhs)])
    return args


def expected_candidates(problem: ref.Problem, snapshot: list[ref.Step]) -> list[ref.Step]:
    """Independent reference enumeration in fixed, documented order."""
    apps = {(t.name, t.child): i for i, t in enumerate(problem.terms) if t.kind == "app"}
    candidates = []
    for sid, s in enumerate(snapshot):
        candidates.append(ref.Step(s.rhs, s.lhs, "symm", (sid,)))
        for name in problem.functions:
            a, b = apps.get((name, s.lhs)), apps.get((name, s.rhs))
            if a is not None and b is not None:
                candidates.append(ref.Step(a, b, "congr", (sid,), name))
    for sid, s in enumerate(snapshot):
        for tid, t in enumerate(snapshot):
            if s.rhs == t.lhs:
                candidates.append(ref.Step(s.lhs, t.rhs, "trans", (sid, tid)))
    return candidates


def read_candidates(problem: ref.Problem, snapshot: list[ref.Step], runner: Path) -> list[ref.Step]:
    args = arguments(problem, snapshot)
    try:
        process = subprocess.run([str(runner), *args], capture_output=True, timeout=20, check=True)
    except (OSError, subprocess.SubprocessError) as exc:
        raise ref.InvalidProblem(f"Mojo candidate runner failed: {exc}") from exc
    if len(process.stdout) > MAX_STDOUT_BYTES:
        raise ref.InvalidProblem("Mojo result exceeds stdout cap")
    candidates: list[ref.Step] = []
    for line in process.stdout.decode("utf-8", errors="strict").splitlines():
        parts = line.split(" ")
        if any(not part or not part.isascii() or not part.isdecimal() for part in parts[1:]):
            raise ref.InvalidProblem("malformed candidate encoding")
        try:
            numbers = tuple(int(x) for x in parts[1:])
            if parts[0] == "S" and len(numbers) == 3:
                a, b, sid = numbers
                step = ref.Step(a, b, "symm", (sid,))
            elif parts[0] == "C" and len(numbers) == 4:
                a, b, sid, f = numbers
                if not 0 <= f < len(problem.functions):
                    raise ref.InvalidProblem("invalid function index")
                step = ref.Step(a, b, "congr", (sid,), problem.functions[f])
            elif parts[0] == "T" and len(numbers) == 4:
                a, b, sid, tid = numbers
                step = ref.Step(a, b, "trans", (sid, tid))
            else:
                raise ref.InvalidProblem("unknown or malformed candidate rule")
        except ValueError as exc:
            raise ref.InvalidProblem("bad candidate record") from exc
        candidates.append(step)
    # Always fail closed on missing, reordered, or forged proposals. This is a
    # conformance gate, *not* a remotely credible speed measurement.
    if candidates != expected_candidates(problem, snapshot):
        raise ref.InvalidProblem("Mojo candidate batch diverged from reference")
    return candidates


def construct_with_mojo(
    problem: ref.Problem,
    runner: Path,
    *,
    max_records: int = 64,
    max_rounds: int = 32,
) -> dict:
    """Use Mojo to enumerate candidate derivations, with Python replay."""
    if max_records < 1 or max_rounds < 0:
        raise ValueError("invalid budget")
    steps: list[ref.Step] = []
    known: dict[tuple[int, int], int] = {}

    def add(step: ref.Step) -> bool:
        key = (step.lhs, step.rhs)
        if key in known:
            return False
        if len(steps) >= max_records:
            raise ref.BudgetReached
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
            snapshot = list(steps)
            try:
                candidates = read_candidates(problem, snapshot, runner)
            except CpuFrontierLimit:
                return {"status": "inconclusive", "reason": "Mojo frontier cap reached", "steps": []}
            changed = False
            for candidate in candidates:
                # Check EVERY proposed inference independently before allowing
                # it to influence search (not only the final proof).
                ref.check(problem, steps + [candidate], len(steps))
                changed |= add(candidate)
                if problem.goal in known:
                    return ref._result(problem, steps, known[problem.goal])
            if not changed:
                return {"status": "not_derived", "reason": "finite closure exhausted", "steps": []}
    except ref.BudgetReached:
        return {"status": "inconclusive", "reason": "record cap reached", "steps": []}
    return {"status": "inconclusive", "reason": "round cap reached", "steps": []}
