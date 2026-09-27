"""Forbidden numerical or analytic primitives in executable source."""

from __future__ import annotations

from claim_governance.findings import Finding
from claim_governance.lexing import has_context, line_of
from claim_governance.policy import NumericsRule, Policy
from claim_governance.repo import Repo

CHECK = "numerics"


def _audit_rule(rule: NumericsRule, repo: Repo) -> list[Finding]:
    regex = rule.regex()
    findings = []
    for rel in repo.files(rule.paths):
        if rel in rule.allow_files:
            continue
        text = repo.masked(rel)
        seen: set[int] = set()
        for match in regex.finditer(text):
            line = line_of(text, match.start())
            source = text.split("\n")[line - 1]
            if line in seen or source.strip() in rule.allow_lines:
                continue
            if rule.negating_context and has_context(text, match.start(), rule.negating_context, rule.radius):
                continue
            seen.add(line)
            findings.append(Finding(rel, line, CHECK, rule.name, f"{rule.message or 'forbidden primitive'}: {source.strip()}"))
    return findings


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    return tuple(f for rule in policy.numerics for f in _audit_rule(rule, repo))
