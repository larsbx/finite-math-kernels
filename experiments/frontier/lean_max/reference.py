"""Non-authoritative, bounded reference for unary equational proof construction.

Only atoms and explicitly listed unary function applications are accepted. A
proof record contains exact equality rules; no GPU, MAX, or Lean execution is
claimed. See CONTRACT.md before consuming records.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any

IDENT = re.compile(r"[A-Za-z][A-Za-z0-9_]*\Z")
MAX_TERMS = 128
MAX_PREMISES = 64
MAX_RECORDS = 16384
MAX_ROUNDS = 128


class InvalidProblem(ValueError):
    pass


@dataclass(frozen=True)
class Term:
    kind: str
    name: str
    child: int | None


@dataclass(frozen=True)
class Problem:
    atoms: tuple[str, ...]
    functions: tuple[str, ...]
    terms: tuple[Term, ...]
    premises: tuple[tuple[int, int], ...]
    goal: tuple[int, int]

    @staticmethod
    def parse(doc: dict[str, Any]) -> "Problem":
        if not isinstance(doc, dict) or set(doc) != {"atoms", "functions", "terms", "premises", "goal"}:
            raise InvalidProblem("problem requires exactly atoms, functions, terms, premises, goal")
        atoms, fns = doc["atoms"], doc["functions"]
        if not isinstance(atoms, list) or not isinstance(fns, list):
            raise InvalidProblem("atoms/functions must be lists")
        for names in (atoms, fns):
            if len(names) != len(set(map(str, names))) or any(not isinstance(n, str) or not IDENT.fullmatch(n) for n in names):
                raise InvalidProblem("invalid or duplicate symbol")
        if set(atoms) & set(fns) or any(x.startswith(("h", "p")) and x[1:].isdigit() for x in atoms + fns):
            raise InvalidProblem("conflicting/reserved symbol")
        raw = doc["terms"]
        if not isinstance(raw, list) or not 1 <= len(raw) <= MAX_TERMS:
            raise InvalidProblem("invalid term count")
        terms = []
        signatures = set()
        for idx, node in enumerate(raw):
            if not isinstance(node, dict):
                raise InvalidProblem("term must be object")
            if set(node) == {"atom"} and isinstance(node["atom"], str) and node["atom"] in atoms:
                term = Term("atom", node["atom"], None)
            elif set(node) == {"fn", "arg"} and isinstance(node["fn"], str) and node["fn"] in fns and type(node["arg"]) is int and 0 <= node["arg"] < idx:
                term = Term("app", node["fn"], node["arg"])
            else:
                raise InvalidProblem("invalid or forward term reference")
            if term in signatures:
                raise InvalidProblem("duplicate term")
            signatures.add(term)
            terms.append(term)
        raw_p = doc["premises"]
        if not isinstance(raw_p, list) or len(raw_p) > MAX_PREMISES:
            raise InvalidProblem("invalid premises")

        def pair(x: Any) -> tuple[int, int]:
            if not isinstance(x, list) or len(x) != 2 or any(type(n) is not int or n < 0 or n >= len(terms) for n in x):
                raise InvalidProblem("invalid equality endpoint")
            return x[0], x[1]

        premises = tuple(pair(p) for p in raw_p)
        return Problem(tuple(atoms), tuple(fns), tuple(terms), premises, pair(doc["goal"]))


@dataclass(frozen=True)
class Step:
    lhs: int
    rhs: int
    rule: str
    refs: tuple[int, ...] = ()
    data: int | str | None = None

    def json(self) -> dict[str, Any]:
        return {"lhs": self.lhs, "rhs": self.rhs, "rule": self.rule, "refs": list(self.refs), "data": self.data}


class BudgetReached(Exception):
    pass


def check_step(problem: Problem, steps: list[Step], i: int) -> None:
    """Validate one inference whose earlier references have been checked."""
    s = steps[i]
    if type(s.lhs) is not int or type(s.rhs) is not int or not 0 <= s.lhs < len(problem.terms) or not 0 <= s.rhs < len(problem.terms):
        raise InvalidProblem("step endpoint outside term table")
    if any(type(r) is not int or not 0 <= r < i for r in s.refs):
        raise InvalidProblem("future or invalid reference")
    if s.rule == "hyp":
        if s.refs or type(s.data) is not int or not 0 <= s.data < len(problem.premises) or (s.lhs, s.rhs) != problem.premises[s.data]:
            raise InvalidProblem("unbound hypothesis")
    elif s.rule == "refl":
        if s.refs or s.data is not None or s.lhs != s.rhs:
            raise InvalidProblem("invalid reflexivity")
    elif s.rule == "symm":
        if len(s.refs) != 1 or s.data is not None or (s.lhs, s.rhs) != (steps[s.refs[0]].rhs, steps[s.refs[0]].lhs):
            raise InvalidProblem("invalid symmetry")
    elif s.rule == "congr":
        if len(s.refs) != 1 or not isinstance(s.data, str) or s.data not in problem.functions:
            raise InvalidProblem("invalid congruence")
        a, b = problem.terms[s.lhs], problem.terms[s.rhs]
        sub = steps[s.refs[0]]
        if a.kind != "app" or b.kind != "app" or a.name != s.data or b.name != s.data or (a.child, b.child) != (sub.lhs, sub.rhs):
            raise InvalidProblem("congruence children mismatch")
    elif s.rule == "trans":
        if len(s.refs) != 2 or s.data is not None:
            raise InvalidProblem("invalid transitivity")
        a, b = (steps[r] for r in s.refs)
        if (s.lhs, s.rhs) != (a.lhs, b.rhs) or a.rhs != b.lhs:
            raise InvalidProblem("transitivity chain mismatch")
    else:
        raise InvalidProblem("unknown proof rule")


def check(problem: Problem, steps: list[Step], goal_id: int) -> None:
    """Replay rules independently of the search path, rejecting forged steps."""
    if type(goal_id) is not int or not 0 <= goal_id < len(steps):
        raise InvalidProblem("invalid goal index")
    for i in range(len(steps)):
        check_step(problem, steps, i)
    if (steps[goal_id].lhs, steps[goal_id].rhs) != problem.goal:
        raise InvalidProblem("proof does not establish goal")


def construct(problem: Problem, max_records: int = MAX_RECORDS, max_rounds: int = MAX_ROUNDS) -> dict[str, Any]:
    """Batched finite closure, deterministic order. Caps mean inconclusive."""
    if max_records < 1 or max_rounds < 0:
        raise ValueError("invalid search budget")
    steps: list[Step] = []
    known: dict[tuple[int, int], int] = {}

    def add(step: Step) -> bool:
        key = (step.lhs, step.rhs)
        if key in known:
            return False
        if len(steps) >= max_records:
            raise BudgetReached
        known[key] = len(steps)
        steps.append(step)
        return True

    try:
        for i, (a, b) in enumerate(problem.premises):
            add(Step(a, b, "hyp", data=i))
        for i in range(len(problem.terms)):
            add(Step(i, i, "refl"))
        if problem.goal in known:
            return _result(problem, steps, known[problem.goal])
        apps: dict[tuple[str, int], int] = {(t.name, t.child): i for i, t in enumerate(problem.terms) if t.kind == "app"}
        for _ in range(max_rounds):
            snapshot = list(steps)
            # Stream rather than materializing the potentially cubic batch.
            # The snapshot fixes the inference frontier for this round.
            incoming: dict[int, list[tuple[int, Step]]] = {}
            for sid, s in enumerate(snapshot):
                incoming.setdefault(s.lhs, []).append((sid, s))

            def candidates():
                for sid, s in enumerate(snapshot):
                    yield Step(s.rhs, s.lhs, "symm", (sid,))
                    for fn in problem.functions:
                        a, b = apps.get((fn, s.lhs)), apps.get((fn, s.rhs))
                        if a is not None and b is not None:
                            yield Step(a, b, "congr", (sid,), fn)
                for sid, s in enumerate(snapshot):
                    for tid, t in incoming.get(s.rhs, []):
                        yield Step(s.lhs, t.rhs, "trans", (sid, tid))

            added = False
            for candidate in candidates():
                added |= add(candidate)
                if candidate.lhs == problem.goal[0] and candidate.rhs == problem.goal[1]:
                    return _result(problem, steps, known[problem.goal])
            if not added:
                return {"status": "not_derived", "reason": "finite closure exhausted", "steps": []}
    except BudgetReached:
        return {"status": "inconclusive", "reason": "record cap reached", "steps": []}
    return {"status": "inconclusive", "reason": "round cap reached", "steps": []}


def _result(problem: Problem, steps: list[Step], goal_id: int) -> dict[str, Any]:
    needed = set()

    def collect(i: int) -> None:
        if i not in needed:
            needed.add(i)
            for r in steps[i].refs:
                collect(r)

    collect(goal_id)
    order = sorted(needed)
    index = {old: new for new, old in enumerate(order)}
    trimmed = [Step(steps[i].lhs, steps[i].rhs, steps[i].rule, tuple(index[r] for r in steps[i].refs), steps[i].data) for i in order]
    check(problem, trimmed, index[goal_id])
    return {"status": "derived", "steps": [s.json() for s in trimmed], "goal_step": index[goal_id]}


def replay(problem: Problem, result: dict[str, Any]) -> None:
    if result.get("status") != "derived":
        raise InvalidProblem("only derived certificates can be replayed")
    if not isinstance(result.get("steps"), list):
        raise InvalidProblem("steps missing")
    raw = result["steps"]
    if len(raw) > MAX_RECORDS:
        raise InvalidProblem("oversized certificate")
    steps = []
    for s in raw:
        if not isinstance(s, dict) or set(s) != {"lhs", "rhs", "rule", "refs", "data"} or not isinstance(s["refs"], list) or not isinstance(s["rule"], str):
            raise InvalidProblem("invalid step encoding")
        steps.append(Step(s["lhs"], s["rhs"], s["rule"], tuple(s["refs"]), s["data"]))
    check(problem, steps, result.get("goal_step"))


def lean_source(problem: Problem, result: dict[str, Any]) -> str:
    """Emit standalone Lean 4 source. Actual acceptance requires running lean."""
    replay(problem, result)

    def term(i: int) -> str:
        t = problem.terms[i]
        return t.name if t.kind == "atom" else f"({t.name} {term(t.child)})"

    binders = " ".join(problem.atoms)
    fs = " ".join(problem.functions)
    lines = ["-- Generated by lean_max/reference.py; non-authoritative until Lean checks it.", "universe u", "", f"theorem lean_max_candidate {{α : Type u}}" + (f" ({binders} : α)" if binders else "") + (f" ({fs} : α → α)" if fs else "")]
    for i, (a, b) in enumerate(problem.premises):
        lines.append(f"    (h{i} : {term(a)} = {term(b)})")
    lines.append(f"    : {term(problem.goal[0])} = {term(problem.goal[1])} := by")
    for i, raw in enumerate(result["steps"]):
        s = Step(raw["lhs"], raw["rhs"], raw["rule"], tuple(raw["refs"]), raw["data"])
        if s.rule == "hyp":
            rhs = f"h{s.data}"
        elif s.rule == "refl":
            rhs = f"Eq.refl {term(s.lhs)}"
        elif s.rule == "symm":
            rhs = f"Eq.symm p{s.refs[0]}"
        elif s.rule == "congr":
            rhs = f"congrArg {s.data} p{s.refs[0]}"
        else:
            rhs = f"Eq.trans p{s.refs[0]} p{s.refs[1]}"
        lines.append(f"  have p{i} : {term(s.lhs)} = {term(s.rhs)} := {rhs}")
    lines.append(f"  exact p{result['goal_step']}")
    return "\n".join(lines) + "\n"


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("problem", type=Path)
    parser.add_argument("--lean-out", type=Path)
    args = parser.parse_args()
    problem = Problem.parse(json.loads(args.problem.read_text(encoding="utf-8")))
    result = construct(problem)
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if args.lean_out and result["status"] == "derived":
        args.lean_out.write_text(lean_source(problem, result), encoding="utf-8")


if __name__ == "__main__":
    main()
