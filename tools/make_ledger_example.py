#!/usr/bin/env python3
"""Regenerate the example ledger under fixtures/ledger/ and its generated surfaces.

The example names the records of `tools/make_vectors.py` plus a withdrawn
pending claim and a record that depends on it, so that every branch of
`tools/generate_ledgers.py` (proved, imported, bounded, open, withdrawn,
unreachable, assumption sets, status overrides) appears in the committed
output. `tests/proof_records/test_generate_ledgers.py` fails if the committed
files differ from the regeneration. Usage: make_ledger_example.py [--check]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records.records import Kind, Record, edge  # noqa: E402
import generate_ledgers as gl  # noqa: E402
import make_vectors as mv  # noqa: E402

DIR = ROOT / "fixtures" / "ledger"
LEDGER = DIR / "example.json"
POLICY = DIR / "policy.toml"

RETRACTED = mv.rec(Kind.PENDING, "retracted renewal lemma", mv.PISOT, tags=frozenset({gl.WITHDRAWN_TAG}), reason="withdrawn 2026-09-16")
ON_RETRACTED = mv.rec(Kind.VERIFIED, "depends on the retracted lemma", mv.PISOT, (edge(RETRACTED, "on_retracted/retracted"),),
                      tags=frozenset({gl.STATUS_TAG + "blocked"}), replay="x", digest="y")

RECORDS: dict[str, Record] = {
    "Census": mv.CENSUS, "Density": mv.DENSITY, "Galois": mv.GALOIS, "Sweep": mv.SWEEP, "Lemma": mv.LEMMA, "Theorem": mv.THEOREM,
    "Conditional": mv.CONDITIONAL, "WithinSweep": mv.WITHIN_SWEEP, "Retracted": RETRACTED, "OnRetracted": ON_RETRACTED,
}


def record_json(record: Record) -> dict:
    return {"id": record.id, "kind": record.kind.value, "statement": record.statement, "scope": record.scope,
            "depends_on": [[e.record_id, e.expected_claim, e.use_site, e.scope_relation, e.required_outcome] for e in record.depends_on],
            "evidence": [list(kv) for kv in record.evidence], "tags": sorted(record.tags)}


def example() -> dict:
    return {
        "format": gl.FORMAT,
        "repository": "larsbx/finite-math-kernels (example)",
        "module": "Example",
        "tla_dir": "tla",
        "index_path": "ledger-index.md",
        "assumption_sets": {"GaloisAssumed": ["Galois"]},
        "status_classes": {Kind.PENDING.value: "open-frontier"},
        "status_labels": {"proved": "theorem", "open-frontier": "open"},
        "records": {name: record_json(r) for name, r in RECORDS.items()},
    }


def main(argv: list[str]) -> int:
    check = "--check" in argv[1:]
    text = json.dumps(example(), indent=2, sort_keys=False) + "\n"
    if check:
        if not LEDGER.exists() or LEDGER.read_text(encoding="utf-8") != text:
            print(f"stale: {LEDGER}")
            return 1
    else:
        DIR.mkdir(parents=True, exist_ok=True)
        LEDGER.write_text(text, encoding="utf-8")
    args = ["generate_ledgers", str(LEDGER), "--out", str(DIR), "--claims", str(POLICY)] + (["--check"] if check else [])
    return gl.main(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
