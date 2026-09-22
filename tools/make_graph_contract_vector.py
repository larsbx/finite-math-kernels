"""Build or check the domain-owned proof-graph normalization vector."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "fixtures/ledger/relationship-graph.json"
EXPECTED = ROOT / "fixtures/oracle/typed-proof-graph-normalization-v1.json"


def normalize(value: dict) -> dict:
    edge_rank = {name: index for index, name in enumerate(value["edge_types"])}
    node_rank = {"claim": 0, "alias": 1, "assumption_set": 2}
    return {
        key: item
        for key, item in sorted(value.items())
        if key not in {"generated", "nodes", "edges"}
    } | {
        "nodes": sorted(value["nodes"], key=lambda node: (node_rank[node["kind"]], node["id"])),
        "edges": sorted(
            value["edges"],
            key=lambda edge: (
                edge_rank[edge["type"]],
                edge["source"],
                edge["target"],
                edge.get("use_site", ""),
            ),
        ),
    }


def render() -> str:
    value = json.loads(SOURCE.read_text(encoding="utf-8"))
    return json.dumps(normalize(value), ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render()
    if args.check:
        if not EXPECTED.exists() or EXPECTED.read_text(encoding="utf-8") != rendered:
            print(f"stale normative vector: {EXPECTED.relative_to(ROOT)}")
            return 1
        return 0
    EXPECTED.parent.mkdir(parents=True, exist_ok=True)
    EXPECTED.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
