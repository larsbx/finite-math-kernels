"""Behavioural tests of the reference model against docs/specification.md."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records.records import Kind, MissingLink, Record, canonical_bytes, close, digest, tag_policy, validate  # noqa: E402
import make_vectors as mv  # noqa: E402


def links(closure) -> list[tuple[str, str]]:
    return [(m.record_id, m.reason) for m in closure.missing_links]


# --- section 3: validation fails closed ------------------------------------------


def test_well_formed_records_validate_unchanged():
    for record in (mv.CENSUS, mv.DENSITY, mv.GALOIS, mv.SWEEP):
        assert validate(record) == record


def test_each_validation_rejection_names_its_reason():
    assert validate(mv.MALFORMED).field("reason") == "duplicate or self dependency"
    missing = Record("x", Kind.VERIFIED, "s", (), (("replay", "r"),))
    assert validate(missing).field("reason") == "missing evidence: digest"
    assert validate(mv.UNCHECKED).field("reason") == "imported theorem with unchecked hypotheses"
    assert validate(Record("", Kind.PENDING, "s", (), (("reason", "r"),))).field("reason") == "empty identifier or statement"
    dup = Record("x", Kind.PENDING, "s", (), (("reason", "a"), ("reason", "b")))
    assert validate(dup).field("reason") == "duplicate evidence key"
    assert validate(Record("x", Kind.REJECTED, "s")).field("reason") == "rejected without reason"
    assert validate(Record("x", "theorem", "s")).kind is Kind.REJECTED  # type: ignore[arg-type]


def test_rejection_is_idempotent():
    once = validate(mv.MALFORMED)
    assert validate(once) == once


# --- section 4: canonical serialization ------------------------------------------


def test_canonical_bytes_are_order_independent_for_sets_and_dependent_for_dependencies():
    a = Record("r", Kind.VERIFIED, "s", ("x", "y"), (("digest", "d"), ("replay", "p")), frozenset({"t1", "t2"}))
    b = Record("r", Kind.VERIFIED, "s", ("x", "y"), (("replay", "p"), ("digest", "d")), frozenset({"t2", "t1"}))
    c = Record("r", Kind.VERIFIED, "s", ("y", "x"), (("replay", "p"), ("digest", "d")), frozenset({"t2", "t1"}))
    assert canonical_bytes(a) == canonical_bytes(b) != canonical_bytes(c)
    assert digest(a) == hashlib.sha256(canonical_bytes(a)).hexdigest()


def test_canonical_bytes_layout():
    record = Record("id", Kind.PENDING, "st", ("d",), (("reason", "r"),), frozenset({"t"}))
    data = canonical_bytes(record)
    chunk = lambda s: len(s.encode()).to_bytes(8, "big") + s.encode()  # noqa: E731
    expected = (chunk("finite_proof_record") + chunk("1") + chunk("id") + chunk("pending_dependency") + chunk("st")
                + (1).to_bytes(8, "big") + chunk("d") + (1).to_bytes(8, "big") + chunk("reason") + chunk("r")
                + (1).to_bytes(8, "big") + chunk("t"))
    assert data == expected


# --- section 5: closure ----------------------------------------------------------


def test_complete_closure_over_verified_and_imported_records():
    closure = close(mv.LEDGER, "theorem")
    assert closure.complete and closure.reached == ("bsw", "census", "lemma", "theorem") and not closure.missing_links


def test_pending_bounded_unknown_rejected_and_cycles_are_named():
    assert links(close(mv.LEDGER, "conditional")) == [("galois", "pending: source pending")]
    assert links(close(mv.LEDGER, "evidence")) == [("sweep", "bounded experiment is evidence, not a theorem")]
    assert links(close(mv.LEDGER, "sweep")) == [("sweep", "bounded experiment is evidence, not a theorem")]
    assert links(close(mv.LEDGER, "dangling")) == [("nowhere", "unknown record")]
    assert links(close(mv.LEDGER, "mismatch")) == [("mismatch", "ledger key differs from record identifier")]
    assert links(close(mv.LEDGER, "bad")) == [("bad", "rejected: duplicate or self dependency")]
    assert links(close(mv.LEDGER, "unchecked")) == [("unchecked", "rejected: imported theorem with unchecked hypotheses")]
    assert links(close(mv.LEDGER, "a")) == [("a", "dependency cycle")]
    assert not close(mv.LEDGER, "a").complete


def test_every_missing_link_below_a_pending_record_is_reported():
    ledger = dict(mv.LEDGER)
    ledger["deep"] = Record("deep", Kind.PENDING, "pending with a broken support", ("nowhere",), (("reason", "open"),))
    ledger["top"] = Record("top", Kind.VERIFIED, "t", ("deep",), (("replay", "x"), ("digest", "y")))
    assert links(close(ledger, "top")) == [("deep", "pending: open"), ("nowhere", "unknown record")]


def test_policy_is_supplied_by_the_consumer():
    assert close(mv.LEDGER, "on_circle").complete
    refused = close(mv.LEDGER, "on_circle", mv.POLICIES["nlap_rank2"])
    assert links(refused) == [("circle", "policy: uses_rank2_circle: rank-2 circle primitive rejected")]
    two = tag_policy({"a": "reason a", "b": "reason b"})
    assert two(Record("r", Kind.VERIFIED, "s", (), (), frozenset({"b", "a"}))) == "a: reason a; b: reason b"
    assert two(mv.CENSUS) is None


def test_open_frontier_is_pending_never_imported():
    assert links(close(mv.LEDGER, "frontier", mv.POLICIES["nlap_rank2"])) == [("mlc", "pending: open frontier")]


def test_missing_link_is_a_value():
    assert MissingLink("x", "y") == MissingLink("x", "y")
