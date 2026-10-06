# audit.py
#
# The engine behind a consumer's terminology and prose audits. See the
# package docstring for the rule kinds and what belongs to the consumer.

from __future__ import annotations

import re
from bisect import bisect_right
from collections.abc import Iterator
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path

from claim_governance.lexing import find_all, has_context, line_of
from vendoring.check_vendored_sync import vendored_directories

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
#: A list item, table row or numbered item starts a new block of prose.
ITEM_RE = re.compile(r"\s*(?:[-*] |\||\d+\.\s)")
#: The comment marker or docstring quote opening a source line.
SOURCE_PREFIX_RE = re.compile(r'^\s*(#+\s?|"""|\'\'\')')


@dataclass(frozen=True)
class Scope:
    """The files a rule reads: repository-relative globs, minus exclusions.

    ``exclude`` patterns are ``fnmatch`` patterns over the POSIX path, where
    ``*`` also matches ``/``. With ``skip_vendored`` a file inside a package
    the consumer's ``vendored.toml`` vendors is skipped, read through the
    ``vendoring`` package.
    """

    include: tuple[str, ...]
    exclude: tuple[str, ...] = ()
    skip_vendored: bool = False

    def excluded(self, rel: str) -> bool:
        return any(fnmatch(rel, pattern) for pattern in self.exclude)

    def files(self, root: Path) -> tuple[str, ...]:
        vendored = tuple(f"{d}/" for d in vendored_directories(root)) if self.skip_vendored else ()
        found = {
            path.relative_to(root).as_posix()
            for pattern in self.include
            for path in root.glob(pattern)
            if path.is_file()
        }
        return tuple(sorted(
            rel for rel in found
            if not self.excluded(rel) and not (vendored and rel.startswith(vendored))
        ))


@dataclass(frozen=True)
class Requirement:
    """A document must match ``pattern`` at least ``minimum`` times."""

    pattern: str
    message: str
    minimum: int = 1

    def __post_init__(self) -> None:
        re.compile(self.pattern)

    def met(self, text: str) -> bool:
        return sum(1 for _ in re.finditer(self.pattern, text)) >= self.minimum


def contains(text: str, message: str) -> Requirement:
    """The document contains ``text`` verbatim."""
    return Requirement(re.escape(text), message)


def all_of(*patterns: str) -> str:
    """A pattern that matches once, at the start, when every pattern occurs somewhere."""
    return r"\A" + "".join(rf"(?=[\s\S]*?(?:{pattern}))" for pattern in patterns)


@dataclass(frozen=True)
class Document:
    """A governing document: it must exist and meet every requirement."""

    path: str
    missing: str
    require: tuple[Requirement, ...] = ()

    def audit(self, root: Path) -> list[str]:
        path = root / self.path
        if not path.is_file():
            return [self.missing]
        text = path.read_text(encoding="utf-8")
        return [req.message for req in self.require if not req.met(text)]


@dataclass(frozen=True)
class Declaration:
    """A declaration block: ``marker`` followed by text, and every field present."""

    marker: str
    fields: tuple[str, ...]

    def missing(self, text: str) -> tuple[str, ...]:
        return tuple(field for field in self.fields if field not in text)

    def complete(self, text: str) -> bool:
        return re.search(re.escape(self.marker) + r"\s*.", text) is not None and not self.missing(text)


@dataclass(frozen=True)
class Hit:
    """One occurrence a rule reports; ``render`` fills the rule's message."""

    path: str
    line: int
    match: str = ""
    term: str = ""
    text: str = ""
    missing: str = ""

    def render(self, message: str) -> str:
        return message.format(path=self.path, line=self.line, match=self.match, term=self.term,
                              text=self.text, missing=self.missing)


class _Rule:
    """What every rule shares: a scope, a message, and a per-text check."""

    scope: Scope
    message: str

    def hits(self, rel: str, text: str) -> list[Hit]:
        raise NotImplementedError

    def stale(self, root: Path, files: tuple[str, ...]) -> list[str]:
        """Exemptions that exempt nothing, reported so they cannot rot silently."""
        return []

    def audit(self, root: Path) -> list[str]:
        files = self.scope.files(root)
        found = self.stale(root, files)
        for rel in files:
            found += [hit.render(self.message) for hit in self.hits(rel, (root / rel).read_text(encoding="utf-8"))]
        return found


@dataclass(frozen=True)
class ClauseRule(_Rule):
    """A banned pattern in a clause of prose, unless the clause denies it.

    A file is read in blocks: a paragraph, a list item, a table row or a
    heading, each joined into one line of text. Markdown headings open
    sections; a source file (any other suffix) is read line by line with its
    leading comment marker or docstring quote removed. Each block is split
    into clauses at ``clause``. A ``banned`` match is reported unless

    1. a ``denial`` match ends within ``reach`` characters before it, in the
       same clause;
    2. it lies inside an ``allowed`` phrase (matched case-insensitively, a
       space also matching a hyphen), which is blanked before matching;
    3. it lies in a section whose heading title matches an ``exempt_sections``
       pattern (``re.search``), including that section's subsections; or
    4. it lies in the block directly after ``<!-- marker: reason -->``: the
       next paragraph, or only the first item of a list or row of a table
       (a blank line or a heading before any block disarms the marker).

    Every ``exempt_sections`` pattern must match a heading in scope, so that
    renaming a section cannot silently drop or widen its exemption.
    """

    scope: Scope
    banned: str
    message: str
    denial: str = r"(?!)"
    reach: int = 48
    clause: str = r"(?<=[.;:])\s+"
    exempt_sections: tuple[str, ...] = ()
    marker: str | None = None
    allowed: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        for pattern in (self.banned, self.denial, self.clause, *self.exempt_sections):
            re.compile(pattern)
        if self.reach < 0:
            raise ValueError("reach must be non-negative")

    def _marker(self) -> re.Pattern[str] | None:
        return None if self.marker is None else re.compile(rf"<!--\s*{re.escape(self.marker)}:\s*(?P<reason>[^>]+?)\s*-->")

    def _blocks(self, rel: str, text: str) -> Iterator[list[tuple[int, str, str]]]:
        """``[(line, prose, raw line)]`` per block that no section or marker exempts."""
        markdown = rel.endswith(".md")
        marker = self._marker()
        exempt_level: int | None = None
        marked = False
        block: list[tuple[int, str, str]] = []

        def flush() -> Iterator[list[tuple[int, str, str]]]:
            nonlocal block, marked
            if block:
                if exempt_level is None and not marked:
                    yield block
                marked = False  # the marker covers this one block only
            block = []

        for number, raw in enumerate(text.splitlines(), start=1):
            line = raw if markdown else SOURCE_PREFIX_RE.sub("", raw).replace('"""', "")
            heading = HEADING_RE.match(line) if markdown else None
            if heading:
                yield from flush()
                level = len(heading.group(1))
                if exempt_level is not None and level <= exempt_level:
                    exempt_level = None
                if exempt_level is None and any(re.search(p, heading.group(2)) for p in self.exempt_sections):
                    exempt_level = level
                marked = False
                block = [(number, line, raw)]
                yield from flush()
                continue
            if marker is not None and marker.search(line):
                yield from flush()
                marked = True
                continue
            if not line.strip():
                yield from flush()
                marked = False
                continue
            if not markdown or ITEM_RE.match(line):
                yield from flush()
            block.append((number, line, raw))
        yield from flush()

    def _mask(self, text: str) -> str:
        for phrase in self.allowed:
            pattern = re.escape(phrase).replace(r"\ ", r"[\s-]")
            text = re.sub(pattern, lambda found: " " * len(found.group(0)), text, flags=re.IGNORECASE)
        return text

    def hits(self, rel: str, text: str) -> list[Hit]:
        found: list[Hit] = []
        for block in self._blocks(rel, text):
            starts, pieces, offset = [], [], 0
            for _, prose, _ in block:
                starts.append(offset)
                pieces.append(prose.strip())
                offset += len(pieces[-1]) + 1
            joined = self._mask(" ".join(pieces))
            cuts = [0, *(m for sep in re.finditer(self.clause, joined) for m in (sep.start(), sep.end())), len(joined)]
            for begin, end in zip(cuts[::2], cuts[1::2]):
                clause = joined[begin:end]
                denials = [d.end() for d in re.finditer(self.denial, clause)]
                for match in re.finditer(self.banned, clause):
                    if any(0 <= match.start() - stop <= self.reach for stop in denials):
                        continue
                    number, _, raw = block[bisect_right(starts, begin + match.start()) - 1]
                    found.append(Hit(rel, number, match=match.group(0), text=raw.strip()))
        return found

    def stale(self, root: Path, files: tuple[str, ...]) -> list[str]:
        titles = [
            heading.group(2)
            for rel in files if rel.endswith(".md")
            for line in (root / rel).read_text(encoding="utf-8").splitlines()
            if (heading := HEADING_RE.match(line))
        ]
        return [
            f"exempt section pattern {pattern!r} matches no heading in scope"
            for pattern in self.exempt_sections
            if not any(re.search(pattern, title) for title in titles)
        ]


@dataclass(frozen=True)
class ContextRule(_Rule):
    """Each occurrence of a term needs a context marker nearby.

    Terms and markers are matched case-insensitively, on the raw text
    (comments and prose included). An occurrence is reported unless a
    ``context`` marker occurs within ``radius`` characters of its start
    (``claim_governance.lexing.has_context``); with no markers every
    occurrence is reported. A file is exempt as a whole when it carries a
    complete ``exempt_declared`` declaration or any ``exempt_if_contains``
    text (a pointer to the registry, say).
    """

    scope: Scope
    terms: tuple[str, ...]
    message: str
    context: tuple[str, ...] = ()
    radius: int = 140
    exempt_declared: Declaration | None = None
    exempt_if_contains: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if self.radius < 0:
            raise ValueError("radius must be non-negative")

    def hits(self, rel: str, text: str) -> list[Hit]:
        if self.exempt_declared is not None and self.exempt_declared.complete(text):
            return []
        if any(pointer in text for pointer in self.exempt_if_contains):
            return []
        return [
            Hit(rel, line_of(text, index), term=term)
            for term in self.terms
            for index in find_all(text, term)
            if not (self.context and has_context(text, index, self.context, self.radius))
        ]


@dataclass(frozen=True)
class DeclarationRule(_Rule):
    """A file that opens a declaration must complete it."""

    scope: Scope
    declaration: Declaration
    message: str

    def hits(self, rel: str, text: str) -> list[Hit]:
        if self.declaration.marker not in text:
            return []
        missing = self.declaration.missing(text)
        return [Hit(rel, line_of(text, text.index(self.declaration.marker)), missing=", ".join(missing))] if missing else []


Rule = ClauseRule | ContextRule | DeclarationRule


@dataclass(frozen=True)
class Policy:
    """What one consumer decides about one audit.

    ``documents`` are checked first; when one fails and ``stop_on_documents``
    holds, the rules are not run, since they read those documents' contents.
    """

    title: str
    documents: tuple[Document, ...] = ()
    rules: tuple[Rule, ...] = ()
    stop_on_documents: bool = True


def scanned_files(root: Path, policy: Policy) -> tuple[str, ...]:
    """Every file some rule of the policy reads."""
    return tuple(sorted({rel for rule in policy.rules for rel in rule.scope.files(root)}))


def audit(root: Path, policy: Policy) -> list[str]:
    """Every finding, in a stable order, each named once; empty means clean."""
    errors = [error for document in policy.documents for error in document.audit(root)]
    if errors and policy.stop_on_documents:
        return list(dict.fromkeys(errors))
    errors += [error for rule in policy.rules for error in rule.audit(root)]
    return list(dict.fromkeys(errors))


def run(root: Path, policy: Policy) -> int:
    """Audit ``root`` under ``policy``; print the report and return an exit code."""
    errors = audit(root, policy)
    if errors:
        print(f"{policy.title} failed:")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(f"OK: {policy.title} passed: {len(scanned_files(root, policy))} files.")
    return 0
