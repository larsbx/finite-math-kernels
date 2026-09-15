"""The committed fixture equals the regeneration and replays through the model."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records.records import Kind, Record, close, digest, validate  # noqa: E402
import make_vectors as mv  # noqa: E402


def load() -> dict:
    return json.loads(mv.FIXTURE.read_text(encoding="utf-8"))


def from_json(item: dict) -> Record:
    return Record(item["id"], Kind(item["kind"]), item["statement"], tuple(item["depends_on"]),
                  tuple(tuple(pair) for pair in item["evidence"]), frozenset(item["tags"]))


def test_fixture_is_current():
    assert mv.FIXTURE.read_text(encoding="utf-8") == mv.render()
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "make_vectors.py"), "--check"], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout


def test_fixture_replays_through_the_reference_model():
    data = load()
    assert data["format"] == "finite_proof_records vectors 1"
    ledger = {key: from_json(item) for key, item in data["ledger"].items()}
    assert ledger == mv.LEDGER
    for key, expected in data["validation"].items():
        checked = validate(ledger[key])
        assert checked.kind.value == expected["kind"]
        assert (checked.field("reason") if checked.kind is Kind.REJECTED else None) == expected["reason"]
        assert digest(ledger[key]) == expected["digest"]
    for case in data["closures"]:
        closure = close(ledger, case["root"], mv.POLICIES[case["policy"]])
        assert closure.complete == case["complete"], case["name"]
        assert list(closure.reached) == case["reached"], case["name"]
        assert [[m.record_id, m.reason] for m in closure.missing_links] == case["missing_links"], case["name"]


def test_fixture_covers_every_missing_link_reason_and_one_complete_closure():
    data = load()
    reasons = {link[1].split(":")[0] for case in data["closures"] for link in case["missing_links"]}
    assert reasons == {"unknown record", "ledger key differs from record identifier", "rejected", "pending",
                       "bounded experiment is evidence, not a theorem", "policy", "dependency cycle"}
    assert [case["name"] for case in data["closures"] if case["complete"]] == ["complete closure", "same tag without the policy"]
