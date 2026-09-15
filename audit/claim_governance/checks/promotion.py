"""Unsettled ledger claims must not be described as proved in prose."""

from __future__ import annotations

from claim_governance.findings import Finding
from claim_governance.lexing import find_all, has_context, line_of
from claim_governance.policy import Policy
from claim_governance.repo import Repo

CHECK = "promotion"


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    cfg = policy.promotion
    unsettled = [c for c in policy.ledger if c.status not in cfg.settled_classes]
    findings = set()
    for rel in repo.files(policy.scan.prose):
        if rel in cfg.allow:
            continue
        text = repo.masked(rel)
        for claim in unsettled:
            for alias in claim.names:
                for idx in find_all(text, alias, word=True):
                    promoted = has_context(text, idx, cfg.proving_phrases, cfg.radius)
                    negated = has_context(text, idx, cfg.negating_context, cfg.radius)
                    if promoted and not negated:
                        findings.add(Finding(rel, line_of(text, idx), CHECK, claim.name, f"{alias!r} is described as proved but the ledger records it as {claim.status!r}"))
    return tuple(sorted(findings))
