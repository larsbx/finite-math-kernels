"""Verify named Gram/exterior contracts stay linked to real evidence."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def test_gram_contract_has_correct_guards_and_evidence():
    o=json.loads((ROOT/"schemas/gram_geometry_contract_v1.json").read_text(encoding="utf-8"))
    assert o["schema_version"] == 1
    ops={a["name"]:a for a in o["operations"]}
    assert set(ops)=={"gram2_determinant8","gram3_determinant8","normalized_gram3_determinant8","rank_le_two8","planar_triple_spread_defect8"}
    assert "Nx*Ny*Nz != 0" in ops["normalized_gram3_determinant8"]["domain"]
    assert "coordinate rank <= 2" in ops["planar_triple_spread_defect8"]["domain"]
    assert len(o["counterexamples"]) == 3
    for entry in o["operations"]:
        assert (ROOT/entry["evidence"].split("#")[0]).is_file()
    for k,v in o["evidence"].items():
        if k != "replay":
            assert (ROOT/v).is_file(),(k,v)
    assert "not formal field-generic proof" in o["authority"]
