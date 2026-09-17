#!/usr/bin/env python3
"""Check that local path and pixi task references in the tree resolve.

Scans every tracked Markdown, Mojo, Python, TOML, and YAML file for
backticked path tokens (``dir/file.ext`` or a bare ``file.ext``) and for
``pixi run <task>`` phrases. A path token must name a tracked file (a bare
filename resolves when exactly one tracked file has that basename) or appear
in EXTERNAL, which attests which other repository it lives in. A task must
be defined in ``pixi.toml`` or be an executable pixi runs directly. Task
phrases inside a double-quoted string literal on a code line are data, not
references, and are not checked. Dated audit records quote past states
verbatim, and this checker's own tests contain synthetic references by
construction; both are skipped.

Usage: check_references.py            exit 1 on any unresolved reference
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from collections.abc import Iterable, Mapping
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from provenance import tracked_files  # noqa: E402

CHECKED_SUFFIXES = (".md", ".mojo", ".py", ".toml", ".yml")
SKIPPED_PREFIXES = ("audit/POST_CONSOLIDATION_AUDIT_", "tests/references/")
EXECUTABLES = frozenset({"mojo", "python"})
PATH_TOKEN = re.compile(r"`([A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:md|mojo|py|toml|json|yml|lock))`")
TASK_TOKEN = re.compile(r"pixi run ([A-Za-z0-9_-]+)")
QUOTED = re.compile(r'"[^"]*"')
TASK_DEFINITION = re.compile(r"^([A-Za-z0-9_-]+) = ", re.M)

# The finite-regime Mandelbrot program moved from larsbx/NLAP-JT to this
# repository on 2026-09-16; NLAP-JT is historical and receives no new work,
# so every row below names the live home of the file it attests.
NLAP = "larsbx/finite-mandlebrot-research (formerly larsbx/NLAP-JT)"
PSC = "larsbx/pisot-substitution-conjecture-research"
EXTERNAL: Mapping[str, str] = {
    "docs/canonical-serialization.md": NLAP,
    "docs/library-extraction-candidates-2026-09-14.md": NLAP,
    "docs/finite-proof-records-spec.md": NLAP,
    "src/mojo_theorem_kernel.mojo": NLAP,
    "src/C1_theorem_tag_import_ledger.mojo": NLAP,
    "src/C1_theorem_tag_assumption_payloads.mojo": NLAP,
    "src/C1_final_proof_block_ledger.mojo": NLAP,
    "tools/audit_exact_arithmetic.py": NLAP,
    "docs/C1_theorem_tag_import_ledger.md": NLAP,
    "src/checked_ray_address.mojo": NLAP,
    "docs/C1_residual_directive_carrier.md": NLAP,
    "docs/cross-pollination-round-two-2026-09-16.md": f"{NLAP} and {PSC}",
    "docs/release-provenance.md": "larsbx/sprucegoose at the commit named in docs/evidence-vocabulary-map.md",
    "tdd_ledger.zig": "larsbx/crypto-composer at the commit named in docs/evidence-vocabulary-map.md",
    "test/harness.zig": "larsbx/crypto-composer at the commit named in docs/evidence-vocabulary-map.md",
    "docs/exact-arithmetic-binding.md": PSC,
    "docs/overlap-finiteness-and-coincidence-density-2026-09-13.md": PSC,
    "src/psc_research/bpa.py": PSC,
    "mojo/psc/finite_cokernel_address.mojo": PSC,
    "docs/padic-representation-literature-gate-2026-09-16.md": PSC,
    "tests/test_substitution_dynamics_oracle.py": PSC,
    "claim_governance.toml": "the consumer repository root (audit/docs/policy-format.md)",
    "docs/ledger-index.md": "the consumer repository (docs/ledger-generation-spec.md, section 3.4)",
    "interval_q/closed_q.mojo": "larsbx/interval_q at the commit pinned in audit/provenance.json",
}


def path_tokens(text: str) -> list[str]:
    return PATH_TOKEN.findall(text)


def task_tokens(text: str) -> list[str]:
    """Task names outside double-quoted literals."""
    return [m.group(1) for line in text.splitlines() for m in TASK_TOKEN.finditer(QUOTED.sub("", line))]


def check(files: Mapping[str, str], tracked: Iterable[str], tasks: Iterable[str], external: Mapping[str, str] = EXTERNAL) -> list[str]:
    """Every unresolved reference as ``path: kind token``."""
    tracked = set(tracked)
    basenames = Counter(Path(p).name for p in tracked)
    known_tasks = set(tasks) | EXECUTABLES
    errors = []
    for path, text in sorted(files.items()):
        if path.startswith(SKIPPED_PREFIXES) or not path.endswith(CHECKED_SUFFIXES):
            continue
        for token in path_tokens(text):
            resolves = token in tracked or token in external or ("/" not in token and basenames[token] == 1)
            if not resolves:
                errors.append(f"{path}: path `{token}` is not a tracked file, a unique basename, or a listed external reference")
        for task in task_tokens(text):
            if task not in known_tasks:
                errors.append(f"{path}: task `pixi run {task}` is not defined in pixi.toml")
    return errors


def tree_files(root: Path = ROOT) -> dict[str, str]:
    return {p: (root / p).read_text(encoding="utf-8", errors="replace") for p in tracked_files(root) if p.endswith(CHECKED_SUFFIXES)}


def defined_tasks(root: Path = ROOT) -> set[str]:
    return set(TASK_DEFINITION.findall((root / "pixi.toml").read_text(encoding="utf-8")))


def main(argv: list[str]) -> int:
    files = tree_files()
    errors = check(files, tracked_files(), defined_tasks())
    if errors:
        print("unresolved references:\n  " + "\n  ".join(errors))
        return 1
    print(f"OK: every path and task reference in {len(files)} files resolves.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
