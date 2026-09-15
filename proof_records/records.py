"""Reference model of finite proof records and dependency closure.

Specification: docs/specification.md. This module is the executable form of
that document: pure functions over immutable records. It decides nothing
about mathematics. It classifies records, validates their finite evidence,
serializes them canonically, and computes whether the dependency closure of
a root record is complete, naming every missing link when it is not.
Repository policy enters only as a predicate supplied by the caller.
"""

from __future__ import annotations

import hashlib
from collections.abc import Callable, Mapping
from dataclasses import dataclass, replace
from enum import Enum


class Kind(str, Enum):
    VERIFIED = "verified_finite_computation"
    IMPORTED = "imported_theorem"
    PENDING = "pending_dependency"
    BOUNDED = "bounded_experiment"
    REJECTED = "rejected"


REQUIRED_EVIDENCE: Mapping[Kind, frozenset[str]] = {
    Kind.VERIFIED: frozenset({"replay", "digest"}),
    Kind.IMPORTED: frozenset({"source", "hypotheses_checked"}),
    Kind.PENDING: frozenset({"reason"}),
    Kind.BOUNDED: frozenset({"domain"}),
    Kind.REJECTED: frozenset({"reason"}),
}

TRUE = "true"


@dataclass(frozen=True)
class Record:
    id: str
    kind: Kind
    statement: str
    depends_on: tuple[str, ...] = ()
    evidence: tuple[tuple[str, str], ...] = ()
    tags: frozenset[str] = frozenset()

    def field(self, key: str) -> str | None:
        return dict(self.evidence).get(key)


@dataclass(frozen=True)
class MissingLink:
    record_id: str
    reason: str


@dataclass(frozen=True)
class Closure:
    root: str
    complete: bool
    reached: tuple[str, ...]
    missing_links: tuple[MissingLink, ...]


Policy = Callable[[Record], str | None]


def no_policy(record: Record) -> str | None:
    return None


def rejected(record: Record, reason: str) -> Record:
    return replace(record, kind=Kind.REJECTED, evidence=(("reason", reason),))


def validate(record: Record) -> Record:
    """Return the record unchanged if well-formed, else its REJECTED form.

    Fail closed: an unknown kind, a missing required evidence field, an
    empty identifier or statement, a duplicate evidence key, a duplicate or
    self dependency, or an imported theorem whose hypotheses are not marked
    checked all reject.
    """
    if not isinstance(record.kind, Kind):
        return rejected(record, "unknown record kind")
    if record.kind is Kind.REJECTED:
        return record if record.field("reason") else rejected(record, "rejected without reason")
    if not record.id or not record.statement:
        return rejected(record, "empty identifier or statement")
    keys = [k for k, _ in record.evidence]
    if len(set(keys)) != len(keys):
        return rejected(record, "duplicate evidence key")
    missing = sorted(REQUIRED_EVIDENCE[record.kind] - set(keys))
    if missing:
        return rejected(record, "missing evidence: " + ", ".join(missing))
    if len(set(record.depends_on)) != len(record.depends_on) or record.id in record.depends_on:
        return rejected(record, "duplicate or self dependency")
    if record.kind is Kind.IMPORTED and record.field("hypotheses_checked") != TRUE:
        return rejected(record, "imported theorem with unchecked hypotheses")
    return record


def _chunk(text: str) -> bytes:
    data = text.encode("utf-8")
    return len(data).to_bytes(8, "big") + data


def canonical_bytes(record: Record) -> bytes:
    """Deterministic encoding: fixed field order, length-prefixed UTF-8,
    evidence sorted by key, tags sorted; dependency order is significant."""
    parts = [_chunk("finite_proof_record"), _chunk("1"), _chunk(record.id), _chunk(record.kind.value), _chunk(record.statement)]
    parts.append(len(record.depends_on).to_bytes(8, "big"))
    parts += [_chunk(d) for d in record.depends_on]
    evidence = sorted(record.evidence)
    parts.append(len(evidence).to_bytes(8, "big"))
    parts += [_chunk(k) + _chunk(v) for k, v in evidence]
    tags = sorted(record.tags)
    parts.append(len(tags).to_bytes(8, "big"))
    parts += [_chunk(t) for t in tags]
    return b"".join(parts)


def digest(record: Record) -> str:
    return hashlib.sha256(canonical_bytes(record)).hexdigest()


def close(ledger: Mapping[str, Record], root: str, policy: Policy = no_policy) -> Closure:
    """Dependency closure of ``root``; complete only if every reached record
    is a validated VERIFIED or IMPORTED record accepted by ``policy`` and the
    dependency graph below the root is acyclic."""
    reached: list[str] = []
    links: list[MissingLink] = []
    stack: list[str] = []

    def visit(record_id: str) -> None:
        if record_id in stack:
            links.append(MissingLink(record_id, "dependency cycle"))
            return
        if record_id in reached:
            return
        reached.append(record_id)
        raw = ledger.get(record_id)
        if raw is None:
            links.append(MissingLink(record_id, "unknown record"))
            return
        record = validate(raw)
        if record.id != record_id:
            links.append(MissingLink(record_id, "ledger key differs from record identifier"))
            return
        if record.kind is Kind.REJECTED:
            links.append(MissingLink(record_id, "rejected: " + (record.field("reason") or "")))
            return
        if record.kind is Kind.PENDING:
            links.append(MissingLink(record_id, "pending: " + (record.field("reason") or "")))
        elif record.kind is Kind.BOUNDED:
            links.append(MissingLink(record_id, "bounded experiment is evidence, not a theorem"))
        verdict = policy(record)
        if verdict is not None:
            links.append(MissingLink(record_id, "policy: " + verdict))
        stack.append(record_id)
        for dep in record.depends_on:
            visit(dep)
        stack.pop()

    visit(root)
    return Closure(root, not links, tuple(sorted(reached)), tuple(links))


def tag_policy(forbidden: Mapping[str, str]) -> Policy:
    """A policy that rejects any record carrying a forbidden tag, with the
    consumer's reason. The library ships no forbidden tags of its own."""
    def policy(record: Record) -> str | None:
        hits = sorted(record.tags & set(forbidden))
        return None if not hits else "; ".join(f"{t}: {forbidden[t]}" for t in hits)
    return policy
