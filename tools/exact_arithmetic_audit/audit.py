# audit.py
#
# The engine behind a consumer's exact-arithmetic audit. See the package
# docstring for what is checked and what belongs to the consumer's Policy.

from __future__ import annotations

import ast
import io
import re
import tokenize
from dataclasses import dataclass
from pathlib import Path

from claim_governance.lexing import mask_comments_and_strings
from vendoring.check_vendored_sync import vendored_directories

#: The classes of the specification's binding tables (section 6).
CLASSES = ("CONFORMS-CHECKED", "CONFORMS", "DEMO", "QUARANTINED")

PATH_RE = re.compile(r"`([A-Za-z0-9_./-]+\.(?:mojo|py))`")
ROW_RE = re.compile(r"^\s*\|(?P<cells>.+)\|\s*$")
#: The three ways a module reaches a layer, each possibly indented: ``from
#: finite_exact.M import ...``, ``import finite_exact.M [as alias]`` and ``from
#: finite_exact import M[, N]`` (parenthesised over several lines included).
FROM_MODULE_RE = re.compile(r"(?:^|;)\s*from\s+finite_exact\.(\w+)(?:\.\w+)*\s+import\b", re.M)
IMPORT_MODULE_RE = re.compile(r"(?:^|;)\s*import\s+([^\n;]+)", re.M)
FROM_PACKAGE_RE = re.compile(r"(?:^|;)\s*from\s+finite_exact\s+import\s+(\([^)]*\)|[^\n;]+)", re.M)

#: Criterion C1, lexically: a floating-point type name, a SIMD float dtype, or
#: a decimal floating literal in any Mojo or Python spelling (``1.5``, ``2.``,
#: ``.5``, ``1e-3``, ``1_000.5``). The union of the two consumer patterns.
FLOAT_RE = re.compile(
    r"\b(?:Float16|Float32|Float64|BFloat16|FloatLiteral|Float|float)\b"
    r"|\bDType\.b?float"
    r"|(?<![\w.])(?:"
    r"(?:\d(?:_?\d)*\.(?:\d(?:_?\d)*)?|\.\d(?:_?\d)*)"
    r"(?:[eE][+-]?\d(?:_?\d)*)?"
    r"|\d(?:_?\d)*[eE][+-]?\d(?:_?\d)*"
    r")(?![\w.])"
)

# Python's builtin complex stores floating-point components. Mojo's exact
# complex carriers are unaffected by this Python-only token rule.
_PYTHON_FLOAT_RE = re.compile(FLOAT_RE.pattern + r"|\bcomplex\b")


@dataclass(frozen=True)
class Policy:
    """What one consumer decides about its own exact-arithmetic audit.

    Every path is repository-relative and POSIX-spelled. The fields where the
    two consumer copies disagreed are the ones a consumer sets; the rest have
    the value both copies shared.
    """

    #: How the specification names this repository as a consumer. The spec
    #: must contain it; a spec that does not name the consumer binds nothing.
    repository: str
    #: The specification every bound module must cite by path (C7).
    spec: str = "docs/rational-interval-arithmetic-spec.md"
    #: Headings the specification must carry, verbatim.
    required_sections: tuple[str, ...] = ()
    #: The document holding the binding table; ``None`` means the spec itself.
    binding: str | None = None
    #: Restrict rows to the section under this heading (up to the next ``##``
    #: or ``###`` heading); ``None`` reads the whole binding document.
    binding_heading: str | None = None
    #: The admissible classes; a row naming a module with any other class is
    #: an error. ``None`` admits any class.
    classes: tuple[str, ...] | None = CLASSES
    #: The class whose modules may hold floating point, and only if allowlisted.
    quarantine_class: str = "QUARANTINED"
    #: List items of this Markdown file are the C1 allowlist; prose is not.
    allowlist: str = "tools/exact_arithmetic_allowlist.md"
    #: Directories scanned for arithmetic consumers and for floating point.
    scan_roots: tuple[str, ...] = ("kernel", "vendor/mojo")
    suffixes: tuple[str, ...] = (".mojo",)
    #: ``finite_exact`` modules whose import makes a file an arithmetic
    #: consumer; ``None`` means any ``finite_exact`` module.
    arithmetic_modules: tuple[str, ...] | None = None
    #: Skip files under a directory whose name starts with a dot.
    skip_hidden: bool = False
    #: Files exempt from C7 because their header is upstream's.
    citation_exempt: frozenset[str] = frozenset()
    #: Also exempt from C7 every file inside a package ``vendored.toml`` vendors.
    exempt_vendored_citations: bool = True
    #: Path prefixes the C1 scan skips (beside the allowlist).
    float_exempt_prefixes: tuple[str, ...] = ()


def _read(root: Path, rel: str) -> str:
    return (root / rel).read_text(encoding="utf-8")


def section(text: str, heading: str) -> str | None:
    """The body under ``heading`` up to the next level-2 or level-3 heading."""
    at = text.find(heading)
    if at < 0:
        return None
    rest = text[at + len(heading):]
    end = re.search(r"^#{2,3} ", rest, flags=re.M)
    return rest if end is None else rest[: end.start()]


def binding_rows(root: Path, policy: Policy) -> list[tuple[str, list[str]]]:
    """``(class, [module paths])`` for every table row that names a module.

    A row names a module when its second cell holds a backticked ``.mojo`` or
    ``.py`` path; header and separator rows hold none. Raises ``ValueError``
    when the binding heading is absent, since then no row could be read.
    """
    text = _read(root, policy.binding or policy.spec)
    if policy.binding_heading is not None:
        body = section(text, policy.binding_heading)
        if body is None:
            raise ValueError(f"binding heading {policy.binding_heading!r} not found")
        text = body
    rows = []
    for line in text.splitlines():
        match = ROW_RE.match(line)
        if not match:
            continue
        cells = [cell.strip() for cell in match.group("cells").split("|")]
        if len(cells) < 3:
            continue
        paths = PATH_RE.findall(cells[1])
        if paths:
            rows.append((cells[2], paths))
    return rows


def allowlisted(root: Path, policy: Policy) -> set[str]:
    """Paths named by list items of the allowlist.

    Only list items count. The file's prose names paths too, and reading
    those as grants would quarantine whatever the document mentions.
    """
    path = root / policy.allowlist
    if not path.exists():
        return set()
    entries: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.lstrip().startswith(("-", "*")):
            entries.update(PATH_RE.findall(line))
    return entries


def scanned_files(root: Path, policy: Policy) -> list[str]:
    """Repo-relative files under the scan roots with a scanned suffix."""
    out = set()
    for base in policy.scan_roots:
        for path in (root / base).rglob("*"):
            rel = path.relative_to(root)
            if path.suffix not in policy.suffixes or not path.is_file():
                continue
            if policy.skip_hidden and any(part.startswith(".") for part in rel.parts):
                continue
            out.add(rel.as_posix())
    return sorted(out)


def imported_layers(text: str) -> set[str | None]:
    """Imported ``finite_exact`` layers; ``None`` means the package or a wildcard.

    Python's syntax tree handles aliases, continuations and compound lines.
    Mojo uses the lexical fallback, with comments and literal text masked.
    """
    try:
        tree = ast.parse(text)
    except SyntaxError:
        tree = None
    if tree is not None:
        layers: set[str | None] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    if alias.name == "finite_exact" or alias.name.startswith("finite_exact."):
                        layers.add(alias.name.partition(".")[2].split(".")[0] or None)
            elif isinstance(node, ast.ImportFrom) and node.level == 0:
                if node.module == "finite_exact":
                    layers.update(None if alias.name == "*" else alias.name for alias in node.names)
                elif node.module and node.module.startswith("finite_exact."):
                    layers.add(node.module.split(".")[1])
        return layers

    text = re.sub(r"\\\r?\n", " ", mask_comments_and_strings(text))
    names: list[str | None] = list(FROM_MODULE_RE.findall(text))
    for clause in IMPORT_MODULE_RE.findall(text):
        for item in clause.split(","):
            dotted = re.split(r"\s+as\s+", item.strip(), maxsplit=1)[0]
            if dotted == "finite_exact" or dotted.startswith("finite_exact."):
                names.append(dotted.partition(".")[2].split(".")[0] or None)
    for clause in FROM_PACKAGE_RE.findall(text):
        for item in clause.strip("()").split(","):
            name = re.split(r"\s+as\s+", item.strip(), maxsplit=1)[0]
            if name:
                names.append(None if name == "*" else name)
    return set(names)


def arithmetic_consumers(root: Path, policy: Policy) -> set[str]:
    """Scanned files that import the exact-arithmetic layers directly, by any spelling.

    Importing the package itself reaches every layer, so it counts whatever
    the policy's ``arithmetic_modules`` are. The syntax tree, or masked Mojo
    fallback, ensures a comment inside a parenthesised import cannot hide a
    layer and an import quoted in a docstring is not one.
    """
    wanted = policy.arithmetic_modules
    return {
        rel for rel in scanned_files(root, policy)
        if any(wanted is None or name is None or name in wanted for name in imported_layers(_read(root, rel)))
    }


def citation_exempt(root: Path, policy: Policy) -> tuple[frozenset[str], tuple[str, ...]]:
    """Exact paths and directory prefixes exempt from the citation check."""
    prefixes = tuple(f"{d}/" for d in vendored_directories(root)) if policy.exempt_vendored_citations else ()
    return policy.citation_exempt, prefixes


def _python_float_lines(text: str) -> set[int] | None:
    """Python lines holding float tokens or f-string fields; ``None`` if unparseable.

    Python's tokenizer distinguishes literal text from executable code even
    when an f-string field reuses the outer quote. On Python 3.11 it masks
    whole f-strings, so the syntax tree supplies their executable fields.
    Nested f-strings have their own fields and are scanned in turn.
    """
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return None
    tokens = [token for token in tokenize.generate_tokens(io.StringIO(text).readline)
              if token.type not in (tokenize.COMMENT, tokenize.NL, tokenize.NEWLINE,
                                    tokenize.INDENT, tokenize.DEDENT, tokenize.ENDMARKER)]
    hits = {token.start[0] for token in tokens
            if token.type in (tokenize.NAME, tokenize.NUMBER)
            and (_PYTHON_FLOAT_RE.search(token.string)
                 or (token.type == tokenize.NUMBER and token.string.endswith(("j", "J"))))}
    for index, token in enumerate(tokens):
        if (index >= 2 and token.type == tokenize.NAME
                and tokens[index - 2].string == "DType" and tokens[index - 1].string == "."
                and FLOAT_RE.search("DType." + token.string)):
            hits.add(token.start[0])
    hits |= {
        node.value.lineno for node in ast.walk(tree)
        if isinstance(node, ast.FormattedValue)
        and _PYTHON_FLOAT_RE.search(mask_comments_and_strings(ast.unparse(node.value)))
    }
    # Python 3.11 tokenizes an entire f-string as STRING; its imaginary
    # constants still appear as complex values in the syntax tree.
    hits |= {node.lineno for node in ast.walk(tree)
             if isinstance(node, ast.Constant) and isinstance(node.value, complex)}
    return hits


def floating_point(root: Path, rel: str) -> list[str]:
    """``rel:line: ...`` for every C1 hit outside comments and literal string text.

    In Python the interpolated fields of an f-string are code and are scanned;
    a Python file that cannot be parsed is reported rather than skipped.
    """
    text = _read(root, rel)
    lines = text.splitlines()
    if rel.endswith(".py"):
        hits = _python_float_lines(text)
        if hits is None:
            return [f"{rel}: cannot parse for the f-string scan (C1)"]
    else:
        hits = {lineno for lineno, line in enumerate(mask_comments_and_strings(text).splitlines(), start=1)
                if FLOAT_RE.search(line)}
    return [f"{rel}:{lineno}: floating point in kernel scope (C1): {lines[lineno - 1].strip()}" for lineno in sorted(hits)]


def audit(root: Path, policy: Policy) -> list[str]:
    """Every violation, in a stable order, each named once; empty means clean."""
    missing = [f"missing {rel}" for rel in (policy.spec, policy.binding) if rel and not (root / rel).exists()]
    if missing:
        return missing
    spec = _read(root, policy.spec)
    errors = [f"spec lacks section {s!r}" for s in policy.required_sections if s not in spec]
    if policy.repository not in spec:
        errors.append(f"{policy.spec} does not name {policy.repository} as a consumer")
    if errors:
        return errors

    try:
        rows = binding_rows(root, policy)
    except ValueError as exc:
        return [f"{policy.binding or policy.spec}: {exc}"]
    if not rows:
        return [f"{policy.binding or policy.spec} has no binding rows"]

    exempt_files, exempt_prefixes = citation_exempt(root, policy)
    bound: set[str] = set()
    quarantined: set[str] = set()
    for cls, modules in rows:
        if policy.classes is not None and cls not in policy.classes:
            errors.append(f"binding row for {', '.join(modules)} has unknown class {cls!r}")
            continue
        for rel in modules:
            bound.add(rel)
            if cls == policy.quarantine_class:
                quarantined.add(rel)
            if not (root / rel).exists():
                errors.append(f"binding row names missing file {rel}")
                continue
            if rel in exempt_files or rel.startswith(exempt_prefixes):
                continue
            if policy.spec not in _read(root, rel):
                errors.append(f"{rel} does not cite {policy.spec} (C7)")

    errors += [f"arithmetic consumer lacks binding row: {rel}" for rel in sorted(arithmetic_consumers(root, policy) - bound)]

    allow = allowlisted(root, policy)
    errors += [f"{rel} is {policy.quarantine_class} but not allowlisted" for rel in sorted(quarantined - allow)]
    errors += [f"{rel} is allowlisted but not a {policy.quarantine_class} binding row" for rel in sorted(allow - quarantined)]

    for rel in scanned_files(root, policy):
        if rel in allow or rel.startswith(policy.float_exempt_prefixes):
            continue
        errors += floating_point(root, rel)
    return list(dict.fromkeys(errors))


def run(root: Path, policy: Policy) -> int:
    """Audit ``root`` under ``policy``; print the report and return an exit code."""
    errors = audit(root, policy)
    if errors:
        print("exact-arithmetic audit failed:\n")
        print("\n".join(f"- {e}" for e in errors))
        print(f"\nSee {policy.spec}, sections 5 to 7" + (f", and {policy.binding}." if policy.binding else "."))
        return 1
    print("OK: every arithmetic consumer is bound, cites the spec, and stays exact.")
    return 0
