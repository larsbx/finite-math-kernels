"""Cross-repository known-answer boundary for Julia Oracle Lab.

This test executes the authoritative Mojo encoder. Expected bytes are vendored
from julia-oracle-lab's finite-integer.bigz.canonical-bytes fixture; a mismatch
fails here rather than transferring acceptance authority to Julia.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROBE = ROOT / "tests" / "finite_exact" / "julia_oracle_vectors.mojo"

EXPECTED = [
    "HEADER julia-oracle-bigint-known-answer 1 shared-finite-kernel",
    "zero 0.0.0.0.0.0.0.0.0",
    "one 1.0.0.0.0.0.0.0.1.1",
    "negative-billion-plus-one 2.0.0.0.0.0.0.0.4.59.154.202.1",
    "END",
]


def test_julia_oracle_bigint_known_answers_match_authoritative_mojo() -> None:
    mojo = shutil.which("mojo")
    assert mojo is not None, "mojo must be available in the canonical pixi/Woodpecker test environment"
    result = subprocess.run(
        [mojo, "run", "-I", str(ROOT), str(PROBE)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    actual = [line for line in result.stdout.splitlines() if line.strip()]
    assert actual == EXPECTED


def test_planted_corruption_is_not_the_authoritative_vector() -> None:
    corrupted = "negative-billion-plus-one 2.0.0.0.0.0.0.0.4.59.154.202.0"
    assert corrupted != EXPECTED[3]
