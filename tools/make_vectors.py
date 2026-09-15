#!/usr/bin/env python3
"""Regenerate fixtures/vectors.json from the Python reference model.

Each vector names a ledger, a root, a policy, and the expected validation
kinds, digests, and closure. The Mojo implementation replays this file;
tests/test_vectors.py fails if the committed file differs from the
regeneration. Usage: make_vectors.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from proof_records.records import Kind, Record, close, digest, no_policy, tag_policy, validate  # noqa: E402

FIXTURE = ROOT / "fixtures" / "vectors.json"

POLICIES = {
    "none": no_policy,
    "nlap_rank2": tag_policy({"uses_rank2_circle": "rank-2 circle primitive rejected"}),
}


def rec(id: str, kind: Kind, statement: str, deps: tuple[str, ...] = (), tags: frozenset[str] = frozenset(), **evidence: str) -> Record:
    return Record(id, kind, statement, deps, tuple(sorted(evidence.items())), tags)


CENSUS = rec("census", Kind.VERIFIED, "4554 PIP specimens, 0 capped", replay="pixi run mojo run -I . census.mojo", digest="sha256:census")
DENSITY = rec("bsw", Kind.IMPORTED, "coincidence density theorem", source="Barge-Stimac-Williams", hypotheses_checked="true")
GALOIS = rec("galois", Kind.PENDING, "Galois propagation", reason="source pending")
SWEEP = rec("sweep", Kind.BOUNDED, "no counterexample up to length 7", domain="images of length <= 3")
LEMMA = rec("lemma", Kind.VERIFIED, "finite lemma", ("census", "bsw"), replay="pixi run test", digest="sha256:lemma")
THEOREM = rec("theorem", Kind.VERIFIED, "closure over verified and imported records", ("lemma",), replay="pixi run verify", digest="sha256:theorem")
CONDITIONAL = rec("conditional", Kind.VERIFIED, "depends on pending material", ("lemma", "galois"), replay="x", digest="y")
EVIDENCE_ONLY = rec("evidence", Kind.VERIFIED, "cites a sweep as support", ("sweep",), replay="x", digest="y")
UNCHECKED = rec("unchecked", Kind.IMPORTED, "import with open hypotheses", source="somewhere", hypotheses_checked="false")
CIRCLE = rec("circle", Kind.VERIFIED, "uses a rank-2 circle", tags=frozenset({"uses_rank2_circle"}), replay="x", digest="y")
MLC = rec("mlc", Kind.PENDING, "global MLC-strength claim", reason="open frontier")
LOOP_A = rec("a", Kind.VERIFIED, "a", ("b",), replay="x", digest="y")
LOOP_B = rec("b", Kind.VERIFIED, "b", ("a",), replay="x", digest="y")
MALFORMED = rec("bad", Kind.VERIFIED, "self dependency", ("bad",), replay="x", digest="y")

LEDGER = {r.id: r for r in [CENSUS, DENSITY, GALOIS, SWEEP, LEMMA, THEOREM, CONDITIONAL, EVIDENCE_ONLY, UNCHECKED, CIRCLE, MLC, LOOP_A, LOOP_B, MALFORMED]}
LEDGER["dangling"] = rec("dangling", Kind.VERIFIED, "cites a missing record", ("nowhere",), replay="x", digest="y")
LEDGER["mismatch"] = rec("elsewhere", Kind.VERIFIED, "key differs from id", replay="x", digest="y")
LEDGER["on_circle"] = rec("on_circle", Kind.VERIFIED, "depends on the circle record", ("circle",), replay="x", digest="y")
LEDGER["frontier"] = rec("frontier", Kind.VERIFIED, "depends on the open frontier", ("mlc",), replay="x", digest="y")

CASES = [
    ("complete closure", "theorem", "none"),
    ("pending link below a verified record", "conditional", "none"),
    ("bounded experiment cited as support", "evidence", "none"),
    ("bounded experiment as root", "sweep", "none"),
    ("unchecked import", "unchecked", "none"),
    ("unknown record", "dangling", "none"),
    ("ledger key mismatch", "mismatch", "none"),
    ("malformed record", "bad", "none"),
    ("cycle", "a", "none"),
    ("consumer policy refuses a tag", "on_circle", "nlap_rank2"),
    ("same tag without the policy", "on_circle", "none"),
    ("open frontier is pending, never imported", "frontier", "nlap_rank2"),
]


def record_json(record: Record) -> dict:
    return {"id": record.id, "kind": record.kind.value, "statement": record.statement, "depends_on": list(record.depends_on),
            "evidence": [list(pair) for pair in record.evidence], "tags": sorted(record.tags)}


def vectors() -> dict:
    ledger = {key: record_json(r) for key, r in LEDGER.items()}
    validation = {key: {"kind": validate(r).kind.value, "reason": validate(r).field("reason") if validate(r).kind is Kind.REJECTED else None,
                        "digest": digest(r)} for key, r in LEDGER.items()}
    closures = []
    for name, root, policy in CASES:
        c = close(LEDGER, root, POLICIES[policy])
        closures.append({"name": name, "root": root, "policy": policy, "complete": c.complete, "reached": list(c.reached),
                         "missing_links": [[m.record_id, m.reason] for m in c.missing_links]})
    return {"format": "finite_proof_records vectors 1", "ledger": ledger, "validation": validation, "closures": closures}


def render() -> str:
    return json.dumps(vectors(), indent=2, sort_keys=True) + "\n"


def main(argv: list[str]) -> int:
    text = render()
    if argv[1:] == ["--check"]:
        current = FIXTURE.read_text(encoding="utf-8") if FIXTURE.exists() else ""
        print("fixtures/vectors.json is up to date" if current == text else "fixtures/vectors.json differs from the reference model")
        return 0 if current == text else 1
    FIXTURE.parent.mkdir(exist_ok=True)
    FIXTURE.write_text(text, encoding="utf-8")
    print(f"wrote {FIXTURE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
