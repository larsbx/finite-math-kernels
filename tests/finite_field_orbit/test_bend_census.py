"""The Bend 2 challenger against the golden vectors, its refusals, and its determinism.

Runs in the polyglot environment (`pixi run test-orbit-bend`), which builds
`benchmarks/frontier/census.bend` with the Bend 2 `bend` on PATH and names the
binary FRONTIER_BEND_BIN. A missing binary fails the gate; it does not skip.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from orbit_census_reference import decode  # noqa: E402

VECTORS = ROOT / "fixtures" / "orbit_census_v1.txt"
DOMAIN_P = 2**16  # section 3.6: Bend 2 answers p < 2^16


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


@pytest.mark.parametrize("line", [line for line in census_lines() if decode(line)[0].p < DOMAIN_P])
def test_bend_reproduces_every_vector_in_its_domain(line):
    assert bend(*decode(line)[0]) == line


def test_the_domain_edge_is_covered():
    assert any(decode(line)[0][::4] == (65521, 65521) for line in census_lines())  # p and hi


@pytest.mark.parametrize("line", [line for line in census_lines() if decode(line)[0].p >= DOMAIN_P])
def test_bend_refuses_what_it_cannot_hold(line):
    assert bend(*decode(line)[0]) == "unsupported:p"


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


@pytest.mark.parametrize("line", [line for line in census_lines() if decode(line)[0].p < DOMAIN_P][-4:])
def test_the_record_is_the_same_at_every_thread_count(line):
    assert {bend(*decode(line)[0], threads=t) for t in (1, 2, 8)} == {line}
