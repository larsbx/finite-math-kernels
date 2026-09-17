"""The claim ledger as a typed relationship graph.

Specification: docs/typed-relationship-graph-spec.md. A proof-record ledger
already is a graph: dependency edges, declared aliases, assumption sets. It
is stored as one kind of edge (``depends_on``) plus prose, so a relationship
that is not a dependency -- two names for one claim, a claim assumed by a
gate, a live result standing on a withdrawn one -- is readable but not
queryable.

This module re-types it in the vocabulary of `larsbx/tui-story`'s semantic
graph (nine edge types with a certainty score) and carries into it what an
LLM-asserted graph lacks: each edge states its provenance and its leaks, and
an edge whose provenance is ``theorem-backed`` must name the source that
backs it -- at the endpoint the provenance was read from, which for an
implication is the premise and not the conclusion -- or the export is refused. Nothing here decides mathematics; it
re-presents records the ledger already validated.
"""

from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass, field

from proof_records.records import BOUNDED, OPEN, Kind

FORMAT = "finite typed relationship graph 1"

#: The edge vocabulary of the tui-story semantic graph, in its declared order.
EDGE_TYPES = ("contradictory", "implicative", "hierarchical", "evolutionary",
              "analogous", "synonymous", "antonymous", "part-whole", "causal")

IMPLICATIVE, SYNONYMOUS, PART_WHOLE, CONTRADICTORY = "implicative", "synonymous", "part-whole", "contradictory"

THEOREM_BACKED = "theorem-backed"
#: Provenance classes, from the record itself rather than a consumer's status labels.
PROVENANCE = (THEOREM_BACKED, "conditional", "imported-theorem", "bounded-evidence", "open", "withdrawn", "declared")

CLAIM, ALIAS, ASSUMPTION_SET = "claim", "alias", "assumption_set"
#: What backs a record of each kind, mirroring records.REQUIRED_EVIDENCE: the
#: citation a theorem-backed edge must name.
CITATION_KEYS: Mapping[Kind, tuple[str, ...]] = {
    Kind.VERIFIED: ("replay", "digest"),
    Kind.REPOSITORY: ("source",),
    Kind.IMPORTED: ("source",),
    Kind.BOUNDED: ("domain",),
    Kind.PENDING: ("reason",),
    Kind.REJECTED: ("reason",),
}
#: Every edge here is read off a registry, never estimated, so certainty is exact.
CERTAIN = 1
#: For each edge type whose provenance is read from one endpoint's record, the
#: endpoint that must therefore carry the citation. An implication takes its
#: provenance from the premise it starts at, an alias edge and a membership edge
#: from the claim they end at and the member they start at. A contradictory edge
#: is provenance `withdrawn` by construction and names nothing.
BACKING: Mapping[str, str] = {IMPLICATIVE: "source", SYNONYMOUS: "target", PART_WHOLE: "source"}


class GraphError(ValueError):
    """The graph cannot be rendered; the message names every reason."""


@dataclass(frozen=True)
class Node:
    id: str
    kind: str
    label: str
    provenance: str
    statement: str = ""
    scope: str = ""
    record_kind: str = ""
    source: str = ""
    leaks: str = ""
    members: tuple[str, ...] = ()


@dataclass(frozen=True)
class Edge:
    type: str
    source: str
    target: str
    provenance: str
    certainty: int = CERTAIN
    use_site: str = ""
    leaks: str = ""


@dataclass(frozen=True)
class Graph:
    repository: str
    source: str
    nodes: tuple[Node, ...] = ()
    edges: tuple[Edge, ...] = field(default_factory=tuple)


def provenance(entry) -> str:
    """The provenance class of an analysed entry, from its own record: what
    backs it, not what a surface calls it."""
    if entry.withdrawn:
        return "withdrawn"
    if entry.outcome == OPEN:
        return "open"
    if entry.outcome == BOUNDED:
        return "bounded-evidence"
    if entry.record.kind is Kind.IMPORTED:
        return "imported-theorem"
    return THEOREM_BACKED if entry.closure.complete else "conditional"


def leaks(entry, unestablished: Sequence[str]) -> str:
    """What the entry does not carry: its declared leaks, else the reason it
    is open, else the premises its closure leaves unestablished."""
    declared = entry.record.field("leaks")
    if declared:
        return declared
    if entry.withdrawn or entry.outcome == OPEN:
        return entry.record.field("reason") or ""
    if unestablished:
        return "premises not established: " + ", ".join(unestablished)
    return ""


def _source(entry) -> str:
    """The evidence that backs the record, by its kind: the citation a
    theorem-backed edge must name."""
    record = entry.record
    return "; ".join(f"{key}: {record.field(key)}" for key in CITATION_KEYS[record.kind] if record.field(key))


def nodes(analysis) -> tuple[Node, ...]:
    """One node per claim, then one per declared alias, then one per
    assumption set, each group sorted by name, so every edge endpoint of the
    graph is a node of it."""
    ledger = analysis.ledger
    by_name = {e.name: e for e in analysis.entries}
    incomplete = {e.name: _unestablished(by_name, e) for e in analysis.entries}
    claims = [
        Node(e.name, CLAIM, ledger.status_labels.get(e.status, e.status), provenance(e), e.record.statement,
             e.record.scope, e.record.kind.value, _source(e), leaks(e, incomplete[e.name]))
        for e in analysis.entries
    ]
    aliases = [Node(alias, ALIAS, alias, "declared", members=(name,))
               for name in sorted(ledger.aliases) for alias in sorted(ledger.aliases[name])]
    sets = [Node(name, ASSUMPTION_SET, "assumption set", "declared", members=tuple(sorted(members)))
            for name, members in sorted(ledger.assumption_sets.items())]
    return tuple(sorted(claims, key=lambda n: n.id)) + tuple(aliases) + tuple(sets)


def _unestablished(by_name: Mapping[str, object], entry) -> tuple[str, ...]:
    """The entry's direct premises that are not themselves theorem-backed."""
    return tuple(sorted({name for name in entry.requires if provenance(by_name[name]) != THEOREM_BACKED}))


def edges(analysis) -> tuple[Edge, ...]:
    """Dependencies as implicative edges from premise to conclusion, aliases
    as synonymous edges, assumption-set membership as part-whole edges, and a
    live result standing on a withdrawn one as a contradictory edge."""
    by_name = {e.name: e for e in analysis.entries}
    name_of = {e.record.id: e.name for e in analysis.entries}
    out: list[Edge] = []
    for entry in analysis.entries:
        for dep in entry.record.depends_on:
            premise = by_name[name_of[dep.record_id]]
            mark = provenance(premise)
            out.append(Edge(IMPLICATIVE, premise.name, entry.name, mark, CERTAIN, dep.use_site,
                            "" if mark == THEOREM_BACKED else f"premise is {mark}"))
            if premise.withdrawn and not entry.withdrawn:
                out.append(Edge(CONTRADICTORY, premise.name, entry.name, "withdrawn", CERTAIN, dep.use_site,
                                "a live result stands on a withdrawn one"))
        for alias in analysis.ledger.aliases.get(entry.name, ()):
            out.append(Edge(SYNONYMOUS, alias, entry.name, provenance(entry), CERTAIN, "aliases"))
    for name, members in sorted(analysis.ledger.assumption_sets.items()):
        for member in sorted(members):
            out.append(Edge(PART_WHOLE, member, name, provenance(by_name[member]), CERTAIN, "assumption_sets"))
    return tuple(sorted(out, key=lambda e: (EDGE_TYPES.index(e.type), e.source, e.target, e.use_site)))


def refusals(graph: Graph) -> list[str]:
    """Reasons to refuse the graph: an unknown edge type or provenance, an
    edge whose endpoint is no node, or a theorem-backed edge whose backing
    record -- the endpoint its provenance was read from, per BACKING -- names
    no source."""
    sourced = {n.id: n.source for n in graph.nodes}
    claims = {n.id for n in graph.nodes if n.kind == CLAIM}
    problems: list[str] = []
    if len(sourced) != len(graph.nodes):
        problems.append("two nodes share an identifier: " + ", ".join(sorted({n.id for n in graph.nodes if sum(m.id == n.id for m in graph.nodes) > 1})))
    for node in graph.nodes:
        if node.provenance not in PROVENANCE:
            problems.append(f"{node.id}: unknown provenance {node.provenance!r}")
        if node.kind == ALIAS and node.id in claims:
            problems.append(f"{node.id}: alias collides with a claim name")
    for edge in graph.edges:
        where = f"{edge.type} {edge.source} -> {edge.target}"
        if edge.type not in EDGE_TYPES:
            problems.append(f"{where}: unknown edge type")
        if edge.provenance not in PROVENANCE:
            problems.append(f"{where}: unknown provenance {edge.provenance!r}")
        if edge.target not in sourced:
            problems.append(f"{where}: target is not a node")
        if edge.source not in sourced:
            problems.append(f"{where}: source is not a node")
        backing = BACKING.get(edge.type)
        if backing is not None and edge.provenance == THEOREM_BACKED:
            backer = getattr(edge, backing)
            if not sourced.get(backer):
                problems.append(f"{where}: theorem-backed edge whose claim names no source: {backer}")
    return problems


def build(analysis) -> Graph:
    """The typed graph of an analysed ledger, refused rather than rendered
    when any edge or node breaks the contract above."""
    graph = Graph(analysis.ledger.repository, analysis.ledger.source, nodes(analysis), edges(analysis))
    problems = refusals(graph)
    if problems:
        raise GraphError("typed graph refused:\n  " + "\n  ".join(problems))
    return graph


def _strip(record: Mapping[str, object]) -> dict[str, object]:
    """Drop empty optional fields so the surface carries only what is stated."""
    return {k: v for k, v in record.items() if v not in ("", (), [])}


def render(graph: Graph, generated: str) -> str:
    """The graph as deterministic JSON, one surface, newline-terminated."""
    body = {
        "format": FORMAT,
        "generated": generated,
        "repository": graph.repository,
        "source": graph.source,
        "edge_types": list(EDGE_TYPES),
        "provenance_classes": list(PROVENANCE),
        "nodes": [_strip(asdict(n)) for n in graph.nodes],
        "edges": [_strip(asdict(e)) for e in graph.edges],
    }
    return json.dumps(body, indent=2, ensure_ascii=False) + "\n"
