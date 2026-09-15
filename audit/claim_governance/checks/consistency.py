"""Every status surface must agree with the claim ledger."""

from __future__ import annotations

from claim_governance.findings import Finding
from claim_governance.lexing import find_all, line_of, window_lines
from claim_governance.policy import Claim, Policy, Surface
from claim_governance.repo import Repo

CHECK = "consistency"


def _region(text: str, surface: Surface) -> tuple[int, str] | None:
    """(offset, text) of the surface's region, or None when its bounds are missing."""
    if surface.section is None:
        return 0, text
    start = text.find(surface.section)
    end = text.find(surface.section_end or "", start + len(surface.section)) if start >= 0 else -1
    return None if end < 0 else (start, text[start:end])


def _audit_surface(claim: Claim, surface: Surface, policy: Policy, repo: Repo) -> Finding | None:
    if not repo.exists(surface.path):
        return Finding(surface.path, 0, CHECK, claim.name, "status surface is missing")
    text = repo.surface(surface.path)
    located = _region(text, surface)
    if located is None:
        return Finding(surface.path, 0, CHECK, claim.name, f"region {surface.section!r} .. {surface.section_end!r} not found")
    offset, region = located
    anchors = (surface.anchor,) if surface.anchor else claim.names
    hits = [idx for anchor in anchors for idx in find_all(region, anchor, word=surface.anchor is None)]
    if surface.expect == "absent":
        return None if not hits else Finding(surface.path, line_of(text, offset + min(hits)), CHECK, claim.name, f"{claim.status!r} claim must be absent from region {surface.section!r}")
    if not hits:
        return Finding(surface.path, line_of(text, offset) if surface.section else 0, CHECK, claim.name, f"surface does not mention {claim.name!r} (anchors {list(anchors)})")
    if surface.expect == "present":
        return None
    line = line_of(text, offset + min(hits))
    found = policy.status.classes_in(window_lines(text, line, surface.window_lines))
    if not found:
        return Finding(surface.path, line, CHECK, claim.name, f"no status label within {surface.window_lines} lines of the anchor")
    if claim.status not in found:
        return Finding(surface.path, line, CHECK, claim.name, f"surface shows {sorted(found)} but the ledger records {claim.status!r}")
    return None


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    return tuple(
        finding
        for claim in policy.ledger
        for surface in claim.surfaces
        if (finding := _audit_surface(claim, surface, policy, repo)) is not None
    )
