from __future__ import annotations

import textwrap
from collections.abc import Mapping
from pathlib import Path

import pytest

from claim_governance.policy import Policy, policy_from_mapping
from claim_governance.repo import Repo
from claim_governance.runner import CHECKS


def write_tree(root: Path, files: Mapping[str, str]) -> Path:
    for rel, body in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(textwrap.dedent(body).lstrip("\n"), encoding="utf-8")
    return root


BASE_STATUS = {
    "classes": ["proved", "imported", "finite-domain", "conditional", "open", "retired"],
    "synonyms": {
        "Repository-proved": "proved",
        "[PROVED]": "proved",
        "Imported theorem": "imported",
        "[IMPORTED]": "imported",
        "Finite-domain theorem": "finite-domain",
        "Conditional theorem": "conditional",
        "Open conjectural gate": "open",
        "[OPEN]": "open",
        "OPEN": "open",
        "Retired claim": "retired",
    },
}


def make_policy(**overrides) -> Policy:
    data = {"repository": {"name": "example/repo"}, "status": BASE_STATUS}
    data.update(overrides)
    return policy_from_mapping(data)


@pytest.fixture
def tree(tmp_path: Path):
    return lambda files: write_tree(tmp_path, files)


def run_check(name: str, policy: Policy, root: Path):
    return CHECKS[name](policy, Repo(root, policy.scan.exclude))
