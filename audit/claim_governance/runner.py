"""Check registry and the audit entry point."""

from __future__ import annotations

from collections.abc import Callable, Iterable
from pathlib import Path
from types import MappingProxyType

from claim_governance.checks import claims, consistency, numerics, promotion, terminology
from claim_governance.findings import Finding
from claim_governance.policy import Policy
from claim_governance.repo import Repo

Check = Callable[[Policy, Repo], tuple[Finding, ...]]

CHECKS: dict[str, Check] = MappingProxyType({  # type: ignore[assignment]
    terminology.CHECK: terminology.check,
    claims.CHECK: claims.check,
    promotion.CHECK: promotion.check,
    numerics.CHECK: numerics.check,
    consistency.CHECK: consistency.check,
})


def run(policy: Policy, root: Path, only: Iterable[str] = ()) -> tuple[Finding, ...]:
    """Run the selected checks (all by default) and return findings sorted by location."""
    names = tuple(only) or tuple(CHECKS)
    unknown = sorted(set(names) - set(CHECKS))
    if unknown:
        raise KeyError(f"unknown checks {unknown}; known: {list(CHECKS)}")
    repo = Repo(root, policy.scan.exclude)
    return tuple(sorted(f for name in names for f in CHECKS[name](policy, repo)))
