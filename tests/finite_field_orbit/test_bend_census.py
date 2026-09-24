"""The Bend 2 challenger against the golden vectors, its refusals, and its determinism.

Runs in the polyglot environment (`pixi run test-orbit-bend`), which builds
`benchmarks/frontier/census.bend` with the Bend 2 `bend` on PATH and names the
binary FRONTIER_BEND_BIN. A missing binary fails the gate; it does not skip.
The sums check builds `tests/finite_field_orbit/census_sums.bend` with that
same `bend`.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from orbit_census_reference import decode  # noqa: E402

VECTORS = ROOT / "fixtures" / "orbit_census_v1.txt"


def bend(*args: object, threads: int = 4) -> str:
    """Bend's one line of output; any other shape, or a non-zero exit, fails the test."""
    binary = os.environ.get("FRONTIER_BEND_BIN", "")
    assert binary and Path(binary).is_file(), "set FRONTIER_BEND_BIN to the built Bend 2 challenger"
    out = subprocess.run([binary, "--threads", str(threads), "--", *map(str, args)],
                         capture_output=True, text=True, timeout=600, check=True).stdout
    line, tail = out.split("\n")
    assert tail == "", out
    return line


def cases(kind: str) -> list[list[str]]:
    rows = [row.split("\t") for row in VECTORS.read_text(encoding="utf-8").splitlines() if not row.startswith("#")]
    return [row[1:] for row in rows if row[0] == kind]


def census_lines() -> list[str]:
    return [line for (line,) in cases("census")]


@pytest.mark.parametrize("line", census_lines())
def test_bend_reproduces_every_census_vector(line):
    assert bend(*decode(line)[0]) == line


def test_both_multiply_paths_and_the_contract_edge_are_covered():
    blocks = [decode(line)[0] for line in census_lines()]
    assert any(b.p == 65521 and b.hi == 65521 for b in blocks)  # native squares only
    assert any(b.p == 2**32 - 5 and b.hi == b.p for b in blocks)  # 32-bit multiply, seeds near p - 1
    assert any(b.lo < 2**16 < b.hi for b in blocks)  # the switch between the two


def test_the_largest_u32_is_not_prime():
    assert bend(2**32 - 1, 0, 5, 0, 5) == "malformed:p"


def test_sums_past_2_to_the_32_render_exactly(tmp_path):
    """The two-half sums and their rendering: a carry, the bound p^2, and 2^64 - 1."""
    assert shutil.which("bend"), "the Bend 2 `bend` must be on PATH"
    binary = tmp_path / "census-sums"
    subprocess.run(["bend", str(ROOT / "tests" / "finite_field_orbit" / "census_sums.bend"), "-o", str(binary)],
                   check=True, timeout=600)
    out = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60, check=True).stdout
    p = 2**32 - 5
    head = f"orbit-census-v1 {p} 0 {p} 0 2 2 2"
    assert out.splitlines() == [f"{head} {2**32} {2**32} 0 1 0 0 1", f"{head} {p * p} {p * p} 0 1 0 0 1",
                                f"{head} {2**64 - 1} 0 0 1 0 0 1"]


@pytest.mark.parametrize(("field", "request_"), cases("request-malformed"))
def test_bend_refuses_malformed_requests_as_the_contract_orders_them(field, request_):
    assert bend(*request_.split(" ")) == f"malformed:{field}"


@pytest.mark.parametrize(("args", "reason"), [
    (("07", 3, 7, 0, 7), "malformed:p"), ((7, "+3", 7, 0, 7), "malformed:c"),
    ((7, 3, 2**32, 0, 7), "malformed:cap"), ((7, 3, 7, 0), "malformed:arity"),
    ((7, 3, 7, 0, 7, 7), "malformed:arity"), ((7, 3, 7, "x", 7), "malformed:lo"),
])
def test_arguments_must_be_canonical_decimals(args, reason):
    assert bend(*args) == reason


@pytest.mark.parametrize("line", census_lines()[-4:])
def test_the_record_is_the_same_at_every_thread_count(line):
    assert {bend(*decode(line)[0], threads=t) for t in (1, 2, 8)} == {line}
