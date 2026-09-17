"""Repository policy: immutable records loaded from ``claim_governance.toml``.

The schema is documented in ``audit/docs/policy-format.md``.  Loading validates
shape and cross-references (every claim status and status synonym must name a
declared status class) and raises :class:`PolicyError` otherwise, so a
misconfigured policy fails closed instead of auditing nothing.
"""

from __future__ import annotations

import re
import tomllib
from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path
from types import MappingProxyType
from typing import Any


class PolicyError(ValueError):
    """The policy file is malformed or internally inconsistent."""


@dataclass(frozen=True)
class Scan:
    prose: tuple[str, ...] = ()
    source: tuple[str, ...] = ()
    exclude: tuple[str, ...] = ()


@dataclass(frozen=True)
class StatusVocabulary:
    """Status classes and the labels each surface uses to spell them.

    ``synonyms`` maps a literal label (case-insensitive, matched on word
    boundaries) to a class in ``classes``.
    """

    classes: tuple[str, ...] = ()
    synonyms: Mapping[str, str] = field(default_factory=lambda: MappingProxyType({}))
    ignore_case: bool = False

    def pattern(self) -> re.Pattern[str]:
        labels = sorted(self.synonyms, key=len, reverse=True)
        alternatives = "|".join(_boundary(re.escape(label)) for label in labels) or r"(?!x)x"
        return re.compile(alternatives, flags=re.IGNORECASE if self.ignore_case else 0)

    def classes_in(self, text: str) -> frozenset[str]:
        fold = str.lower if self.ignore_case else str
        lookup = {fold(label): cls for label, cls in self.synonyms.items()}
        return frozenset(lookup[fold(m.group(0))] for m in self.pattern().finditer(text))


def _boundary(escaped: str) -> str:
    return rf"(?<![\w-]){escaped}(?![\w-])"


@dataclass(frozen=True)
class ScopedTerm:
    term: str
    home: tuple[str, ...]


@dataclass(frozen=True)
class DeprecatedTerm:
    term: str
    replacement: str
    allow: tuple[str, ...] = ()


@dataclass(frozen=True)
class Terminology:
    registry: str | None = None
    registry_sections: tuple[str, ...] = ()
    declaration_marker: str = "Terminology declaration:"
    declaration_fields: tuple[str, ...] = ()
    project_terms: tuple[str, ...] = ()
    scoped: tuple[ScopedTerm, ...] = ()
    deprecated: tuple[DeprecatedTerm, ...] = ()
    risky_phrases: tuple[str, ...] = ()
    negating_context: tuple[str, ...] = ()
    migration_context: tuple[str, ...] = ()
    allow: tuple[str, ...] = ()


@dataclass(frozen=True)
class Claims:
    """``file_status_marker``: a line opening with it, within the first
    ``file_status_lines`` lines, declares a file-level status; statements in
    such a file need no individual label."""

    paths: tuple[str, ...] = ()
    statement_kinds: tuple[str, ...] = ()
    window_lines: int = 6
    file_status_marker: str | None = None
    file_status_lines: int = 10
    allow: tuple[str, ...] = ()


@dataclass(frozen=True)
class Coverage:
    """Which executable tests must name the claim they guard.

    ``tests`` are globs of test files.  Each test declares what it stands
    for: ``claim_pattern`` matches a ledger claim it guards,
    ``contract_pattern`` a stated contract that is no ledger claim (a
    vendored kernel's arithmetic, say).  ``require_classes`` names the
    status classes whose claims must be guarded by at least one test.
    ``receipts``, when that file exists, is the run log of a test suite:
    a declaration counts only if the run reached it, so a claim guarded by
    a test that never ran is not covered.
    """

    tests: tuple[str, ...] = ()
    claim_pattern: str = r'require_claim\("(?P<claim>[^"]*)"\)'
    contract_pattern: str = r'require_contract\("(?P<contract>[^"]*)"\)'
    require_classes: tuple[str, ...] = ()
    receipts: str | None = None

    def claims(self) -> re.Pattern[str]:
        return re.compile(self.claim_pattern)

    def contracts(self) -> re.Pattern[str]:
        return re.compile(self.contract_pattern)


EXPECTATIONS = ("labelled", "present", "absent")


@dataclass(frozen=True)
class Surface:
    """Where a claim's status is spelled out.

    ``expect`` is ``"labelled"`` (the ledger class must appear near the
    anchor), ``"present"`` or ``"absent"`` (the anchor must or must not occur
    in the region).  ``section`` and ``section_end`` are literals bounding the
    region searched; without them the whole file is the region.
    """

    path: str
    anchor: str | None = None
    window_lines: int = 3
    expect: str = "labelled"
    section: str | None = None
    section_end: str | None = None


@dataclass(frozen=True)
class Claim:
    name: str
    status: str
    aliases: tuple[str, ...] = ()
    surfaces: tuple[Surface, ...] = ()

    @property
    def names(self) -> tuple[str, ...]:
        return (self.name, *self.aliases)


@dataclass(frozen=True)
class Promotion:
    proving_phrases: tuple[str, ...] = ()
    negating_context: tuple[str, ...] = ()
    settled_classes: tuple[str, ...] = ()
    radius: int = 120
    allow: tuple[str, ...] = ()


@dataclass(frozen=True)
class NumericsRule:
    """``negating_context``: markers within ``radius`` characters of a match
    that exempt it, for prose files that name a banned primitive in order to
    forbid it."""

    name: str
    pattern: str
    paths: tuple[str, ...]
    message: str = ""
    allow_files: tuple[str, ...] = ()
    allow_lines: tuple[str, ...] = ()
    negating_context: tuple[str, ...] = ()
    radius: int = 140

    def regex(self) -> re.Pattern[str]:
        return re.compile(self.pattern)


@dataclass(frozen=True)
class Policy:
    repository: str
    scan: Scan = Scan()
    status: StatusVocabulary = StatusVocabulary()
    terminology: Terminology = Terminology()
    claims: Claims = Claims()
    coverage: Coverage = Coverage()
    ledger: tuple[Claim, ...] = ()
    promotion: Promotion = Promotion()
    numerics: tuple[NumericsRule, ...] = ()


def _strs(table: Mapping[str, Any], key: str, default: tuple[str, ...] = ()) -> tuple[str, ...]:
    value = table.get(key, list(default))
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        raise PolicyError(f"{key!r} must be a list of strings")
    return tuple(value)


def _str(table: Mapping[str, Any], key: str, default: str | None = None) -> str | None:
    value = table.get(key, default)
    if value is not None and not isinstance(value, str):
        raise PolicyError(f"{key!r} must be a string")
    return value


def _int(table: Mapping[str, Any], key: str, default: int) -> int:
    value = table.get(key, default)
    if not isinstance(value, int) or value < 0:
        raise PolicyError(f"{key!r} must be a non-negative integer")
    return value


def _require(table: Mapping[str, Any], key: str, where: str) -> str:
    value = _str(table, key)
    if not value:
        raise PolicyError(f"{where} requires {key!r}")
    return value


def _status(table: Mapping[str, Any]) -> StatusVocabulary:
    classes = _strs(table, "classes")
    synonyms = table.get("synonyms", {})
    if not isinstance(synonyms, dict):
        raise PolicyError("status.synonyms must be a table")
    bad = sorted(cls for cls in synonyms.values() if cls not in classes)
    if bad:
        raise PolicyError(f"status.synonyms name undeclared classes {bad}")
    ignore_case = table.get("ignore_case", False)
    if not isinstance(ignore_case, bool):
        raise PolicyError("status.ignore_case must be a boolean")
    return StatusVocabulary(classes, MappingProxyType(dict(synonyms)), ignore_case)


def _terminology(table: Mapping[str, Any]) -> Terminology:
    return Terminology(
        registry=_str(table, "registry"),
        registry_sections=_strs(table, "registry_sections"),
        declaration_marker=_str(table, "declaration_marker", "Terminology declaration:") or "",
        declaration_fields=_strs(table, "declaration_fields"),
        project_terms=_strs(table, "project_terms"),
        scoped=tuple(ScopedTerm(_require(s, "term", "scoped term"), _strs(s, "home")) for s in table.get("scoped", [])),
        deprecated=tuple(
            DeprecatedTerm(_require(d, "term", "deprecated term"), _str(d, "replacement", "") or "", _strs(d, "allow"))
            for d in table.get("deprecated", [])
        ),
        risky_phrases=_strs(table, "risky_phrases"),
        negating_context=_strs(table, "negating_context"),
        migration_context=_strs(table, "migration_context"),
        allow=_strs(table, "allow"),
    )


def _claim(table: Mapping[str, Any], classes: tuple[str, ...]) -> Claim:
    name = _require(table, "name", "claim")
    status = _require(table, "status", f"claim {name!r}")
    if status not in classes:
        raise PolicyError(f"claim {name!r} has undeclared status class {status!r}")
    return Claim(name, status, _strs(table, "aliases"), tuple(_surface(s, name) for s in table.get("surfaces", [])))


def _surface(table: Mapping[str, Any], claim: str) -> Surface:
    where = f"surface of {claim!r}"
    expect = _str(table, "expect", "labelled") or "labelled"
    if expect not in EXPECTATIONS:
        raise PolicyError(f"{where}: expect must be one of {list(EXPECTATIONS)}")
    section, section_end = _str(table, "section"), _str(table, "section_end")
    if (section is None) != (section_end is None):
        raise PolicyError(f"{where}: section and section_end must be given together")
    return Surface(_require(table, "path", where), _str(table, "anchor"), _int(table, "window_lines", 3), expect, section, section_end)


def _coverage(table: Mapping[str, Any], classes: tuple[str, ...]) -> Coverage:
    """The declaration patterns must compile and expose the named group the
    check reads; every required class must be a declared status class."""
    defaults = Coverage()
    patterns = {"claim_pattern": defaults.claim_pattern, "contract_pattern": defaults.contract_pattern}
    for key, group in (("claim_pattern", "claim"), ("contract_pattern", "contract")):
        pattern = _str(table, key, patterns[key]) or ""
        try:
            compiled = re.compile(pattern)
        except re.error as exc:
            raise PolicyError(f"coverage.{key}: invalid pattern ({exc})") from exc
        if group not in compiled.groupindex:
            raise PolicyError(f"coverage.{key} must capture a group named {group!r}")
        patterns[key] = pattern
    required = _strs(table, "require_classes")
    bad = sorted(set(required) - set(classes))
    if bad:
        raise PolicyError(f"coverage.require_classes names undeclared classes {bad}")
    return Coverage(_strs(table, "tests"), patterns["claim_pattern"], patterns["contract_pattern"], required, _str(table, "receipts"))


def _promotion(table: Mapping[str, Any], classes: tuple[str, ...]) -> Promotion:
    settled = _strs(table, "settled_classes")
    bad = sorted(set(settled) - set(classes))
    if bad:
        raise PolicyError(f"promotion.settled_classes names undeclared classes {bad}")
    return Promotion(
        proving_phrases=_strs(table, "proving_phrases"),
        negating_context=_strs(table, "negating_context"),
        settled_classes=settled,
        radius=_int(table, "radius", 120),
        allow=_strs(table, "allow"),
    )


def _numerics(table: Mapping[str, Any]) -> NumericsRule:
    name = _require(table, "name", "numerics rule")
    pattern = _require(table, "pattern", f"numerics rule {name!r}")
    try:
        re.compile(pattern)
    except re.error as exc:
        raise PolicyError(f"numerics rule {name!r}: invalid pattern ({exc})") from exc
    return NumericsRule(
        name, pattern, _strs(table, "paths"), _str(table, "message", "") or "",
        _strs(table, "allow_files"), _strs(table, "allow_lines"),
        _strs(table, "negating_context"), _int(table, "radius", 140),
    )


def _numerics_rules(table: Any) -> tuple[NumericsRule, ...]:
    if not isinstance(table, Mapping):
        raise PolicyError("[numerics] must be a table")
    rules = table.get("rule", [])
    if not isinstance(rules, list) or any(not isinstance(rule, Mapping) for rule in rules):
        raise PolicyError("numerics.rule must be a list of tables")
    return tuple(_numerics(rule) for rule in rules)


def policy_from_mapping(data: Mapping[str, Any]) -> Policy:
    repository = _require(data.get("repository", {}), "name", "[repository]")
    scan = data.get("scan", {})
    status = _status(data.get("status", {}))
    claims = data.get("claims", {})
    ledger = tuple(_claim(c, status.classes) for c in data.get("claim", []))
    duplicates = sorted({c.name for c in ledger if sum(d.name == c.name for d in ledger) > 1})
    if duplicates:
        raise PolicyError(f"duplicate claim names {duplicates}")
    return Policy(
        repository=repository,
        scan=Scan(_strs(scan, "prose"), _strs(scan, "source"), _strs(scan, "exclude")),
        status=status,
        terminology=_terminology(data.get("terminology", {})),
        claims=Claims(
            _strs(claims, "paths"), _strs(claims, "statement_kinds"), _int(claims, "window_lines", 6),
            _str(claims, "file_status_marker"), _int(claims, "file_status_lines", 10), _strs(claims, "allow"),
        ),
        coverage=_coverage(data.get("coverage", {}), status.classes),
        ledger=ledger,
        promotion=_promotion(data.get("promotion", {}), status.classes),
        numerics=_numerics_rules(data.get("numerics", {})),
    )


def load_policy(path: Path) -> Policy:
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise PolicyError(f"{path}: {exc}") from exc
    return policy_from_mapping(data)
