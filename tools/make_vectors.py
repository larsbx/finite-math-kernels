#!/usr/bin/env python3
"""Regenerate fixtures/vectors.json from the Python reference model.

Each vector names a ledger, a root, a policy, and the expected validation
kinds, identities, digests, and closure. Ledger keys are record identifiers
(digests of the preimage), so the fixture also carries a label map for
readers. The Mojo implementation replays this file;
tests/proof_records/test_vectors.py fails if the committed file differs
from the regeneration. It also writes proof_records/known_answers.py, the
constants the import-time self-test checks. Usage: make_vectors.py [--check]
"""

from __future__ import annotations

import json
import sys
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from proof_records.records import (BOUNDED, Edge, Kind, Record, close, digest, edge, identified, identity, no_policy,  # noqa: E402
                                   preimage_bytes, tag_policy, validate)

FIXTURE = ROOT / "fixtures" / "vectors.json"
KNOWN = ROOT / "proof_records" / "known_answers.py"

POLICIES = {
    "none": no_policy,
    "nlap_rank2": tag_policy({"uses_rank2_circle": "rank-2 circle primitive rejected"}),
}

PISOT = "primitive Pisot substitutions"
SPECIMENS = "4554 PIP specimens"
SHORT = "images of length <= 3"
FORGED = "sha256:" + "f" * 64
NOWHERE = "sha256:" + "0" * 64


def rec(kind: Kind, statement: str, scope: str, deps: tuple[Edge, ...] = (), tags: frozenset[str] = frozenset(), **evidence: str) -> Record:
    return identified(Record("", kind, statement, scope, deps, tuple(sorted(evidence.items())), tags))


PROOF = rec(Kind.REPOSITORY, "seed-patch overlap graph finiteness", PISOT, source="manuscript Theorem 4.22", proof_reviewed="true")
UNREVIEWED = rec(Kind.REPOSITORY, "repository theorem with an unreviewed proof", PISOT, source="draft", proof_reviewed="false")
CENSUS = rec(Kind.VERIFIED, "4554 PIP specimens, 0 capped", SPECIMENS, replay="pixi run mojo run -I . census.mojo", digest="sha256:census")
DENSITY = rec(Kind.IMPORTED, "coincidence density theorem", PISOT, source="Barge-Stimac-Williams", hypotheses_checked="true")
GALOIS = rec(Kind.PENDING, "Galois propagation", PISOT, reason="source pending")
SWEEP = rec(Kind.BOUNDED, "no counterexample up to length 7", SHORT, domain=SHORT)
LEMMA = rec(Kind.VERIFIED, "finite lemma", PISOT, (edge(CENSUS, "lemma/census", "scope=" + SPECIMENS), edge(DENSITY, "lemma/density")),
            replay="pixi run test", digest="sha256:lemma")
THEOREM = rec(Kind.VERIFIED, "closure over verified and imported records", PISOT, (edge(LEMMA, "theorem/lemma"), edge(PROOF, "theorem/proof")),
              replay="pixi run verify", digest="sha256:theorem")
CONDITIONAL = rec(Kind.VERIFIED, "depends on pending material", PISOT, (edge(LEMMA, "conditional/lemma"), edge(GALOIS, "conditional/galois")),
                  replay="x", digest="y")
EVIDENCE_ONLY = rec(Kind.VERIFIED, "cites a sweep as support", SHORT, (edge(SWEEP, "evidence/sweep"),), replay="x", digest="y")
WITHIN_SWEEP = rec(Kind.VERIFIED, "bounded claim closed by a bounded experiment", SHORT, (edge(SWEEP, "within/sweep", required_outcome=BOUNDED),),
                   replay="x", digest="y")
UNCHECKED = rec(Kind.IMPORTED, "import with open hypotheses", PISOT, source="somewhere", hypotheses_checked="false")
CIRCLE = rec(Kind.VERIFIED, "uses a rank-2 circle", PISOT, tags=frozenset({"uses_rank2_circle"}), replay="x", digest="y")
MLC = rec(Kind.PENDING, "global MLC-strength claim", PISOT, reason="open frontier")
ON_CIRCLE = rec(Kind.VERIFIED, "depends on the circle record", PISOT, (edge(CIRCLE, "on_circle/circle"),), replay="x", digest="y")
FRONTIER = rec(Kind.VERIFIED, "depends on the open frontier", PISOT, (edge(MLC, "frontier/mlc"),), replay="x", digest="y")
DANGLING = rec(Kind.VERIFIED, "cites a missing record", PISOT, (Edge(NOWHERE, "nothing", "dangling/nowhere"),), replay="x", digest="y")
MISMATCH = rec(Kind.VERIFIED, "key differs from id", PISOT, replay="x", digest="y")
WRONG_CLAIM = rec(Kind.VERIFIED, "expects a claim the census does not make", SPECIMENS,
                  (Edge(CENSUS.id, "4555 PIP specimens, 0 capped", "wrong_claim/census"),), replay="x", digest="y")
WRONG_SCOPE = rec(Kind.VERIFIED, "expects the lemma on the wrong scope", SPECIMENS, (edge(LEMMA, "wrong_scope/lemma"),), replay="x", digest="y")
WRONG_OUTCOME = rec(Kind.VERIFIED, "requires a bounded outcome from an accepted record", SPECIMENS,
                    (edge(CENSUS, "wrong_outcome/census", required_outcome=BOUNDED),), replay="x", digest="y")
FORGED_ID = replace(CENSUS, id=FORGED)
LOOP_A = Record("sha256:" + "a" * 64, Kind.VERIFIED, "a", PISOT, (Edge("sha256:" + "b" * 64, "b", "a/b"),), (("digest", "y"), ("replay", "x")))
LOOP_B = Record("sha256:" + "b" * 64, Kind.VERIFIED, "b", PISOT, (Edge("sha256:" + "a" * 64, "a", "b/a"),), (("digest", "y"), ("replay", "x")))
DUPLICATE_DEP = rec(Kind.VERIFIED, "duplicate dependency", PISOT, (edge(CENSUS, "bad/first", "scope=" + SPECIMENS), edge(CENSUS, "bad/second", "scope=" + SPECIMENS)),
                    replay="x", digest="y")
BAD_RELATION = rec(Kind.VERIFIED, "unknown scope relation", PISOT, (edge(CENSUS, "bad_relation/census", "within"),), replay="x", digest="y")
BAD_OUTCOME = rec(Kind.VERIFIED, "unknown required outcome", PISOT, (edge(CENSUS, "bad_outcome/census", required_outcome="proved"),),
                  replay="x", digest="y")
DIAMOND = rec(Kind.VERIFIED, "reaches the lemma twice, once with the wrong claim", PISOT,
              (edge(THEOREM, "diamond/theorem"), Edge(LEMMA.id, "not the finite lemma", "diamond/lemma")), replay="x", digest="y")
DIAMOND_OK = rec(Kind.VERIFIED, "reaches the lemma twice, correctly", PISOT, (edge(THEOREM, "ok/theorem"), edge(LEMMA, "ok/lemma")),
                 replay="x", digest="y")
BOUNDED_ELSEWHERE = rec(Kind.VERIFIED, "bounded dependency outside its own scope", PISOT,
                        (edge(SWEEP, "elsewhere/sweep", "scope=" + SHORT, BOUNDED),), replay="x", digest="y")

LABELS = {
    "proof": PROOF, "unreviewed": UNREVIEWED, "census": CENSUS, "bsw": DENSITY, "galois": GALOIS, "sweep": SWEEP, "lemma": LEMMA, "theorem": THEOREM, "conditional": CONDITIONAL,
    "evidence": EVIDENCE_ONLY, "within": WITHIN_SWEEP, "unchecked": UNCHECKED, "circle": CIRCLE, "mlc": MLC, "on_circle": ON_CIRCLE,
    "frontier": FRONTIER, "dangling": DANGLING, "wrong_claim": WRONG_CLAIM, "wrong_scope": WRONG_SCOPE, "wrong_outcome": WRONG_OUTCOME,
    "forged": FORGED_ID, "a": LOOP_A, "b": LOOP_B, "bad": DUPLICATE_DEP, "bad_relation": BAD_RELATION, "bad_outcome": BAD_OUTCOME,
    "elsewhere": BOUNDED_ELSEWHERE, "diamond": DIAMOND, "diamond_ok": DIAMOND_OK,
}
KEYS = {label: r.id for label, r in LABELS.items()}
KEYS["mismatch"] = "mismatch"
LEDGER = {KEYS[label]: r for label, r in LABELS.items()}
LEDGER["mismatch"] = MISMATCH

CASES = [
    ("complete closure", "theorem", "none"),
    ("bounded claim closed by a bounded experiment on its own scope", "within", "none"),
    ("pending link below a verified record", "conditional", "none"),
    ("bounded experiment cited as support", "evidence", "none"),
    ("bounded experiment as root", "sweep", "none"),
    ("unchecked import", "unchecked", "none"),
    ("repository theorem as root", "proof", "none"),
    ("unreviewed repository theorem", "unreviewed", "none"),
    ("unknown record", "dangling", "none"),
    ("ledger key mismatch", "mismatch", "none"),
    ("claim mismatch", "wrong_claim", "none"),
    ("scope mismatch", "wrong_scope", "none"),
    ("second incoming edge to a shared record is checked", "diamond", "none"),
    ("shared record reached twice with correct edges", "diamond_ok", "none"),
    ("outcome mismatch", "wrong_outcome", "none"),
    ("forged identifier", "forged", "none"),
    ("cycle is unconstructible: forged identifiers reject", "a", "none"),
    ("duplicate dependency", "bad", "none"),
    ("unknown scope relation", "bad_relation", "none"),
    ("unknown required outcome", "bad_outcome", "none"),
    ("bounded dependency outside its own scope", "elsewhere", "none"),
    ("consumer policy refuses a tag", "on_circle", "nlap_rank2"),
    ("same tag without the policy", "on_circle", "none"),
    ("open frontier is pending, never imported", "frontier", "nlap_rank2"),
]


def record_json(record: Record) -> dict:
    return {"id": record.id, "kind": record.kind.value, "statement": record.statement, "scope": record.scope,
            "depends_on": [[e.record_id, e.expected_claim, e.use_site, e.scope_relation, e.required_outcome] for e in record.depends_on],
            "evidence": [list(pair) for pair in record.evidence], "tags": sorted(record.tags)}


def vectors() -> dict:
    ledger = {key: record_json(r) for key, r in LEDGER.items()}
    validation = {}
    for key, r in LEDGER.items():
        checked = validate(r)
        validation[key] = {"kind": checked.kind.value, "reason": checked.field("reason") if checked.kind is Kind.REJECTED else None,
                           "identity": identity(r), "digest": digest(r)}
    closures = []
    for name, root, policy in CASES:
        c = close(LEDGER, KEYS[root], POLICIES[policy])
        closures.append({"name": name, "root": KEYS[root], "root_label": root, "policy": policy, "complete": c.complete,
                         "reached": list(c.reached), "missing_links": [[m.record_id, m.reason] for m in c.missing_links]})
    return {"format": "finite_proof_records vectors 2", "labels": KEYS, "ledger": ledger, "validation": validation, "closures": closures}


def render() -> str:
    return json.dumps(vectors(), indent=2, sort_keys=True) + "\n"


def pinned_key() -> str:
    """The record the boot gate pins: the lexicographically first ledger entry
    stored under its own identifier, so the choice is a rule rather than a
    preference and it is never one of the deliberately malformed specimens."""
    return min(key for key, record in LEDGER.items() if key == record.id)


def render_known_answers() -> str:
    """`proof_records/known_answers.py`, the constants the import-time self-test
    checks. Generated from the same reference ledger as the fixture, so the two
    cannot disagree, and committed, so a codec change is a diff somebody
    accepts rather than a self-test that agrees with itself."""
    record = LEDGER[pinned_key()]
    lines = [
        '"""The known answers of the import-time self-test. Generated; do not edit.',
        "",
        "Written by tools/make_vectors.py from the reference ledger that also produces",
        "fixtures/vectors.json. `make_vectors.py --check` fails when a regeneration",
        "differs from the committed file, which is what keeps these from being",
        "constants the code agrees with by construction.",
        '"""',
        "",
        "from __future__ import annotations",
        "",
        "from proof_records.records import Edge, Kind",
        "",
        f"RECORD_ID = {record.id!r}",
        f"RECORD_KIND = Kind({record.kind.value!r})",
        f"RECORD_STATEMENT = {record.statement!r}",
        f"RECORD_SCOPE = {record.scope!r}",
    ]
    edges = [f"    Edge({e.record_id!r}, {e.expected_claim!r}, {e.use_site!r}, {e.scope_relation!r}, {e.required_outcome!r}),"
             for e in record.depends_on]
    lines += ["RECORD_DEPENDS_ON = ()"] if not edges else ["RECORD_DEPENDS_ON = (", *edges, ")"]
    lines += [
        f"RECORD_EVIDENCE = {tuple(record.evidence)!r}",
        f"RECORD_TAGS = {tuple(sorted(record.tags))!r}",
        "",
        f"PREIMAGE_HEX = {preimage_bytes(record).hex()!r}",
        f"IDENTITY = {identity(record)!r}",
        f"DIGEST = {digest(record)!r}",
        "",
    ]
    return "\n".join(lines)


OUTPUTS = ((lambda: FIXTURE, render), (lambda: KNOWN, render_known_answers))


def main(argv: list[str]) -> int:
    checking = argv[1:] == ["--check"]
    stale = []
    for path_of, render_one in OUTPUTS:
        path, text = path_of(), render_one()
        name = path.relative_to(ROOT)
        if checking:
            current = path.read_text(encoding="utf-8") if path.exists() else ""
            print(f"{name} is up to date" if current == text else f"{name} differs from the reference model")
            if current != text:
                stale.append(str(name))
            continue
        path.parent.mkdir(exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"wrote {name}")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
