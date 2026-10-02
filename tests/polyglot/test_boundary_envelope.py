"""The polyglot boundary envelope fails closed: every accepted vector passes, every rejected one is refused."""

import json
from pathlib import Path

import pytest

from boundary_envelope import refusal

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "schemas/polyglot-boundary-envelope-v1.json").read_text())
VECTORS = json.loads((ROOT / "conformance/polyglot_boundary_envelope_v1.json").read_text())


@pytest.mark.parametrize("case", VECTORS["accepted"], ids=lambda c: c["name"])
def test_accepted(case):
    assert refusal(SCHEMA, case["value"]) is None


@pytest.mark.parametrize("case", VECTORS["rejected"], ids=lambda c: c["name"])
def test_rejected(case):
    assert refusal(SCHEMA, case["value"]) is not None


@pytest.mark.parametrize("value", [None, [], "envelope", 0])
def test_non_objects_refused(value):
    assert refusal(SCHEMA, value) is not None


def test_unsupported_schema_keyword_refused():
    """The validator understands a closed subset of JSON Schema; anything else is refused, never ignored."""
    assert refusal({"type": "object", "minProperties": 1}, {}) is not None


def test_vectors_name_this_boundary():
    assert VECTORS["boundary"] == SCHEMA["properties"]["boundary"]["const"]
