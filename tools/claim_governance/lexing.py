"""Lexical helpers shared by the checks.

These are policy guards, not parsers.  Every masker preserves line breaks so
diagnostics keep their original line numbers.
"""

from __future__ import annotations

import re
from collections.abc import Iterator

_STRING_QUOTES = {"'", '"'}


def mask_comments_and_strings(source: str, *, keep_strings: bool = False) -> str:
    """Blank ``#`` comments and (unless ``keep_strings``) string literals in
    Python/Mojo source.

    Triple-quoted strings span lines; single-quoted strings end at a newline.
    Every replaced character becomes a space, so columns and lines survive.
    """
    out: list[str] = []
    quote: str | None = None
    triple = False
    escaped = False
    index = 0
    while index < len(source):
        char = source[index]
        if quote is not None:
            if char == "\n":
                out.append("\n")
                if not triple:
                    quote, escaped = None, False
                index += 1
                continue
            if triple and source.startswith(quote * 3, index):
                out.extend(quote * 3 if keep_strings else "   ")
                index += 3
                quote, triple = None, False
                continue
            out.append(char if keep_strings else " ")
            if not triple:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            index += 1
            continue
        if char == "#":
            newline = source.find("\n", index)
            end = len(source) if newline == -1 else newline
            out.extend(" " * (end - index))
            index = end
            continue
        if char in _STRING_QUOTES:
            triple = source.startswith(char * 3, index)
            quote = char
            width = 3 if triple else 1
            out.extend(source[index: index + width] if keep_strings else " " * width)
            index += width
            continue
        out.append(char)
        index += 1
    return "".join(out)


def mask_tex_comments(source: str) -> str:
    """Blank unescaped ``%`` comments in LaTeX source, keeping line breaks."""
    lines: list[str] = []
    for line in source.split("\n"):
        kept: list[str] = []
        escaped = False
        for char in line:
            if char == "%" and not escaped:
                kept.append(" " * (len(line) - len(kept)))
                break
            kept.append(char)
            escaped = char == "\\" and not escaped
        lines.append("".join(kept))
    return "\n".join(lines)


def mask_fenced_code(markdown: str) -> str:
    """Blank the bodies of fenced code blocks in Markdown, keeping line breaks."""
    out: list[str] = []
    fence: str | None = None
    for line in markdown.split("\n"):
        stripped = line.lstrip()
        if fence is None and (stripped.startswith("```") or stripped.startswith("~~~")):
            fence = stripped[:3]
            out.append("")
        elif fence is not None and stripped.startswith(fence):
            fence = None
            out.append("")
        else:
            out.append("" if fence else line)
    return "\n".join(out)


def mask_for(path_suffix: str, text: str) -> str:
    """Apply the masker appropriate to a file's suffix."""
    if path_suffix in {".py", ".mojo"}:
        return mask_comments_and_strings(text)
    if path_suffix == ".tex":
        return mask_tex_comments(text)
    if path_suffix == ".md":
        return mask_fenced_code(text)
    return text


def line_of(text: str, index: int) -> int:
    """1-based line number of character ``index`` in ``text``."""
    return text.count("\n", 0, index) + 1


def has_context(text: str, index: int, markers: tuple[str, ...], radius: int = 140) -> bool:
    """True when any marker occurs within ``radius`` characters of ``index``."""
    window = text[max(0, index - radius): index + radius].lower()
    return any(marker.lower() in window for marker in markers)


def find_all(text: str, needle: str, *, word: bool = False) -> Iterator[int]:
    """Yield the start index of every case-insensitive occurrence of ``needle``."""
    pattern = re.escape(needle)
    if word:
        pattern = rf"(?<![\w-]){pattern}(?![\w-])"
    for match in re.finditer(pattern, text, flags=re.IGNORECASE):
        yield match.start()


def window_lines(text: str, start_line: int, count: int) -> str:
    """Lines ``start_line`` (1-based) through ``start_line + count`` inclusive."""
    lines = text.split("\n")
    return "\n".join(lines[start_line - 1: start_line + count])
