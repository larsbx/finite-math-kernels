"""The Mojo implementation replays the vectors; the harness checks itself first."""

from __future__ import annotations

import hashlib
import shutil
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records.records import canonical_bytes  # noqa: E402
import make_vectors as mv  # noqa: E402
import replay_mojo as replay  # noqa: E402


def test_transcript_round_trips_every_vector():
    data = replay.load()
    lines = replay.input_lines(data)
    assert lines[0] == "P\tnone\t0"
    assert sum(line.startswith("R\t") for line in lines) == len(data["ledger"])
    assert sum(line.startswith("C\t") for line in lines) == len(data["closures"])
    assert all(len(line.split("\t")) >= 3 for line in lines)


def reference_transcript(data: dict) -> list[str]:
    """What the Mojo driver must print, computed from the Python reference in fixture order."""
    lines = []
    for key in data["ledger"]:
        record = mv.LEDGER[key]
        checked = mv.validate(record)
        reason = checked.field("reason") if checked.kind is mv.Kind.REJECTED else ""
        octets = ".".join(str(b) for b in canonical_bytes(record))
        lines.append("\t".join(["V", key, checked.kind.value, reason or "", octets]))
    for case in data["closures"]:
        closure = mv.close(mv.LEDGER, case["root"], mv.POLICIES[case["policy"]])
        lines.append("\t".join(["C", case["root"], "1" if closure.complete else "0", ",".join(closure.reached),
                                 str(len(closure.missing_links)), *(x for m in closure.missing_links for x in (m.record_id, m.reason))]))
    return lines


def test_expected_lines_are_what_the_reference_would_print():
    data = replay.load()
    assert replay.compare(reference_transcript(data), data) == []
    digest = hashlib.sha256(canonical_bytes(mv.CENSUS)).hexdigest()
    assert data["validation"]["census"]["digest"] == digest


def test_harness_rejects_a_corrupted_transcript():
    data = replay.load()
    good = reference_transcript(data)
    tampered = list(good)
    fields = tampered[-1].split("\t")
    fields[2] = "1" if fields[2] == "0" else "0"
    tampered[-1] = "\t".join(fields)
    errors = replay.compare(tampered, data)
    assert len(errors) == 1 and errors[0].startswith(f"line {len(good)}")
    assert replay.compare(good[:-1], data) != []


@pytest.mark.skipif(shutil.which("mojo") is None, reason="mojo binary not on PATH")
def test_mojo_implementation_replays_the_vectors():
    data = replay.load()
    actual = replay.run_mojo(data)
    assert actual is not None
    assert replay.compare(actual, data) == []
