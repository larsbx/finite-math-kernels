"""Every path and task reference in the tree resolves, and the checker sees stale ones."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import check_references as refs  # noqa: E402
import provenance  # noqa: E402

TRACKED = ["README.md", "pixi.toml", "docs/spec.md", "pkg/a.mojo", "tests/pkg/test_a.mojo", "tools/x.py", "audit/POST_CONSOLIDATION_AUDIT_2026-09-15.md"]
TASKS = {"test", "test-pkg"}


def test_tree_references_resolve():
    assert refs.check(refs.tree_files(), provenance.tracked_files(), refs.defined_tasks()) == []
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "check_references.py")], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout


def test_external_references_attest_a_repository():
    assert all(value for value in refs.EXTERNAL.values())
    assert not any(token in provenance.tracked_files() for token in refs.EXTERNAL)


def test_tokens():
    text = 'See `docs/spec.md`, ``pkg/a.mojo``, `a.mojo`, and `pixi run test`; "pixi run verify" is data.\nReplay with `pixi run replay`.'
    assert refs.path_tokens(text) == ["docs/spec.md", "pkg/a.mojo", "a.mojo"]
    assert refs.task_tokens(text) == ["test", "replay"]


def test_check_resolves_tracked_unique_basename_and_external_only():
    files = {"docs/spec.md": "`pkg/a.mojo` `a.mojo` `docs/other.md` `x.py` `test_a.mojo` `pixi run test-pkg` `pixi run smoke`"}
    assert refs.check(files, TRACKED, TASKS, external={"docs/other.md": "elsewhere"}) == [
        "docs/spec.md: task `pixi run smoke` is not defined in pixi.toml"]
    assert refs.check(files, TRACKED, TASKS, external={}) == [
        "docs/spec.md: path `docs/other.md` is not a tracked file, a unique basename, or a listed external reference",
        "docs/spec.md: task `pixi run smoke` is not defined in pixi.toml"]
    ambiguous = TRACKED + ["other/x.py"]
    assert refs.check({"README.md": "`x.py`"}, ambiguous, TASKS, external={}) == [
        "README.md: path `x.py` is not a tracked file, a unique basename, or a listed external reference"]


def test_audit_records_and_unchecked_suffixes_are_skipped():
    files = {"audit/POST_CONSOLIDATION_AUDIT_2026-09-15.md": "`gone.md` `pixi run smoke`", "fixtures/v.json": "`gone.md`",
             "tests/references/test_references.py": "`gone.md`"}
    assert refs.check(files, TRACKED, TASKS, external={}) == []


def test_executables_are_not_tasks():
    assert refs.check({"README.md": "`pixi run mojo run -I . x.mojo` and `pixi run python tools/x.py`"}, TRACKED, TASKS, external={}) == []
