"""Guard the independently generated Gram/exterior conformance corpus."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "tools/make_gram_geometry_vectors.py"
CORPUS = ROOT / "conformance/gram_geometry_v1.txt"


def test_gram_dataset_regenerates_without_drift():
    result = subprocess.run(
        [sys.executable, str(GENERATOR), "--check"],
        cwd=ROOT, capture_output=True, text=True, check=False
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_gram_dataset_retains_each_mathematical_falsifier():
    rows = [line.split("\t") for line in CORPUS.read_text(encoding="utf-8").splitlines()
            if line and not line.startswith("#")]
    assert len(rows) == 18
    for p in ("3", "5", "7"):
        cases = {row[2]: row for row in rows if row[1] == p}
        assert set(cases) == {
            "planar", "independent", "radical", "tangent", "null",
            "proportional"
        }
        assert cases["planar"][8:] == ["1", "0", "0"]
        assert cases["independent"][8] == "0"
        assert cases["independent"][-1] == "rejected"
        assert cases["radical"][7:10] == ["0", "0", "0"]
        assert cases["tangent"][6] == "0"
        assert cases["null"][9:] == ["rejected", "rejected"]
