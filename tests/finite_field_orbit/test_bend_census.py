"""The Bend challenger against the golden vectors, and the measured reasons for its domain.

Runs in the polyglot environment (`pixi run test-orbit-bend`).
`bend` and `hvm` must be on PATH; a missing toolchain fails the gate, it does
not skip. Each run gets its own working directory, because `bend run-c`
writes a fixed `.out.hvm` into the current one.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from orbit_census_reference import Block, census, decode, encode  # noqa: E402

SOURCE = ROOT / "benchmarks" / "frontier" / "census.bend"
VECTORS = ROOT / "fixtures" / "orbit_census_v1.txt"
BEND_MAX_P = 4093


def bend(tmp_path: Path, *args: int) -> str:
    """The record line Bend prints; anything else in its output fails the test."""
    assert shutil.which("bend") and shutil.which("hvm"), "bend and hvm must be on PATH"
    out = subprocess.run(["bend", "run-c", str(SOURCE), *map(str, args)], cwd=tmp_path,
                         capture_output=True, text=True, timeout=600, check=True).stdout
    line, result, tail = out.split("\n")
    assert result.startswith("Result: ") and tail == "", out
    return line


def bend_domain_vectors() -> list[str]:
    lines = [row.split("\t")[1] for row in VECTORS.read_text(encoding="utf-8").splitlines() if row.startswith("census\t")]
    return [line for line in lines if decode(line)[0].p <= BEND_MAX_P]


@pytest.mark.parametrize("line", bend_domain_vectors())
def test_bend_reproduces_every_vector_in_its_domain(tmp_path, line):
    assert bend(tmp_path, *decode(line)[0]) == line


def test_bend_domain_covers_the_largest_prime_it_allows():
    assert any(decode(line)[0].p == BEND_MAX_P and decode(line)[0].hi == BEND_MAX_P for line in bend_domain_vectors())


def test_outside_its_domain_bend_is_silently_wrong(tmp_path):
    """Measured fact behind section 3.6: squares of seeds >= 4096 wrap mod 2^24."""
    b = Block(4099, 0, 4099, 4096, 4099)
    got = bend(tmp_path, *b)
    assert got != encode(b, census(b))
    assert got.split(" ")[1:6] == [str(v) for v in b]  # the echo is intact; only the answer is wrong


def test_arguments_of_2_to_the_24_are_refused_by_the_cli(tmp_path):
    """Arguments do not wrap (the CLI exits 2); only arithmetic does. The orchestrator refuses first anyway."""
    result = subprocess.run(["bend", "run-c", str(SOURCE), str(2**24 + 7), "3", "7", "0", "7"], cwd=tmp_path,
                            capture_output=True, text=True, timeout=600, check=False)
    assert result.returncode != 0 and "outside of range for U24" in result.stderr + result.stdout
