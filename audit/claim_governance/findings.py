"""The single result type shared by every check."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, order=True)
class Finding:
    """One policy violation, anchored to a file and (optionally) a line.

    ``check`` is the check's registered name, ``rule`` the policy item that
    fired (a term, a claim name, a numerics rule name), and ``message`` the
    human-readable diagnostic.  Line ``0`` means the finding concerns the
    whole file.
    """

    path: str
    line: int
    check: str
    rule: str
    message: str

    def render(self) -> str:
        where = f"{self.path}:{self.line}" if self.line else self.path
        return f"{where}: [{self.check}/{self.rule}] {self.message}"
