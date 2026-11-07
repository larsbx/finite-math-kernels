"""The approved normative contract and its canonical vector stay in sync."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "schemas/typed-proof-graph-normalization-v1.json"


def load_vector_tool():
    spec = importlib.util.spec_from_file_location("graph_contract_vector", ROOT / "tools/make_graph_contract_vector.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_approved_contract_pins_source_and_questions() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract["contract_id"] == "finite-proof-graph.normalization"
    assert contract["contract_version"] == "1.0.1"
    assert contract["status"] == "approved"
    assert contract["authoritative_questions"] == [
        "contract_interpretation", "normal_form", "composition_preservation"
    ]
    assert set(contract["excluded_questions"]) >= {
        "mathematical_proof", "certificate_acceptance", "effect_authorization", "persisted_state"
    }
    assert any("canonical edge identities" in item for item in contract["preconditions"])
    assert "provenance" in contract["normal_form"]["edges"]
    assert "conflicting payloads" in contract["normal_form"]["edges"]


def test_input_digest_and_expected_vector_are_domain_owned() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    vector = next(item for item in contract["vectors"] if item["id"] == "relationship-graph-example-v1")
    source = ROOT / vector["input"]
    expected = ROOT / vector["expected"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == vector["input_sha256"]
    assert expected.read_text(encoding="utf-8") == load_vector_tool().render()


def test_minimal_vector_is_a_normalization_fixed_point() -> None:
    tool = load_vector_tool()
    source = json.loads((ROOT / "conformance/oracle/typed-proof-graph-minimal-v1.input.json").read_text())
    expected = json.loads((ROOT / "conformance/oracle/typed-proof-graph-minimal-v1.expected.json").read_text())
    assert tool.normalize(source) == expected
    assert tool.normalize(expected) == expected


def test_exact_duplicate_edges_collapse_but_conflicting_identity_payloads_refuse() -> None:
    tool = load_vector_tool()
    source = json.loads((ROOT / "conformance/oracle/typed-proof-graph-minimal-v1.input.json").read_text())
    edge = dict(source["edges"][0])

    duplicate = dict(source)
    duplicate["edges"] = [edge, dict(edge)]
    normalized = tool.normalize(duplicate)
    assert normalized["edges"] == [edge]

    conflicting = dict(source)
    changed = dict(edge)
    changed["leaks"] = "different semantic payload"
    conflicting["edges"] = [edge, changed]
    with pytest.raises(ValueError, match="conflicting edges share canonical identity"):
        tool.normalize(conflicting)


@pytest.mark.parametrize("bad", [True, 1.0])
def test_contract_normalizer_rejects_non_integer_certainty(bad) -> None:
    tool = load_vector_tool()
    source = json.loads((ROOT / "conformance/oracle/typed-proof-graph-minimal-v1.input.json").read_text())
    source["edges"][0]["certainty"] = bad
    with pytest.raises(ValueError, match="certainty must be exactly the integer 1"):
        tool.normalize(source)


def test_numeric_payload_spellings_do_not_collapse_as_exact_duplicates() -> None:
    tool = load_vector_tool()
    source = json.loads((ROOT / "conformance/oracle/typed-proof-graph-minimal-v1.input.json").read_text())
    edge = dict(source["edges"][0])
    edge["payload_number"] = 1
    changed = dict(edge)
    changed["payload_number"] = 1.0
    source["edges"] = [edge, changed]
    with pytest.raises(ValueError, match="conflicting edges share canonical identity"):
        tool.normalize(source)
