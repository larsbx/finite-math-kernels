"""Reference model of finite proof records and dependency closure.

Specification: docs/proof-records-specification.md. This module is the
executable form of that document: pure functions over immutable records. It
decides nothing about mathematics. It classifies records, validates their
finite evidence, verifies each record's identifier against its preimage,
serializes records canonically, and computes whether the dependency closure
of a root record is complete, naming every missing link when it is not.
Repository policy enters only as a predicate supplied by the caller.
"""

from __future__ import annotations

import hashlib
from collections.abc import Callable, Mapping
from dataclasses import dataclass, replace
from enum import Enum


class Kind(str, Enum):
    VERIFIED = "verified_finite_computation"
    REPOSITORY = "repository_theorem"
    IMPORTED = "imported_theorem"
    PENDING = "pending_dependency"
    BOUNDED = "bounded_experiment"
    REJECTED = "rejected"


REQUIRED_EVIDENCE: Mapping[Kind, frozenset[str]] = {
    Kind.VERIFIED: frozenset({"replay", "digest"}),
    Kind.REPOSITORY: frozenset({"source", "proof_reviewed"}),
    Kind.IMPORTED: frozenset({"source", "hypotheses_checked"}),
    Kind.PENDING: frozenset({"reason"}),
    Kind.BOUNDED: frozenset({"domain"}),
    Kind.REJECTED: frozenset({"reason"}),
}

TRUE = "true"
FORMAT = "finite_proof_record"
VERSION = "2"
ID_SUITE = "sha256:"
SAME_SCOPE = "same"
SCOPE_LITERAL = "scope="
ACCEPTED = "accepted"
BOUNDED = "bounded"
OPEN = "open"
REJECTED = "rejected"
OUTCOMES = frozenset({ACCEPTED, BOUNDED})


@dataclass(frozen=True)
class Edge:
    """An identity-bearing dependency: which record, what it must claim, where
    it is used, how its scope must relate to the user's, and which validation
    outcome the use requires (``accepted`` or ``bounded``)."""

    record_id: str
    expected_claim: str
    use_site: str
    scope_relation: str = SAME_SCOPE
    required_outcome: str = ACCEPTED

    def required_scope(self, own_scope: str) -> str | None:
        """The scope the dependency must declare, or None for an unknown relation."""
        if self.scope_relation == SAME_SCOPE:
            return own_scope
        if self.scope_relation.startswith(SCOPE_LITERAL):
            return self.scope_relation[len(SCOPE_LITERAL):]
        return None


@dataclass(frozen=True)
class Record:
    id: str
    kind: Kind
    statement: str
    scope: str = ""
    depends_on: tuple[Edge, ...] = ()
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


def outcome(record: Record) -> str:
    """The validation outcome of a validated record: ``rejected``, ``open``,
    ``bounded``, or ``accepted`` (policy is reported separately)."""
    return {Kind.REJECTED: REJECTED, Kind.PENDING: OPEN, Kind.BOUNDED: BOUNDED}.get(record.kind, ACCEPTED)


def _edge_rejection(record: Record) -> str | None:
    ids = [e.record_id for e in record.depends_on]
    if len(set(ids)) != len(ids) or record.id in ids:
        return "duplicate or self dependency"
    for e in record.depends_on:
        if e.required_scope(record.scope) is None:
            return "unknown scope relation: " + e.scope_relation
        if e.required_outcome not in OUTCOMES:
            return "unknown required outcome: " + e.required_outcome
        if e.required_outcome == BOUNDED and e.scope_relation != SAME_SCOPE:
            return "bounded dependency outside its own scope"
    return None


def validate(record: Record) -> Record:
    """Return the record unchanged if well-formed, else its REJECTED form.

    Fail closed, in the order of docs/proof-records-specification.md
    section 3: unknown kind; rejected without reason; empty statement or
    scope; duplicate evidence key; required evidence absent or empty (a
    present key carrying no value cites nothing); malformed
    dependency edges; imported theorem with unchecked hypotheses; repository
    theorem without a reviewed proof; an identifier that is not the digest
    of the record's preimage.
    """
    if not isinstance(record.kind, Kind):
        return rejected(record, "unknown record kind")
    if record.kind is Kind.REJECTED:
        return record if (record.field("reason") or "").strip() else rejected(record, "rejected without reason")
    if not record.statement or not record.scope:
        return rejected(record, "empty statement or scope")
    keys = [k for k, _ in record.evidence]
    if len(set(keys)) != len(keys):
        return rejected(record, "duplicate evidence key")
    supplied = {k for k, v in record.evidence if v.strip()}
    missing = sorted(REQUIRED_EVIDENCE[record.kind] - supplied)
    if missing:
        return rejected(record, "missing evidence: " + ", ".join(missing))
    edge_reason = _edge_rejection(record)
    if edge_reason is not None:
        return rejected(record, edge_reason)
    if record.kind is Kind.IMPORTED and record.field("hypotheses_checked") != TRUE:
        return rejected(record, "imported theorem with unchecked hypotheses")
    if record.kind is Kind.REPOSITORY and record.field("proof_reviewed") != TRUE:
        return rejected(record, "repository theorem without a reviewed proof")
    if record.id != identity(record):
        return rejected(record, "identifier does not match preimage")
    return record


def _chunk(text: str) -> bytes:
    data = text.encode("utf-8")
    return len(data).to_bytes(8, "big") + data


def _count(n: int) -> bytes:
    return n.to_bytes(8, "big")


def preimage_bytes(record: Record) -> bytes:
    """The record-ID preimage: every identity-bearing field except the
    identifier itself. Fixed field order, length-prefixed UTF-8, dependency
    order significant, evidence sorted by key, tags sorted."""
    parts = [_chunk(FORMAT), _chunk(VERSION), _chunk(record.kind.value), _chunk(record.statement), _chunk(record.scope)]
    parts.append(_count(len(record.depends_on)))
    parts += [_chunk(e.record_id) + _chunk(e.expected_claim) + _chunk(e.use_site) + _chunk(e.scope_relation) + _chunk(e.required_outcome)
              for e in record.depends_on]
    evidence = sorted(record.evidence)
    parts.append(_count(len(evidence)))
    parts += [_chunk(k) + _chunk(v) for k, v in evidence]
    tags = sorted(record.tags)
    parts.append(_count(len(tags)))
    parts += [_chunk(t) for t in tags]
    return b"".join(parts)


def identity(record: Record) -> str:
    """The identifier the record must carry: the SHA-256 suite over its preimage."""
    return ID_SUITE + hashlib.sha256(preimage_bytes(record)).hexdigest()


def canonical_bytes(record: Record) -> bytes:
    """The authoritative encoding: the preimage followed by the identifier, so a
    validator recomputes the preimage and verifies the identifier without circularity."""
    return preimage_bytes(record) + _chunk(record.id)


def digest(record: Record) -> str:
    return hashlib.sha256(canonical_bytes(record)).hexdigest()


def identified(record: Record) -> Record:
    """The record carrying the identifier its preimage determines."""
    return replace(record, id=identity(record))


def edge(target: Record, use_site: str, scope_relation: str = SAME_SCOPE, required_outcome: str = ACCEPTED) -> Edge:
    """An edge to ``target`` expecting exactly the claim it states."""
    return Edge(target.id, target.statement, use_site, scope_relation, required_outcome)


def close(ledger: Mapping[str, Record], root: str, policy: Policy = no_policy) -> Closure:
    """Dependency closure of ``root``; complete only if every reached record
    is validated, matches the edge that reached it in claim, scope, and
    outcome, is accepted by ``policy``, and the graph below the root is acyclic."""
    reached: list[str] = []
    links: list[MissingLink] = []
    stack: list[str] = []

    def visit(record_id: str, via: Edge | None, own_scope: str) -> None:
        """Links about the record itself are reported on its first visit and
        its dependencies walked once; links about the edge that reached it
        (claim, scope, outcome) are reported for every incoming edge."""
        if record_id in stack:
            links.append(MissingLink(record_id, "dependency cycle"))
            return
        first = record_id not in reached
        if first:
            reached.append(record_id)
        raw = ledger.get(record_id)
        if raw is None:
            if first:
                links.append(MissingLink(record_id, "unknown record"))
            return
        record = validate(raw)
        if record.id != record_id:
            if first:
                links.append(MissingLink(record_id, "ledger key differs from record identifier"))
            return
        if record.kind is Kind.REJECTED:
            if first:
                links.append(MissingLink(record_id, "rejected: " + (record.field("reason") or "")))
            return
        required = via.required_outcome if via is not None else ACCEPTED
        if via is not None:
            if record.statement != via.expected_claim:
                links.append(MissingLink(record_id, "claim mismatch: " + via.use_site))
            if record.scope != via.required_scope(own_scope):
                links.append(MissingLink(record_id, "scope mismatch: " + via.use_site))
        found = outcome(record)
        if found == OPEN:
            if first:
                links.append(MissingLink(record_id, "pending: " + (record.field("reason") or "")))
        elif found == BOUNDED and required != BOUNDED:
            links.append(MissingLink(record_id, "bounded experiment is evidence, not a theorem"))
        elif found == ACCEPTED and required != ACCEPTED:
            links.append(MissingLink(record_id, f"outcome mismatch: {via.use_site} requires {required}, found {found}"))
        if not first:
            return
        verdict = policy(record)
        if verdict is not None:
            links.append(MissingLink(record_id, "policy: " + verdict))
        stack.append(record_id)
        for dep in record.depends_on:
            visit(dep.record_id, dep, record.scope)
        stack.pop()

    visit(root, None, "")
    return Closure(root, not links, tuple(sorted(reached)), tuple(links))


def tag_policy(forbidden: Mapping[str, str]) -> Policy:
    """A policy that rejects any record carrying a forbidden tag, with the
    consumer's reason. The library ships no forbidden tags of its own."""
    def policy(record: Record) -> str | None:
        hits = sorted(record.tags & set(forbidden))
        return None if not hits else "; ".join(f"{t}: {forbidden[t]}" for t in hits)
    return policy
