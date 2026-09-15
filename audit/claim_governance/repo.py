"""Read-only view of the repository being audited."""

from __future__ import annotations

from dataclasses import dataclass, field
from fnmatch import fnmatch
from pathlib import Path

from claim_governance.lexing import mask_comments_and_strings, mask_for


@dataclass(frozen=True)
class Repo:
    root: Path
    exclude: tuple[str, ...] = ()
    _cache: dict[str, str] = field(default_factory=dict, compare=False, repr=False)

    def files(self, globs: tuple[str, ...]) -> tuple[str, ...]:
        """Repository-relative POSIX paths matching any glob, minus exclusions, sorted."""
        found = {
            path.relative_to(self.root).as_posix()
            for pattern in globs
            for path in self.root.glob(pattern)
            if path.is_file()
        }
        return tuple(sorted(rel for rel in found if not self.excluded(rel)))

    def excluded(self, rel: str) -> bool:
        return any(fnmatch(rel, pattern) or rel.startswith(pattern.rstrip("*")) for pattern in self.exclude)

    def exists(self, rel: str) -> bool:
        return (self.root / rel).is_file()

    def text(self, rel: str) -> str:
        if rel not in self._cache:
            self._cache[rel] = (self.root / rel).read_text(encoding="utf-8", errors="replace")
        return self._cache[rel]

    def masked(self, rel: str) -> str:
        """File text with comments, string literals, or fenced code blanked by suffix."""
        return mask_for(Path(rel).suffix, self.text(rel))

    def surface(self, rel: str) -> str:
        """Text for status surfaces: comments blanked, but Markdown code fences and
        source string literals kept, since dependency chains, status tables, and
        ledger names live inside them."""
        suffix = Path(rel).suffix
        if suffix == ".md":
            return self.text(rel)
        if suffix in {".py", ".mojo"}:
            return mask_comments_and_strings(self.text(rel), keep_strings=True)
        return mask_for(suffix, self.text(rel))
