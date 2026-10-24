"""Deterministic, independent hyperbolic RT corpus validation.

The upstream Mojo vector reader replays these same rows through the canonical
ExactField operations. Passing this test alone does not verify Mojo.
"""
from __future__ import annotations
import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "tools/make_hyperbolic_rt_vectors.py"
DATA = ROOT / "conformance/hyperbolic_rt_v1.txt"

def test_exact_rt_fixture_generated_without_drift():
    result = subprocess.run([sys.executable, str(GEN), "--check"],cwd=ROOT,capture_output=True,text=True)
    assert result.returncode == 0, result.stderr

def test_fixture_has_relevant_falsifiers_and_all_three_primes():
    rows = [row.split("\t") for row in DATA.read_text(encoding="utf-8").splitlines() if row and not row.startswith("#")]
    assert len(rows) == 48
    for p in ("3", "5", "7"):
        grouped = [row for row in rows if row[1] == p]
        assert len(grouped) == 16
        assert any(row[0] == "spread" and row[-1] == "rejected" for row in grouped)
        assert any(row[0] == "triple" and row[2] == "planar" and row[-1] == "0" for row in grouped)
        assert any(row[0] == "triple" and row[2] == "nonplanar" and row[-1] != "0" for row in grouped)
