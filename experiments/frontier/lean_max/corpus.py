"""Deterministic small term-DAG corpus; includes failures and budget refusals."""
import json
from pathlib import Path
import random

from . import reference as ref


def documents() -> list[dict]:
    demo = json.loads(Path(__file__).with_name("demo.json").read_text())
    docs = [demo]
    for goal in ([0, 0], [1, 0], [0, 2]):
        docs.append({"atoms": ["a", "b", "c"], "functions": [],
                     "terms": [{"atom": n} for n in ("a", "b", "c")],
                     "premises": [[0, 1]], "goal": goal})
    rng = random.Random(20261105)
    for case in range(30):
        atoms = [f"a{i}" for i in range(rng.randrange(1, 5))]
        functions = [f"f{i}" for i in range(rng.randrange(4))]
        terms = [{"atom": a} for a in atoms]
        used = set()
        if functions:
            for _ in range(7):
                fn, child = rng.choice([(fn, i) for fn in functions for i in range(len(terms))
                                        if (fn, i) not in used])
                terms.append({"fn": fn, "arg": child})
                used.add((fn, child))
        premises = [rng.choices(range(len(terms)), k=2) for _ in range(4)]
        docs.append({"atoms": atoms, "functions": functions, "terms": terms, "premises": premises,
                     "goal": premises[0][::-1] if case % 2 == 0 else rng.choices(range(len(terms)), k=2)})
    return docs


def problems():
    return [ref.Problem.parse(doc) for doc in documents()]
