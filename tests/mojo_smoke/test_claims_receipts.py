"""The Mojo declarations print exactly the receipt lines the coverage check reads."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.skipif(shutil.which("mojo") is None, reason="mojo is not on PATH")
def test_receipts():
    out = subprocess.run(["mojo", "run", "-I", "kernel", "tests/mojo_smoke/test_claims.mojo"], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout.splitlines()
    assert out == ["claim-receipt: ExampleClaim",
                   "contract-receipt: receipts are printed after the assertions they stand behind"]
