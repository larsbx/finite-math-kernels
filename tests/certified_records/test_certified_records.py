"""The canonical record codec of `kernel/certified_records/codec.py` against
`conformance/certified_records_v1.txt`, the vectors the Mojo half reads too."""

from __future__ import annotations

from pathlib import Path

import pytest

from certified_records.codec import Schema, decode, encode, first_mismatch, parse_canonical, vector_cases

ROOT = Path(__file__).resolve().parents[2]
VECTORS = (ROOT / "conformance" / "certified_records_v1.txt").read_text(encoding="utf-8")
TOY = Schema("toy-v1", (("a", 32), ("b", 64)))


@pytest.mark.parametrize(("line",), vector_cases(VECTORS, "decode-ok"))
def test_well_formed_lines_round_trip(line):
    assert encode(TOY, decode(TOY, line)) == line


@pytest.mark.parametrize(("reason", "line"), vector_cases(VECTORS, "decode-malformed"))
def test_every_other_line_names_its_first_malformed_field(reason, line):
    with pytest.raises(ValueError, match=f"^malformed:{reason}$"):
        decode(TOY, line)


@pytest.mark.parametrize(("reason", "claimed", "actual"), vector_cases(VECTORS, "mismatch"))
def test_first_mismatch_names_the_first_differing_field(reason, claimed, actual):
    assert first_mismatch(TOY, decode(TOY, claimed), decode(TOY, actual)) == reason


def test_the_canonical_decimal_is_bounded_by_its_width():
    assert parse_canonical("4294967295", 32) == 2**32 - 1 and parse_canonical("4294967296", 32) is None
    assert parse_canonical("18446744073709551615", 64) == 2**64 - 1
    assert parse_canonical("18446744073709551616", 64) is None
    assert [parse_canonical(t, 64) for t in ("", "0", "00", "007", "+1", "-0", " 1", "1 ")] == [None, 0] + [None] * 6


def test_a_schema_refuses_widths_other_than_32_and_64():
    with pytest.raises(ValueError):
        Schema("bad-v1", (("a", 16),))


def test_first_mismatch_can_skip_a_prefix():
    a, b = decode(TOY, "toy-v1 1 2"), decode(TOY, "toy-v1 9 3")
    assert first_mismatch(TOY, a, b) == "mismatch:a" and first_mismatch(TOY, a, b, start=1) == "mismatch:b"


def test_vector_cases_skip_comments_and_keep_empty_columns():
    text = "# comment\nk\tx\t\nother\ty\nk\t\tz\n"
    assert vector_cases(text, "k") == [["x", ""], ["", "z"]]
