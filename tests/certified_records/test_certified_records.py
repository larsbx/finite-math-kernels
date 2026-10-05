"""The Python binding to the Mojo record codec, on the vectors the Mojo tests read.

`tests/certified_records/test_certified_records.mojo` checks the codec itself;
this checks only that values, reasons and rows cross the binding intact.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
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


def _import_in(package_parent: Path, env: dict[str, str]) -> subprocess.CompletedProcess:
    probe = "from certified_records.codec import Schema, decode; print(decode(Schema('toy-v1', (('a', 32), ('b', 64))), 'toy-v1 1 2'))"
    return subprocess.run([sys.executable, "-c", probe], cwd=package_parent, env={**os.environ, **env},
                          capture_output=True, text=True, check=False)


def test_a_consumer_finds_its_own_build_under_any_include_root(tmp_path):
    """Vendored three levels below the consumer's root, the binding still finds the
    consumer's .build/certified_records_ext.so, or the one CERTIFIED_RECORDS_EXT names."""
    package_parent = tmp_path / "consumer" / "vendor" / "python" / "deep"
    shutil.copytree(ROOT / "kernel" / "certified_records", package_parent / "certified_records",
                    ignore=shutil.ignore_patterns("*.mojo", "__pycache__"))
    built = ROOT / ".build" / "certified_records_ext.so"
    (tmp_path / "consumer" / ".build").mkdir()
    shutil.copy2(built, tmp_path / "consumer" / ".build" / built.name)
    found = _import_in(package_parent, {})
    assert found.returncode == 0 and found.stdout.strip() == "(1, 2)", found.stderr
    (tmp_path / "consumer" / ".build" / built.name).unlink()
    named = _import_in(package_parent, {"CERTIFIED_RECORDS_EXT": str(built)})
    assert named.returncode == 0 and named.stdout.strip() == "(1, 2)", named.stderr
    missing = _import_in(package_parent, {})
    assert missing.returncode != 0 and "build-certified-records-py" in missing.stderr
