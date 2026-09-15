"""Undeclared, scoped, deprecated, and risky terminology."""

from __future__ import annotations

import re

from claim_governance.findings import Finding
from claim_governance.lexing import find_all, has_context, line_of
from claim_governance.policy import Policy, Terminology
from claim_governance.repo import Repo

CHECK = "terminology"


def _declaration_blocks(text: str, marker: str) -> list[tuple[int, str]]:
    """(line, block text) for each declaration; a block runs to the next marker or
    heading.  A marker inside a heading line is a title, not a declaration."""
    def in_heading(index: int) -> bool:
        return text[text.rfind("\n", 0, index) + 1: index].lstrip().startswith("#")

    starts = [m.start() for m in re.finditer(re.escape(marker), text) if not in_heading(m.start())]
    blocks: list[tuple[int, str]] = []
    for i, start in enumerate(starts):
        rest = text[start + len(marker):]
        stop = min(
            (m.start() for m in re.finditer(rf"^(?:#{{1,6}} |{re.escape(marker)})", rest, flags=re.MULTILINE)),
            default=len(rest),
        )
        blocks.append((line_of(text, start), text[start: start + len(marker) + stop]))
    return blocks


def _is_governed(text: str, policy: Terminology) -> bool:
    blocks = _declaration_blocks(text, policy.declaration_marker)
    return bool(blocks) and all(all(f in block for f in policy.declaration_fields) for _, block in blocks)


def _declared_terms(registry: str, marker: str) -> set[str]:
    declared = {m.group(1).strip().strip("`").lower() for m in re.finditer(rf"{re.escape(marker)}\s*`?([^`\n]+?)`?(?:\s+is\b|\s+means\b|:|\.|\n)", registry)}
    headings = {m.group(1).strip().strip("`").lower() for m in re.finditer(r"^#{2,6}\s+(.+?)\s*$", registry, flags=re.MULTILINE)}
    return declared | headings


def _audit_registry(policy: Terminology, repo: Repo) -> list[Finding]:
    if policy.registry is None:
        return []
    if not repo.exists(policy.registry):
        return [Finding(policy.registry, 0, CHECK, "registry", "terminology registry is missing")]
    text = repo.text(policy.registry)
    findings = [
        Finding(policy.registry, 0, CHECK, "registry", f"missing section {section!r}")
        for section in policy.registry_sections if section not in text
    ]
    declared = _declared_terms(text, policy.declaration_marker)
    findings += [
        Finding(policy.registry, 0, CHECK, term, "project term is not declared in the registry")
        for term in policy.project_terms if term.lower() not in declared
    ]
    return findings


def _audit_declarations(rel: str, text: str, policy: Terminology) -> list[Finding]:
    return [
        Finding(rel, line, CHECK, "declaration", f"terminology declaration missing fields: {', '.join(missing)}")
        for line, block in _declaration_blocks(text, policy.declaration_marker)
        if (missing := [f for f in policy.declaration_fields if f not in block])
    ]


def _audit_risky(rel: str, text: str, policy: Terminology, governed: bool) -> list[Finding]:
    if governed:
        return []
    return [
        Finding(rel, line_of(text, idx), CHECK, phrase, "risky bridge phrase requires a terminology declaration with genealogy and known leaks")
        for phrase in policy.risky_phrases
        for idx in find_all(text, phrase)
        if not has_context(text, idx, policy.negating_context)
    ]


def _audit_deprecated(rel: str, text: str, policy: Terminology) -> list[Finding]:
    return [
        Finding(rel, line_of(text, idx), CHECK, item.term, f"deprecated term requires migration context; use {item.replacement}")
        for item in policy.deprecated if rel not in item.allow
        for idx in find_all(text, item.term)
        if not has_context(text, idx, policy.migration_context)
    ]


def _audit_scoped(rel: str, text: str, policy: Terminology, governed: bool) -> list[Finding]:
    pointer = policy.registry is not None and policy.registry in text
    if governed or pointer:
        return []
    findings = []
    for item in policy.scoped:
        if rel.startswith(item.home):
            continue
        idx = next(find_all(text, item.term), None)
        if idx is not None and not has_context(text, idx, policy.negating_context):
            findings.append(Finding(rel, line_of(text, idx), CHECK, item.term, "scoped term requires a local declaration or a registry pointer outside its home files"))
    return findings


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    term = policy.terminology
    findings = _audit_registry(term, repo)
    for rel in repo.files(policy.scan.prose + policy.scan.source):
        if rel in term.allow:
            continue
        text = repo.masked(rel)
        governed = _is_governed(text, term)
        findings += _audit_declarations(rel, text, term)
        findings += _audit_risky(rel, text, term, governed)
        findings += _audit_deprecated(rel, text, term)
        findings += _audit_scoped(rel, text, term, governed)
    return tuple(sorted(set(findings)))
