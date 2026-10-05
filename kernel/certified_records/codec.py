"""Python binding to the Mojo record codec, `kernel/certified_records/codec.mojo`.

There is one codec. This module holds no parsing or encoding logic: it loads
the extension module that `pixi run build-certified-records-py` builds from
`kernel/certified_records/python_binding.mojo` and converts types at the
boundary. A `Schema` is plain data; values cross as decimal strings, so 64-bit
fields survive intact.
"""

from __future__ import annotations

import importlib.util
from dataclasses import dataclass
from pathlib import Path

EXTENSION = Path(__file__).resolve().parents[2] / ".build" / "certified_records_ext.so"


def _load():
    if not EXTENSION.is_file():
        raise ImportError(f"{EXTENSION} is missing; build it with `pixi run build-certified-records-py`")
    spec = importlib.util.spec_from_file_location("certified_records_ext", EXTENSION)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_mojo = _load()


@dataclass(frozen=True)
class Schema:
    tag: str
    fields: tuple[tuple[str, int], ...]

    @property
    def names(self) -> tuple[str, ...]:
        return tuple(name for name, _ in self.fields)

    def wire(self) -> tuple:
        return (self.tag, list(self.names), [bits for _, bits in self.fields])


def decode(schema: Schema, line: str) -> tuple[int, ...]:
    """The field values of `line`, or `ValueError('malformed:...')`."""
    reason, values = _mojo.decode(schema.wire(), line)
    if reason:
        raise ValueError(reason)
    return tuple(int(v) for v in values)


def encode(schema: Schema, values: tuple[int, ...]) -> str:
    return _mojo.encode(schema.wire(), [str(v) for v in values])


def first_mismatch(schema: Schema, claimed: tuple[int, ...], actual: tuple[int, ...], start: int = 0) -> str:
    return _mojo.first_mismatch(schema.wire(), [str(v) for v in claimed], [str(v) for v in actual], start)


def vector_cases(text: str, kind: str) -> list[list[str]]:
    return [list(row) for row in _mojo.vector_cases(text, kind)]
