"""The Python oracle of the property probe: encoder, generator, comparison.

The full Mojo-versus-Python comparison runs when a ``mojo`` binary is on
PATH (always the case under ``pixi run test`` in CI).
"""

from __future__ import annotations

import shutil
import sys
from fractions import Fraction
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import property_oracle as oracle  # noqa: E402


def test_oracle_encoder_matches_documented_canonical_bytes():
    # docs/canonical-encoding.md golden vectors
    assert oracle.encode_z(-1000000001) == "2.0.0.0.0.0.0.0.4.59.154.202.1"
    assert oracle.encode_z(0) == "0.0.0.0.0.0.0.0.0"
    assert oracle.encode_z(1) == "1.0.0.0.0.0.0.0.1.1"
    assert oracle.encode_q(Fraction(1, 2)) == oracle.encode_z(1) + "." + oracle.encode_z(2)
    assert oracle.encode_q(Fraction(2, -4)) == oracle.encode_z(-1) + "." + oracle.encode_z(2)


def test_oracle_generator_is_deterministic_and_bounded():
    first, second = oracle.expected_lines(0), oracle.expected_lines(0)
    assert first == second
    assert first[0] == oracle.header(0) and first[-1] == "END"
    assert len(first) == 2 + oracle.Z_CASES + oracle.Q_CASES
    rng = oracle.Xorshift64Star(oracle.SEED)
    values = [oracle.random_int(rng) for _ in range(500)]
    assert all(abs(v) < oracle.BASE ** oracle.MAX_LIMBS for v in values)
    assert any(v < 0 for v in values) and any(0 <= v < 1000 for v in values)
    assert any(abs(v) >= oracle.BASE ** 4 for v in values)


def test_zq_transcript_is_a_prefix_of_the_full_transcript():
    zq, zqi = oracle.expected_lines(0), oracle.expected_lines()
    assert zq[1:-1] == zqi[1 : 1 + oracle.Z_CASES + oracle.Q_CASES]
    assert len(zqi) == len(zq) + oracle.I_CASES


def test_oracle_division_convention_truncates_toward_zero():
    assert oracle.trunc_divmod(-10, 3) == (-3, -1)
    assert oracle.trunc_divmod(10, -3) == (-3, 1)
    assert oracle.trunc_divmod(-10, -3) == (3, -1)
    assert oracle.trunc_divmod(0, 7) == (0, 0)


def test_oracle_rejects_a_corrupted_transcript():
    lines = oracle.expected_lines(0)
    assert oracle.compare(lines, 0) == []
    corrupted = list(lines)
    tokens = corrupted[1].split(" ")
    tokens[4] = tokens[3]  # a + b replaced by b
    corrupted[1] = " ".join(tokens)
    errors = oracle.compare(corrupted, 0)
    assert len(errors) == 1 and errors[0].startswith("line 2 token 4")
    assert oracle.compare(lines[:-1], 0) != []
    assert oracle.compare(lines) != []  # a zq transcript is not a zqi transcript


def test_layer_flag_selects_the_interval_case_count():
    assert oracle.parse_args(["oracle", "--layers", "zq"]) == (0, None, False)
    assert oracle.parse_args(["oracle", "--layers", "zqi", "t.txt"]) == (oracle.I_CASES, "t.txt", False)
    assert oracle.parse_args(["oracle"]) == (oracle.I_CASES, None, False)
    with pytest.raises(SystemExit):
        oracle.parse_args(["oracle", "--layers", "q"])


def test_the_distribution_flag_reports_phi_G_alone():
    assert oracle.parse_args(["oracle", "--layers", "zq", "--distribution"]) == (0, None, True)
    assert oracle.parse_args(["oracle", "--distribution"]) == (oracle.I_CASES, None, True)
    with pytest.raises(SystemExit):
        oracle.parse_args(["oracle", "--distribution", "t.txt"])


@pytest.mark.skipif(shutil.which("mojo") is None, reason="mojo binary not on PATH")
def test_mojo_probe_agrees_with_python_oracle():
    actual = oracle.run_probe()
    assert actual is not None
    assert oracle.compare(actual, 0) == []
