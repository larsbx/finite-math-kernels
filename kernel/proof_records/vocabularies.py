"""External evidence vocabularies mapped onto proof-record kinds.

Specification: docs/evidence-vocabulary-map.md, round-two item R4. Three
programs keep content-addressed evidence ledgers with different vocabularies.
This module is the executable form of the map between them: each external
class names the kind a receipt of that class becomes, the evidence keys the
translation must supply, and the authority the translation may not add.

The map only ever preserves or lowers authority. Translating a receipt never
makes a bounded exercise a theorem, never makes an unexecuted step a failure,
and never makes a failing test a malformed record; `validate` and `close` in
`proof_records.records` then apply their usual rules to the result.
"""

from __future__ import annotations

from dataclasses import dataclass
from collections.abc import Mapping

from proof_records.records import ACCEPTED, BOUNDED, OPEN, Kind, Record, identified, outcome

SPRUCEGOOSE = "larsbx/sprucegoose (docs/release-provenance.md, 'Evidence classes')"
CRYPTO_COMPOSER = "larsbx/crypto-composer (tdd_ledger.zig, `Status = enum { red, green }`)"


@dataclass(frozen=True)
class Translation:
    """How one external evidence class becomes a proof record.

    ``kind`` is the record kind a receipt of this class becomes, ``evidence``
    the keys the caller must supply beyond the kind's required set, and
    ``never`` the outcomes this class may never reach however the receipt
    reads. ``rationale`` states why, in the external system's own terms.
    """

    source: str
    external: str
    kind: Kind
    evidence: tuple[str, ...]
    never: frozenset[str]
    rationale: str

    @property
    def outcome(self) -> str:
        return outcome(Record("", self.kind, "s", "d"))


def _t(source: str, external: str, kind: Kind, evidence: tuple[str, ...], never: tuple[str, ...], rationale: str) -> Translation:
    return Translation(source, external, kind, evidence, frozenset(never), rationale)


VOCABULARY: Mapping[str, Translation] = {
    # --- sprucegoose: five evidence classes -----------------------------------------
    "Source/static PASS": _t(
        SPRUCEGOOSE, "Source/static PASS", Kind.VERIFIED, ("replay", "digest"), (BOUNDED, OPEN),
        "formatter, standalone compilation, and regressions on exact bytes: a replayable computation over named inputs"),
    "Boot-free behavioral PASS": _t(
        SPRUCEGOOSE, "Boot-free behavioral PASS", Kind.VERIFIED, ("replay", "digest"), (BOUNDED, OPEN),
        "codecs, in-memory inspection, CLI, and no-write accounting: replayable without booting the application"),
    "Dirty build exercise": _t(
        SPRUCEGOOSE, "Dirty build exercise", Kind.BOUNDED, ("domain",), (ACCEPTED,),
        "always non-transferable evidence, even if repeated bytes match, so it may close only its own enumerated domain"),
    "Transferable clean release": _t(
        SPRUCEGOOSE, "Transferable clean release", Kind.VERIFIED, ("replay", "digest"), (BOUNDED, OPEN),
        "a clean committed candidate built twice with identical declared inputs, byte-identical archives and receipts, validated against destination inventory"),
    "UNEXECUTED": _t(
        SPRUCEGOOSE, "UNEXECUTED", Kind.PENDING, ("reason",), (ACCEPTED, BOUNDED),
        "dependency or setup prevented execution: neither PASS nor implementation FAIL, so it is an open premise and never a rejection"),
    # --- crypto-composer: two ledger statuses ---------------------------------------
    "red": _t(
        CRYPTO_COMPOSER, "red", Kind.PENDING, ("reason",), (ACCEPTED, BOUNDED),
        "a recorded failing test is an open obligation, not a malformed record; the package has no `refuted` state and "
        "docs/proof-records-specification.md section 1 directs a consumer to record one as a pending dependency"),
    "green": _t(
        CRYPTO_COMPOSER, "green", Kind.VERIFIED, ("replay", "digest"), (BOUNDED, OPEN),
        "a green row is admitted only after a red row for the same test and only with `--run`, so it carries a command, "
        "an exit code, and the manifest digest of the tree it ran against"),
}

# Kinds with no faithful image in either external vocabulary. Neither system
# imports a mathematical theorem or proves one in its own repository, and
# `rejected` is malformed-record status, not an evidence class.
UNMAPPED: Mapping[Kind, str] = {
    Kind.REPOSITORY: "neither system carries a human-reviewed proof at a named location",
    Kind.IMPORTED: "neither system imports an external theorem with checked hypotheses",
    Kind.REJECTED: "a malformed record, not an evidence class; a failing or unexecuted step maps to pending_dependency",
}


def translate(external: str, statement: str, scope: str, evidence: Mapping[str, str], tags: frozenset[str] = frozenset()) -> Record:
    """The identified proof record for a receipt of class ``external``.

    Raises when the class is unknown or an evidence key the translation names
    is missing or empty, so a receipt never becomes a record with less
    evidence than its class requires.
    """
    if external not in VOCABULARY:
        raise KeyError(f"unknown evidence class {external!r}")
    rule = VOCABULARY[external]
    missing = sorted(k for k in rule.evidence if not evidence.get(k))
    if missing:
        raise ValueError(f"{external}: missing evidence {', '.join(missing)}")
    pairs = tuple(sorted((str(k), str(v)) for k, v in evidence.items()))
    return identified(Record("", rule.kind, statement, scope, (), pairs, tags))


def authority_preserved(external: str, record: Record) -> bool:
    """Whether the record's outcome is one the external class may reach."""
    rule = VOCABULARY[external]
    return outcome(record) not in rule.never
