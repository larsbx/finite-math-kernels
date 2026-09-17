"""Every test names what it guards, and every guarded class is guarded.

The proof-driven-test discipline of `larsbx/crypto-composer`, where a test
may not exist without a proof statement, read onto a claim ledger: a test
declares the ledger claim it guards (or the contract it guards that is no
ledger claim), the declaration must resolve, and a claim whose warrant is an
executable computation must have at least one test that names it.

A declaration is static text.  When the policy names a receipts file and
that file exists, it is the run log of the suite: a declaration the run did
not reach does not count, so a claim guarded only by a test body that is
never called is reported rather than credited.

The three states are distinct.  No receipts configured, or the file absent,
means the declarations stand on their own.  A parsed log means a declaration
counts only if the run reached it.  A *malformed* log is neither: it says
nothing about what executed, so it credits nothing and every required class
is reported uncovered until the file parses.  Reading a broken run log as an
absent one would make a green suite out of a file nobody can read.
"""

from __future__ import annotations

from claim_governance.findings import Finding
from claim_governance.lexing import line_of
from claim_governance.policy import Coverage, Policy
from claim_governance.repo import Repo

CHECK = "coverage"
POLICY_FILE = "claim_governance.toml"
RECEIPTS_FORMAT = "# finite proof-test receipts 1"
CLAIM, CONTRACT = "claim", "contract"
KINDS = (CLAIM, CONTRACT)
Receipt = tuple[str, str, str]


def read_receipts(cfg: Coverage, repo: Repo) -> tuple[frozenset[Receipt] | None, Finding | None]:
    """The run log as ``(path, kind, value)`` triples, or ``None`` when no
    receipts are configured or the file is absent or malformed.  A malformed
    file is one finding, not silence, and never credits a declaration."""
    if not cfg.receipts or not repo.exists(cfg.receipts):
        return None, None
    lines = repo.text(cfg.receipts).split("\n")
    if not lines or lines[0].strip() != RECEIPTS_FORMAT:
        return None, Finding(cfg.receipts, 1, CHECK, "receipts", f"first line must be {RECEIPTS_FORMAT!r}")
    entries: set[Receipt] = set()
    for number, line in enumerate(lines[1:], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3 or fields[1] not in KINDS:
            return None, Finding(cfg.receipts, number, CHECK, "receipts", f"line is not <path> TAB <{'|'.join(KINDS)}> TAB <value>")
        entries.add((fields[0], fields[1], fields[2]))
    return frozenset(entries), None


def declarations(cfg: Coverage, repo: Repo, rel: str) -> tuple[tuple[str, str, int], ...]:
    """Every ``(kind, value, line)`` a test file declares, in file order."""
    text = repo.surface(rel)
    found = [(CLAIM, m.group(CLAIM), line_of(text, m.start())) for m in cfg.claims().finditer(text)]
    found += [(CONTRACT, m.group(CONTRACT), line_of(text, m.start())) for m in cfg.contracts().finditer(text)]
    return tuple(sorted(found, key=lambda d: d[2]))


def check(policy: Policy, repo: Repo) -> tuple[Finding, ...]:
    cfg = policy.coverage
    if not cfg.tests:
        return ()
    canonical = {name.casefold(): claim.name for claim in policy.ledger for name in claim.names}
    receipts, malformed = read_receipts(cfg, repo)
    findings = [malformed] if malformed is not None else []
    # A malformed run log is not a missing one. It says nothing about which
    # declarations executed, so it credits none of them: every required class
    # is reported uncovered until the file parses.
    credits = malformed is None
    guarded: dict[str, list[str]] = {}
    declared: set[Receipt] = set()
    for rel in repo.files(cfg.tests):
        found = declarations(cfg, repo, rel)
        if not found:
            findings.append(Finding(rel, 0, CHECK, "declaration", "test names no ledger claim and no contract"))
        for kind, value, line in found:
            declared.add((rel, kind, value))
            name = canonical.get(value.casefold())
            if kind == CLAIM and name is None:
                findings.append(Finding(rel, line, CHECK, value or "<empty>", "names a claim that is not in the ledger"))
                continue
            if kind == CONTRACT and not value.strip():
                findings.append(Finding(rel, line, CHECK, "declaration", "names an empty contract"))
                continue
            if receipts is not None and (rel, kind, value) not in receipts:
                findings.append(Finding(rel, line, CHECK, name or value, "declared, but the recorded run did not reach it"))
                continue
            if kind == CLAIM and credits:
                guarded.setdefault(name or value, []).append(rel)
    for stale in sorted((receipts or frozenset()) - declared):
        findings.append(Finding(cfg.receipts or "", 0, CHECK, stale[2], f"receipt for {stale[1]} is not declared by {stale[0]}"))
    for claim in policy.ledger:
        if claim.status in cfg.require_classes and claim.name not in guarded:
            findings.append(Finding(POLICY_FILE, 0, CHECK, claim.name, f"no test guards this {claim.status!r} claim"))
    return tuple(findings)
