"""Apparent theorem statements must carry a status label."""

from __future__ import annotations

import re

from claim_governance.findings import Finding
from claim_governance.lexing import window_lines
from claim_governance.policy import Claims, Policy
from claim_governance.repo import Repo

CHECK = "claims"


def statement_pattern(kinds: tuple[str, ...]) -> re.Pattern[str]:
    """Lines that open a statement: a Markdown heading (``## Theorem 4.4``), a
    bold lead-in (``**Lemma 1.1 (x).**``), or a LaTeX ``\\begin{kind}``.  The kind
    may be followed by a number or tag and must then end or meet punctuation,
    so ``# Hypothesis firewall`` and in-sentence references do not match."""
    alternatives = "|".join(re.escape(k) for k in kinds) or r"(?!x)x"
    return re.compile(
        rf"^[ \t]*(?:#{{1,6}}[ \t]+|\*\*|\\begin\{{)[ \t]*(?P<kind>{alternatives})(?:[ \t]+(?-i:[\dA-Z])[\w.]*)?[ \t]*(?:[(:.*\]}}]|$)",
        flags=re.IGNORECASE | re.MULTILINE,
    )


def has_file_status(text: str, cfg: Claims) -> bool:
    if cfg.file_status_marker is None:
        return False
    head = text.split("\n")[: cfg.file_status_lines]
    return any(line.lstrip().startswith(cfg.file_status_marker) for line in head)


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    cfg = policy.claims
    pattern = statement_pattern(cfg.statement_kinds)
    labels = policy.status.pattern()
    findings = []
    for rel in repo.files(cfg.paths):
        if rel in cfg.allow:
            continue
        text = repo.masked(rel)
        if has_file_status(text, cfg):
            continue
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            if not labels.search(window_lines(text, line, cfg.window_lines)):
                findings.append(Finding(rel, line, CHECK, match.group("kind"), f"statement {match.group(0).strip()!r} has no status label within {cfg.window_lines} lines"))
    return tuple(findings)
