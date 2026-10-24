"""Schema-level claim-boundary checks for the exact RT contract (no promotion)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "schemas/hyperbolic_rt_contract_v1.json"


def test_rt_contract_declares_hypotheses_and_existing_evidence():
    spec = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert spec["schema_version"] == 1
    assert spec["characteristics"]["witt_index"] == 4
    names = {r["name"] for r in spec["theorems"]}
    assert names == {
        "projective_spread", "orthogonal_reflection", "two_reflection_transport",
        "nonzero_norm_shell_count", "batch_inverse",
    }
    for entry in spec["theorems"]:
        assert entry["domain"]
        assert (ROOT / entry["evidence"].split("#",1)[0]).is_file()
    for key in ("scalar","batch","max","golden_vectors","generator","reference"):
        assert (ROOT / spec["implementation"][key]).is_file()
    assert any(x["name"] == "triple_spread_nonplanar" for x in spec["falsifiers"])
    assert "No field-generic theorem verification" in spec["claim_boundary"]
