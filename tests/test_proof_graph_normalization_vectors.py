import json
from pathlib import Path


VECTOR = Path("fixtures/ledger/proof-graph-normalization-v1.json")
EXCLUDED = {
    "mathematical_proof",
    "certificate_acceptance",
    "effect_authorization",
    "persisted_state",
}


def test_proof_graph_normalization_vectors_are_domain_owned_and_fail_closed():
    payload = json.loads(VECTOR.read_text())
    assert payload["contract_id"] == "finite-proof-graph-normalization"
    assert payload["contract_version"] == 1
    assert payload["owner"] == "finite-math-kernels proof-record replay"
    assert set(payload["authority"]["excludes"]) == EXCLUDED
    assert "certificate_acceptance" not in payload["authority"]["includes"]
    assert payload["normalization"]["payload_policy"] == (
        "preserve_provenance_scope_source_and_leaks"
    )
    assert {vector["id"] for vector in payload["vectors"]} == {
        "unordered-independent-records",
        "provenance-is-semantic",
        "exact-duplicate-collapses",
    }


def test_expected_edges_are_canonical_sorted_unique():
    payload = json.loads(VECTOR.read_text())
    for vector in payload["vectors"]:
        expected = [tuple(edge) for edge in vector.get("expected_edges", [])]
        assert expected == sorted(set(expected))
