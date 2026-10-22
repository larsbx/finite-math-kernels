"""Build or check the domain-owned proof-graph normalization vector."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "conformance/ledger/relationship-graph.json"
EXPECTED = ROOT / "conformance/oracle/typed-proof-graph-normalization-v1.json"


def _edge_identity(edge: dict) -> tuple[str, str, str, str, str]:
    return (
        edge["type"],
        edge["source"],
        edge["target"],
        edge["provenance"],
        edge.get("use_site", ""),
    )


def _normalize_edges(edges: list[dict], edge_rank: dict[str, int]) -> list[dict]:
    by_identity: dict[tuple[str, str, str, str, str], dict] = {}
    for edge in edges:
        identity = _edge_identity(edge)
        previous = by_identity.get(identity)
        if previous is not None and previous != edge:
            raise ValueError(f"conflicting edges share canonical identity: {identity!r}")
        by_identity[identity] = edge
    return sorted(
        by_identity.values(),
        key=lambda edge: (
            edge_rank[edge["type"]],
            edge["source"],
            edge["target"],
            edge["provenance"],
            edge.get("use_site", ""),
        ),
    )


def normalize(value: dict) -> dict:
    edge_rank = {name: index for index, name in enumerate(value["edge_types"])}
    node_rank = {"claim": 0, "alias": 1, "assumption_set": 2}
    return {
        key: item
        for key, item in sorted(value.items())
        if key not in {"generated", "nodes", "edges"}
    } | {
        "nodes": sorted(value["nodes"], key=lambda node: (node_rank[node["kind"]], node["id"])),
        "edges": _normalize_edges(value["edges"], edge_rank),
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
