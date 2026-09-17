"""Conformance of the evidence-vocabulary map with docs/evidence-vocabulary-map.md."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from proof_records.records import (ACCEPTED, BOUNDED, Edge, Kind, OPEN, Record, close, edge, identified, identity,  # noqa: E402
                                   outcome, validate)
from proof_records.vocabularies import UNMAPPED, VOCABULARY, authority_preserved, translate  # noqa: E402

DOC = ROOT / "docs" / "evidence-vocabulary-map.md"
SPRUCEGOOSE = {"Source/static PASS", "Boot-free behavioral PASS", "Dirty build exercise", "Transferable clean release", "UNEXECUTED"}
CRYPTO_COMPOSER = {"red", "green"}
EVIDENCE = {"replay": "make check", "digest": "sha256:deadbeef", "domain": "one dirty tree", "reason": "toolchain absent"}


def payload(external: str) -> dict[str, str]:
    return {key: EVIDENCE[key] for key in VOCABULARY[external].evidence}


def record(external: str, statement: str = "s", scope: str = "d"):
    return translate(external, statement, scope, payload(external))


def test_both_source_vocabularies_are_covered_exactly():
    assert set(VOCABULARY) == SPRUCEGOOSE | CRYPTO_COMPOSER
    assert {t.external for t in VOCABULARY.values()} == set(VOCABULARY)
    assert {t.source for t in VOCABULARY.values() if t.external in SPRUCEGOOSE} == {VOCABULARY["UNEXECUTED"].source}
    assert {t.source for t in VOCABULARY.values() if t.external in CRYPTO_COMPOSER} == {VOCABULARY["red"].source}


def test_each_class_maps_to_the_documented_kind_and_outcome():
    expected = {
        "Source/static PASS": (Kind.VERIFIED, ACCEPTED), "Boot-free behavioral PASS": (Kind.VERIFIED, ACCEPTED),
        "Dirty build exercise": (Kind.BOUNDED, BOUNDED), "Transferable clean release": (Kind.VERIFIED, ACCEPTED),
        "UNEXECUTED": (Kind.PENDING, OPEN), "red": (Kind.PENDING, OPEN), "green": (Kind.VERIFIED, ACCEPTED),
    }
    assert {name: (t.kind, t.outcome) for name, t in VOCABULARY.items()} == expected


def test_translation_never_raises_authority_above_its_class():
    for external in VOCABULARY:
        built = record(external)
        assert outcome(built) not in VOCABULARY[external].never
        assert authority_preserved(external, built)
    assert ACCEPTED in VOCABULARY["Dirty build exercise"].never
    assert ACCEPTED in VOCABULARY["UNEXECUTED"].never and ACCEPTED in VOCABULARY["red"].never


def test_translated_records_validate_unchanged_and_carry_their_identity():
    for external in VOCABULARY:
        built = record(external)
        assert validate(built) == built
        assert built.id == identity(built)
        assert {k for k, _ in built.evidence} >= set(VOCABULARY[external].evidence)


def test_a_receipt_missing_its_required_evidence_is_refused():
    for external, rule in VOCABULARY.items():
        for key in rule.evidence:
            short = {k: v for k, v in payload(external).items() if k != key}
            with pytest.raises(ValueError, match=f"missing evidence {key}"):
                translate(external, "s", "d", short)
            with pytest.raises(ValueError):
                translate(external, "s", "d", {**payload(external), key: ""})
    with pytest.raises(KeyError):
        translate("Transferable dirty release", "s", "d", {})


def test_a_dirty_exercise_cannot_close_a_general_claim():
    dirty = record("Dirty build exercise", "archive bytes repeated", "one dirty tree")
    assert outcome(dirty) == BOUNDED

    def verified(statement: str, dependency: Edge):
        return identified(Record("", Kind.VERIFIED, statement, "one dirty tree", (dependency,),
                                 (("digest", "sha256:deadbeef"), ("replay", "make check"))))

    # Cited as a theorem, the exercise is a missing link.
    general = verified("the release is transferable", edge(dirty, "general/dirty"))
    closure = close({dirty.id: dirty, general.id: general}, general.id)
    assert not closure.complete
    assert [m.reason for m in closure.missing_links] == ["bounded experiment is evidence, not a theorem"]

    # The same evidence closes a bounded claim on the exercise's own scope.
    within = verified("the bytes repeated on this tree", Edge(dirty.id, dirty.statement, "within/dirty", "same", BOUNDED))
    assert close({dirty.id: dirty, within.id: within}, within.id).complete


def test_unmapped_kinds_have_no_row_and_are_documented():
    assert set(UNMAPPED) == {Kind.REPOSITORY, Kind.IMPORTED, Kind.REJECTED}
    assert not {t.kind for t in VOCABULARY.values()} & set(UNMAPPED)
    body = DOC.read_text(encoding="utf-8")
    for kind in UNMAPPED:
        assert f"`{kind.value}`" in body
    for external in VOCABULARY:
        assert f"`{external}`" in body


def test_the_document_states_the_authority_rule_and_the_red_unexecuted_asymmetry():
    body = DOC.read_text(encoding="utf-8")
    assert "preserves or lowers authority, never raises it" in body
    assert "a red row ran and failed, an unexecuted step never ran" in body
    assert "c211ff6" in body and "6b8ee2c" in body
