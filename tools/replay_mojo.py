#!/usr/bin/env python3
"""Replay fixtures/vectors.json through the Mojo implementation and compare.

Writes the vectors as the tab-separated transcript that
``tests/replay_vectors.mojo`` reads, runs it under ``mojo run -I .``, and
compares every validation result, canonical digest (SHA-256 of the octets
the Mojo side prints), and closure with the fixture. Nothing printed by
Mojo is parsed into a number except the complete flag and list counts.

Usage:
    replay_mojo.py               run ``mojo`` and compare
    replay_mojo.py TRANSCRIPT    compare a saved Mojo output transcript

Exit status 0 on agreement, 1 on any mismatch, 2 when ``mojo`` is unavailable.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "fixtures" / "vectors.json"
DRIVER = ROOT / "tests" / "replay_vectors.mojo"
POLICIES = {"none": [], "nlap_rank2": [("uses_rank2_circle", "rank-2 circle primitive rejected")]}


def load() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def _clean(*values: str) -> list[str]:
    for value in values:
        if "\t" in value or "\n" in value:
            raise ValueError(f"vector string contains a separator: {value!r}")
    return list(values)


def input_lines(data: dict) -> list[str]:
    lines = []
    for name, pairs in POLICIES.items():
        lines.append("\t".join(["P", name, str(len(pairs)), *(x for pair in pairs for x in _clean(*pair))]))
    for key, r in data["ledger"].items():
        fields = ["R", key, *_clean(r["id"], r["kind"], r["statement"]), str(len(r["depends_on"])), *_clean(*r["depends_on"]),
                  str(len(r["evidence"])), *(x for pair in r["evidence"] for x in _clean(*pair)), str(len(r["tags"])), *_clean(*r["tags"])]
        lines.append("\t".join(fields))
    for case in data["closures"]:
        lines.append("\t".join(["C", case["root"], case["policy"]]))
    return lines


def expected_lines(data: dict) -> list[str]:
    lines = []
    for key, v in data["validation"].items():
        lines.append("\t".join(["V", key, v["kind"], v["reason"] or "", v["digest"]]))
    for case in data["closures"]:
        lines.append("\t".join(["C", case["root"], "1" if case["complete"] else "0", ",".join(case["reached"]), str(len(case["missing_links"])),
                                *(x for link in case["missing_links"] for x in link)]))
    return lines


def normalize(actual: list[str]) -> list[str]:
    """Replace the octet field of each V line by the SHA-256 of those bytes."""
    out = []
    for line in actual:
        fields = line.split("\t")
        if fields[0] == "V" and len(fields) == 5:
            octets = bytes(int(o) for o in fields[4].split(".")) if fields[4] else b""
            fields[4] = hashlib.sha256(octets).hexdigest()
        out.append("\t".join(fields))
    return out


def compare(actual: list[str], data: dict | None = None) -> list[str]:
    expected = expected_lines(data or load())
    got = normalize(actual)
    errors = []
    if len(got) != len(expected):
        errors.append(f"transcript has {len(got)} lines, expected {len(expected)}")
    for lineno, (want, have) in enumerate(zip(expected, got), start=1):
        if want != have:
            errors.append(f"line {lineno}: expected {want!r}, got {have!r}")
    return errors


def run_mojo(data: dict) -> list[str] | None:
    mojo = shutil.which("mojo")
    if mojo is None:
        return None
    with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False, encoding="utf-8") as handle:
        handle.write("\n".join(input_lines(data)) + "\n")
        path = handle.name
    env = dict(os.environ, REPLAY_INPUT=path)
    result = subprocess.run([mojo, "run", "-I", str(ROOT), str(DRIVER)], cwd=ROOT, env=env, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"mojo replay failed with status {result.returncode}:\n{result.stderr}")
    return [line for line in result.stdout.splitlines() if line.strip()]


def main(argv: list[str]) -> int:
    data = load()
    if len(argv) > 1:
        actual = [line for line in Path(argv[1]).read_text(encoding="utf-8").splitlines() if line.strip()]
    else:
        actual = run_mojo(data)
        if actual is None:
            print("mojo is not on PATH; run inside `pixi run` or pass a saved transcript.")
            return 2
    errors = compare(actual, data)
    if errors:
        print("Mojo implementation disagrees with fixtures/vectors.json:\n")
        print("\n".join(errors))
        return 1
    print(f"OK: Mojo replay agrees with the reference on {len(data['ledger'])} records and {len(data['closures'])} closures.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
