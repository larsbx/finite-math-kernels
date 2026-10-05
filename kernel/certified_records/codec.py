"""Canonical one-line records: a tag and unsigned decimal fields of 32 or 64 bits.

Python half of `kernel/certified_records/codec.mojo`; the two read the same
vectors, `conformance/certified_records_v1.txt`.

A record line is the tag and one canonical decimal per field, single-space
separated. A canonical decimal is ASCII digits with no sign and no leading
zero, below 2^bits. `decode` is total: every line either decodes or is refused
as `malformed:arity` (wrong tag or token count) or `malformed:<field>` (the
first field that is not canonical), so a contract built on it inherits one
refusal grammar. Two records are equal iff their fields are, so replay
compares fields with `first_mismatch` and reports `mismatch:<field>`.
"""

from __future__ import annotations

from dataclasses import dataclass

WIDTHS = (32, 64)


@dataclass(frozen=True)
class Schema:
    tag: str
    fields: tuple[tuple[str, int], ...]

    def __post_init__(self) -> None:
        if not self.fields or any(bits not in WIDTHS for _, bits in self.fields):
            raise ValueError(f"{self.tag}: every field is 32 or 64 bits")

    @property
    def names(self) -> tuple[str, ...]:
        return tuple(name for name, _ in self.fields)


def parse_canonical(token: str, bits: int) -> int | None:
    if not (token.isascii() and token.isdigit()) or (len(token) > 1 and token[0] == "0"):
        return None
    value = int(token)
    return value if value < 2**bits else None


def decode(schema: Schema, line: str) -> tuple[int, ...]:
    """The field values of `line`, or `ValueError('malformed:...')`."""
    tokens = line.split(" ")
    if len(tokens) != 1 + len(schema.fields) or tokens[0] != schema.tag:
        raise ValueError("malformed:arity")
    values = []
    for (name, bits), token in zip(schema.fields, tokens[1:]):
        value = parse_canonical(token, bits)
        if value is None:
            raise ValueError(f"malformed:{name}")
        values.append(value)
    return tuple(values)


def encode(schema: Schema, values: tuple[int, ...]) -> str:
    return " ".join([schema.tag, *map(str, values)])


def first_mismatch(schema: Schema, claimed: tuple[int, ...], actual: tuple[int, ...], start: int = 0) -> str:
    """`mismatch:<field>` for the first field from `start` on where they differ, else ''."""
    for name, x, y in list(zip(schema.names, claimed, actual))[start:]:
        if x != y:
            return f"mismatch:{name}"
    return ""


def vector_cases(text: str, kind: str) -> list[list[str]]:
    """The tab-separated columns after the kind, for every row of that kind; `#` lines are comments."""
    rows = [line.split("\t") for line in text.splitlines() if not line.startswith("#")]
    return [row[1:] for row in rows if row[0] == kind]
