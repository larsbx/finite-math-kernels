"""Conformance tests for proof_records/graph.py against docs/typed-relationship-graph-spec.md."""

from __future__ import annotations

import copy
import json
import sys
from dataclasses import replace
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records import generate_ledgers as gl  # noqa: E402
from proof_records import graph as tg  # noqa: E402
import make_ledger_example as mle  # noqa: E402

FIXTURE = ROOT / "fixtures" / "ledger" / "relationship-graph.json"


def analysis(**changes):
    data = copy.deepcopy(mle.example())
    data.update(changes)
    return gl.analyse(gl.Ledger(
        repository=data["repository"], module=data["module"],
        records={n: gl.record_from_json(r) for n, r in data["records"].items()},
        assumption_sets={k: tuple(v) for k, v in data["assumption_sets"].items()},
        status_classes={**gl.DEFAULT_STATUS_CLASSES, **data["status_classes"]},
        status_labels=data["status_labels"], tla_dir=data["tla_dir"], index_path=data["index_path"],
        source="example.json", graph_path=data.get("graph_path", ""),
        aliases={k: tuple(v) for k, v in data["aliases"].items()}, surfaces={k: tuple(v) for k, v in data["surfaces"].items()},
    ))


ANALYSIS = analysis()
GRAPH = tg.build(ANALYSIS)


def edges_of(graph, kind):
    return [(e.source, e.target, e.provenance, e.leaks) for e in graph.edges if e.type == kind]


def node(graph, name):
    return next(n for n in graph.nodes if n.id == name)


# --- the committed example --------------------------------------------------


def test_the_committed_graph_is_the_rendered_one():
    assert FIXTURE.read_text(encoding="utf-8") == tg.render(GRAPH, gl.GENERATED.format(source="example.json"))


def test_the_surface_declares_its_vocabularies():
    body = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert body["format"] == tg.FORMAT
    assert tuple(body["edge_types"]) == tg.EDGE_TYPES
    assert tuple(body["provenance_classes"]) == tg.PROVENANCE


def test_every_edge_endpoint_is_a_node():
    ids = {n.id for n in GRAPH.nodes}
    assert all({e.source, e.target} <= ids for e in GRAPH.edges)


# --- typing ------------------------------------------------------------------


def test_a_dependency_is_an_implicative_edge_from_premise_to_conclusion():
    assert ("Lemma", "Theorem", "theorem-backed", "") in edges_of(GRAPH, tg.IMPLICATIVE)


def test_an_alias_is_a_synonymous_edge_carrying_the_claim_provenance():
    assert edges_of(GRAPH, tg.SYNONYMOUS) == [("4554 specimens", "Census", "theorem-backed", ""), ("PIP census", "Census", "theorem-backed", "")]


def test_assumption_set_membership_is_a_part_whole_edge():
    assert edges_of(GRAPH, tg.PART_WHOLE) == [("Galois", "GaloisAssumed", "open", "")]


def test_a_live_result_on_a_withdrawn_one_is_a_contradictory_edge_beside_its_dependency():
    assert edges_of(GRAPH, tg.CONTRADICTORY) == [("Retracted", "OnRetracted", "withdrawn", "a live result stands on a withdrawn one")]
    assert ("Retracted", "OnRetracted", "withdrawn", "premise is withdrawn") in edges_of(GRAPH, tg.IMPLICATIVE)


def test_no_contradictory_edge_when_the_dependent_is_withdrawn_too():
    data = copy.deepcopy(mle.example())
    data["records"]["OnRetracted"]["tags"] = sorted({*data["records"]["OnRetracted"]["tags"], gl.WITHDRAWN_TAG})
    data["records"]["OnRetracted"]["kind"] = "pending_dependency"
    data["records"]["OnRetracted"]["evidence"] = [["reason", "withdrawn with its premise"]]
    data["records"]["OnRetracted"]["id"] = ""
    record = gl.record_from_json(data["records"]["OnRetracted"])
    from proof_records.records import identified
    data["records"]["OnRetracted"]["id"] = identified(record).id
    assert edges_of(tg.build(analysis(records=data["records"])), tg.CONTRADICTORY) == []


# --- provenance and leaks ----------------------------------------------------


@pytest.mark.parametrize("name,expected", [
    ("Census", "theorem-backed"), ("Density", "imported-theorem"), ("Galois", "open"),
    ("Sweep", "bounded-evidence"), ("Conditional", "conditional"), ("Retracted", "withdrawn"),
])
def test_provenance_comes_from_the_record_not_from_a_status_label(name, expected):
    assert node(GRAPH, name).provenance == expected


def test_a_conditional_claim_leaks_the_premises_it_does_not_establish():
    assert node(GRAPH, "Conditional").leaks == "premises not established: Galois"


def test_an_open_claim_leaks_the_reason_it_is_pending():
    assert node(GRAPH, "Galois").leaks == next(v for k, v in ANALYSIS.ledger.records["Galois"].evidence if k == "reason")


def test_a_theorem_backed_claim_leaks_nothing():
    assert node(GRAPH, "Census").leaks == ""


def test_the_node_source_is_the_evidence_its_kind_requires():
    assert node(GRAPH, "Census").source.startswith("replay: ")
    assert node(GRAPH, "Density").source.startswith("source: ")


def test_every_edge_is_declared_rather_than_estimated():
    assert {e.certainty for e in GRAPH.edges} == {tg.CERTAIN}


# --- fail closed --------------------------------------------------------------


def test_a_theorem_backed_edge_whose_claim_names_no_source_is_refused():
    stripped = replace(node(GRAPH, "Lemma"), source="")
    broken = replace(GRAPH, nodes=tuple(stripped if n.id == "Lemma" else n for n in GRAPH.nodes))
    assert any("theorem-backed edge whose claim names no source" in r for r in tg.refusals(broken))


def _without_source(graph, name):
    stripped = replace(node(graph, name), source="")
    return replace(graph, nodes=tuple(stripped if n.id == name else n for n in graph.nodes))


def _source_rule(graph) -> list[str]:
    return [r for r in tg.refusals(graph) if "names no source" in r]


def test_an_implication_is_backed_by_its_premise_not_its_conclusion():
    """`Proof -> Theorem` takes its provenance from Proof, so Proof is the
    node that must carry the citation. Checking Theorem instead accepts an
    unsourced theorem-backed premise and rejects a well-backed edge whose
    conclusion happens to name nothing -- wrong in both directions."""
    assert any("Proof -> Theorem" in r for r in _source_rule(_without_source(GRAPH, "Proof")))
    conclusion_only = _source_rule(_without_source(GRAPH, "Theorem"))
    assert not any("-> Theorem" in r for r in conclusion_only), conclusion_only


def test_an_alias_is_backed_by_the_claim_it_renames():
    """The other direction: a synonymous edge reads its provenance from the
    target, and the alias node carries no source of its own by construction."""
    assert any("-> Census" in r for r in _source_rule(_without_source(GRAPH, "Census")))
    assert node(GRAPH, "PIP census").source == ""
    assert not _source_rule(GRAPH)


def test_a_membership_edge_is_backed_by_its_member():
    backed = replace(next(e for e in GRAPH.edges if e.type == tg.PART_WHOLE), provenance=tg.THEOREM_BACKED)
    graph = replace(GRAPH, edges=tuple(backed if e.type == tg.PART_WHOLE else e for e in GRAPH.edges))
    assert not _source_rule(graph)
    assert any("Galois ->" in r for r in _source_rule(_without_source(graph, "Galois")))


def test_every_backing_endpoint_is_a_field_of_an_edge():
    assert set(tg.BACKING) <= set(tg.EDGE_TYPES)
    assert set(tg.BACKING.values()) == {"source", "target"}


def test_an_unknown_edge_type_or_provenance_is_refused():
    broken = replace(GRAPH, edges=(*GRAPH.edges, tg.Edge("guessed", "Census", "Lemma", "hunch")))
    assert [r.split(": ")[-1] for r in tg.refusals(broken)] == ["unknown edge type", "unknown provenance 'hunch'"]


def test_an_edge_to_nothing_is_refused():
    broken = replace(GRAPH, edges=(*GRAPH.edges, tg.Edge(tg.IMPLICATIVE, "Nowhere", "Nothing", "open")))
    assert sorted(r.split(": ")[-1] for r in tg.refusals(broken)) == ["source is not a node", "target is not a node"]


def test_an_alias_that_collides_with_a_claim_is_refused():
    broken = replace(GRAPH, nodes=(*GRAPH.nodes, tg.Node("Census", tg.ALIAS, "Census", "declared")))
    assert any("alias collides with a claim name" in r for r in tg.refusals(broken))
    assert any("two nodes share an identifier" in r for r in tg.refusals(broken))


def test_build_raises_rather_than_rendering_a_refused_graph(monkeypatch):
    monkeypatch.setattr(tg, "edges", lambda a: (tg.Edge(tg.IMPLICATIVE, "Nowhere", "Nothing", "open"),))
    with pytest.raises(tg.GraphError, match="typed graph refused"):
        tg.build(ANALYSIS)


# --- wiring into the generator -------------------------------------------------


def test_the_graph_is_a_generated_surface_only_when_a_path_is_declared():
    assert gl.output_paths(ANALYSIS.ledger)[-1] == "relationship-graph.json"
    assert "relationship-graph.json" not in gl.output_paths(analysis(graph_path="").ledger)


def test_a_graph_path_outside_the_root_or_over_another_surface_is_refused():
    for bad, message in (("/etc/graph.json", "must be a normalized path"), ("tla/Example.tla", r"collides with a generated TLA\+ file"),
                         ("ledger-index.md", "collides with index_path")):
        with pytest.raises(gl.LedgerError, match=message):
            analysis(graph_path=bad)
