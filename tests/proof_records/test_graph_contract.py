"""The approved normative contract and its canonical vector stay in sync."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "contracts/typed-proof-graph-normalization-v1.json"


def load_vector_tool():
    spec = importlib.util.spec_from_file_location("graph_contract_vector", ROOT / "tools/make_graph_contract_vector.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_approved_contract_pins_source_and_questions() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract["contract_id"] == "finite-proof-graph.normalization"
    assert contract["contract_version"] == "1.0.0"
    assert contract["status"] == "approved"
    assert contract["authoritative_questions"] == [
        "contract_interpretation", "normal_form", "composition_preservation"
    ]
    assert set(contract["excluded_questions"]) >= {
        "mathematical_proof", "certificate_acceptance", "effect_authorization", "persisted_state"
    }


def test_input_digest_and_expected_vector_are_domain_owned() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    vector = next(item for item in contract["vectors"] if item["id"] == "relationship-graph-example-v1")
    source = ROOT / vector["input"]
    expected = ROOT / vector["expected"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == vector["input_sha256"]
    assert expected.read_text(encoding="utf-8") == load_vector_tool().render()


def test_minimal_vector_is_a_normalization_fixed_point() -> None:
    tool = load_vector_tool()
    source = json.loads((ROOT / "fixtures/oracle/typed-proof-graph-minimal-v1.input.json").read_text())
    expected = json.loads((ROOT / "fixtures/oracle/typed-proof-graph-minimal-v1.expected.json").read_text())
    assert tool.normalize(source) == expected
    assert tool.normalize(expected) == expected
