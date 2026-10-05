"""The Python binding to the Mojo record codec, on the vectors the Mojo tests read.

`tests/certified_records/test_certified_records.mojo` checks the codec itself;
this checks only that values, reasons and rows cross the binding intact.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from certified_records.codec import Schema, decode, encode, first_mismatch, vector_cases

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


def test_64_bit_values_cross_the_binding_intact():
    assert decode(TOY, "toy-v1 4294967295 18446744073709551615") == (2**32 - 1, 2**64 - 1)
    assert encode(TOY, (0, 2**64 - 1)) == "toy-v1 0 18446744073709551615"


def test_first_mismatch_can_skip_a_prefix():
    a, b = decode(TOY, "toy-v1 1 2"), decode(TOY, "toy-v1 9 3")
    assert first_mismatch(TOY, a, b) == "mismatch:a" and first_mismatch(TOY, a, b, start=1) == "mismatch:b"


def test_vector_cases_skip_comments_and_keep_empty_columns():
    text = "# comment\nk\tx\t\nother\ty\nk\t\tz\n"
    assert vector_cases(text, "k") == [["x", ""], ["", "z"]]
