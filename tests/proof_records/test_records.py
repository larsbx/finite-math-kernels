"""Behavioural tests of the reference model against docs/proof-records-specification.md."""

from __future__ import annotations

import hashlib
import sys
from dataclasses import replace
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records.records import (Edge, Kind, MissingLink, Record, canonical_bytes, close, digest, edge, identified, identity,  # noqa: E402
                                   outcome, preimage_bytes, tag_policy, validate)
import make_vectors as mv  # noqa: E402


def links(closure) -> list[tuple[str, str]]:
    return [(m.record_id, m.reason) for m in closure.missing_links]


def pending(statement: str = "s", scope: str = "d", **kw) -> Record:
    return identified(Record("", Kind.PENDING, statement, scope, evidence=(("reason", "r"),), **kw))


# --- section 3: validation fails closed ------------------------------------------


def test_well_formed_records_validate_unchanged():
    for record in (mv.CENSUS, mv.DENSITY, mv.GALOIS, mv.SWEEP, mv.LEMMA, mv.WITHIN_SWEEP):
        assert validate(record) == record


def test_each_validation_rejection_names_its_reason():
    assert validate(mv.DUPLICATE_DEP).field("reason") == "duplicate or self dependency"
    assert validate(identified(Record("", Kind.VERIFIED, "s", "d", (), (("replay", "r"),)))).field("reason") == "missing evidence: digest"
    assert validate(mv.UNCHECKED).field("reason") == "imported theorem with unchecked hypotheses"
    assert validate(pending(statement="")).field("reason") == "empty statement or scope"
    assert validate(pending(scope="")).field("reason") == "empty statement or scope"
    dup = identified(Record("", Kind.PENDING, "s", "d", (), (("reason", "a"), ("reason", "b"))))
    assert validate(dup).field("reason") == "duplicate evidence key"
    assert validate(Record("x", Kind.REJECTED, "s")).field("reason") == "rejected without reason"
    assert validate(Record("x", "theorem", "s", "d")).kind is Kind.REJECTED  # type: ignore[arg-type]
    assert validate(mv.BAD_RELATION).field("reason") == "unknown scope relation: within"
    assert validate(mv.BAD_OUTCOME).field("reason") == "unknown required outcome: proved"
    assert validate(mv.BOUNDED_ELSEWHERE).field("reason") == "bounded dependency outside its own scope"


def test_identifier_is_verified_against_the_preimage():
    assert validate(mv.FORGED_ID).field("reason") == "identifier does not match preimage"
    assert validate(replace(mv.CENSUS, id="")).field("reason") == "identifier does not match preimage"
    assert validate(replace(mv.CENSUS, id="census")).field("reason") == "identifier does not match preimage"
    tampered = replace(mv.CENSUS, statement=mv.CENSUS.statement + " (edited)")
    assert validate(tampered).field("reason") == "identifier does not match preimage"
    assert validate(identified(tampered)) == identified(tampered)


def test_incomplete_open_and_bounded_records_keep_their_identity():
    for record in (mv.GALOIS, mv.SWEEP, mv.CONDITIONAL):
        assert validate(record) == record and record.id == identity(record)
        assert outcome(validate(record)) in {"open", "bounded", "accepted"}
    assert outcome(validate(mv.FORGED_ID)) == "rejected"


def test_rejection_is_idempotent():
    once = validate(mv.DUPLICATE_DEP)
    assert validate(once) == once


# --- section 4: identity and canonical serialization ------------------------------


def test_preimage_excludes_the_identifier_and_the_authoritative_encoding_appends_it():
    record = mv.CENSUS
    assert preimage_bytes(record) == preimage_bytes(replace(record, id="anything"))
    assert canonical_bytes(record) == preimage_bytes(record) + len(record.id.encode()).to_bytes(8, "big") + record.id.encode()
    assert identity(record) == "sha256:" + hashlib.sha256(preimage_bytes(record)).hexdigest()
    assert digest(record) == hashlib.sha256(canonical_bytes(record)).hexdigest()


def test_every_edge_field_is_identity_bearing():
    base = identified(Record("", Kind.VERIFIED, "s", "d", (edge(mv.CENSUS, "u", "scope=" + mv.SPECIMENS),), (("digest", "y"), ("replay", "x"))))
    e = base.depends_on[0]
    for changed in (replace(e, record_id="sha256:" + "1" * 64), replace(e, expected_claim="other"), replace(e, use_site="v"),
                    replace(e, scope_relation="same"), replace(e, required_outcome="bounded")):
        assert identity(replace(base, depends_on=(changed,))) != base.id
    assert identity(replace(base, scope="e")) != base.id


def test_canonical_bytes_are_order_independent_for_sets_and_dependent_for_dependencies():
    x, y = Edge("sha256:" + "1" * 64, "x", "u/x"), Edge("sha256:" + "2" * 64, "y", "u/y")
    a = identified(Record("", Kind.VERIFIED, "s", "d", (x, y), (("digest", "d"), ("replay", "p")), frozenset({"t1", "t2"})))
    b = identified(Record("", Kind.VERIFIED, "s", "d", (x, y), (("replay", "p"), ("digest", "d")), frozenset({"t2", "t1"})))
    c = identified(Record("", Kind.VERIFIED, "s", "d", (y, x), (("replay", "p"), ("digest", "d")), frozenset({"t2", "t1"})))
    assert canonical_bytes(a) == canonical_bytes(b) != canonical_bytes(c)


def test_canonical_bytes_layout():
    record = identified(Record("", Kind.PENDING, "st", "sc", (Edge("sha256:" + "1" * 64, "c", "u", "same", "accepted"),), (("reason", "r"),), frozenset({"t"})))
    chunk = lambda s: len(s.encode()).to_bytes(8, "big") + s.encode()  # noqa: E731
    count = lambda n: n.to_bytes(8, "big")  # noqa: E731
    preimage = (chunk("finite_proof_record") + chunk("2") + chunk("pending_dependency") + chunk("st") + chunk("sc")
                + count(1) + chunk("sha256:" + "1" * 64) + chunk("c") + chunk("u") + chunk("same") + chunk("accepted")
                + count(1) + chunk("reason") + chunk("r") + count(1) + chunk("t"))
    assert preimage_bytes(record) == preimage
    assert canonical_bytes(record) == preimage + chunk(record.id)


# --- section 5: closure ----------------------------------------------------------


def test_complete_closure_over_verified_and_imported_records():
    closure = close(mv.LEDGER, mv.THEOREM.id)
    assert closure.complete and closure.reached == tuple(sorted([mv.DENSITY.id, mv.CENSUS.id, mv.LEMMA.id, mv.THEOREM.id]))
    assert not closure.missing_links


def test_bounded_evidence_closes_only_its_own_scope_when_the_edge_asks_for_it():
    assert close(mv.LEDGER, mv.WITHIN_SWEEP.id).complete
    assert links(close(mv.LEDGER, mv.EVIDENCE_ONLY.id)) == [(mv.SWEEP.id, "bounded experiment is evidence, not a theorem")]
    assert links(close(mv.LEDGER, mv.SWEEP.id)) == [(mv.SWEEP.id, "bounded experiment is evidence, not a theorem")]
    assert links(close(mv.LEDGER, mv.WRONG_OUTCOME.id)) == [(mv.CENSUS.id, "outcome mismatch: wrong_outcome/census requires bounded, found accepted")]


def test_edges_bind_claim_and_scope():
    assert links(close(mv.LEDGER, mv.WRONG_CLAIM.id)) == [(mv.CENSUS.id, "claim mismatch: wrong_claim/census")]
    assert links(close(mv.LEDGER, mv.WRONG_SCOPE.id)) == [(mv.LEMMA.id, "scope mismatch: wrong_scope/lemma")]


def test_every_incoming_edge_to_a_shared_record_is_checked():
    assert links(close(mv.LEDGER, mv.DIAMOND.id)) == [(mv.LEMMA.id, "claim mismatch: diamond/lemma")]
    ok = close(mv.LEDGER, mv.DIAMOND_OK.id)
    assert ok.complete and ok.reached.count(mv.LEMMA.id) == 1
    twice_pending = identified(Record("", Kind.VERIFIED, "t", mv.PISOT, (edge(mv.CONDITIONAL, "t/conditional"), edge(mv.GALOIS, "t/galois")),
                                      (("digest", "y"), ("replay", "x"))))
    assert links(close({**mv.LEDGER, twice_pending.id: twice_pending}, twice_pending.id)) == [(mv.GALOIS.id, "pending: source pending")]


def test_pending_unknown_rejected_and_mismatched_links_are_named():
    assert links(close(mv.LEDGER, mv.CONDITIONAL.id)) == [(mv.GALOIS.id, "pending: source pending")]
    assert links(close(mv.LEDGER, mv.DANGLING.id)) == [(mv.NOWHERE, "unknown record")]
    assert links(close(mv.LEDGER, "mismatch")) == [("mismatch", "ledger key differs from record identifier")]
    assert links(close(mv.LEDGER, mv.DUPLICATE_DEP.id)) == [(mv.DUPLICATE_DEP.id, "rejected: duplicate or self dependency")]
    assert links(close(mv.LEDGER, mv.UNCHECKED.id)) == [(mv.UNCHECKED.id, "rejected: imported theorem with unchecked hypotheses")]
    assert links(close(mv.LEDGER, mv.FORGED_ID.id)) == [(mv.FORGED_ID.id, "rejected: identifier does not match preimage")]


def test_cycles_cannot_be_built_from_verified_identifiers_and_still_fail_closed():
    assert links(close(mv.LEDGER, mv.LOOP_A.id)) == [(mv.LOOP_A.id, "rejected: identifier does not match preimage")]
    with mock.patch("proof_records.records.validate", lambda record: record):
        assert links(close(mv.LEDGER, mv.LOOP_A.id)) == [(mv.LOOP_A.id, "dependency cycle")]
        assert not close(mv.LEDGER, mv.LOOP_A.id).complete


def test_every_missing_link_below_a_pending_record_is_reported():
    ledger = dict(mv.LEDGER)
    deep = identified(Record("", Kind.PENDING, "pending with a broken support", "d", (Edge(mv.NOWHERE, "x", "deep/nowhere"),), (("reason", "open"),)))
    top = identified(Record("", Kind.VERIFIED, "t", "d", (edge(deep, "top/deep"),), (("digest", "y"), ("replay", "x"))))
    ledger[deep.id] = deep
    ledger[top.id] = top
    assert links(close(ledger, top.id)) == [(deep.id, "pending: open"), (mv.NOWHERE, "unknown record")]


def test_policy_is_supplied_by_the_consumer():
    assert close(mv.LEDGER, mv.ON_CIRCLE.id).complete
    refused = close(mv.LEDGER, mv.ON_CIRCLE.id, mv.POLICIES["nlap_rank2"])
    assert links(refused) == [(mv.CIRCLE.id, "policy: uses_rank2_circle: rank-2 circle primitive rejected")]
    two = tag_policy({"a": "reason a", "b": "reason b"})
    assert two(Record("r", Kind.VERIFIED, "s", "d", (), (), frozenset({"b", "a"}))) == "a: reason a; b: reason b"
    assert two(mv.CENSUS) is None


def test_open_frontier_is_pending_never_imported():
    assert links(close(mv.LEDGER, mv.FRONTIER.id, mv.POLICIES["nlap_rank2"])) == [(mv.MLC.id, "pending: open frontier")]


def test_missing_link_is_a_value():
    assert MissingLink("x", "y") == MissingLink("x", "y")
