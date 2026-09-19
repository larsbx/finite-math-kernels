"""Every path and task reference in the tree resolves, and the checker sees stale ones.

The engine lives in the vendorable `references` package and the policy in
`tools/check_references.py`. The cases below exercise both: the repository's
own policy against its own tree, and the engine against small trees built to
fail.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import check_references as policy_module  # noqa: E402
import provenance  # noqa: E402
from references.check_references import Policy, check, defined_tasks, path_tokens, task_tokens, tracked_files, tree_files  # noqa: E402

TRACKED = ["README.md", "pixi.toml", "docs/spec.md", "pkg/a.mojo", "tests/pkg/test_a.mojo", "tools/x.py", "audit/POST_CONSOLIDATION_AUDIT_2026-09-15.md"]
TASKS = {"test", "test-pkg"}
POLICY = policy_module.POLICY
BARE = Policy(skipped_prefixes=POLICY.skipped_prefixes)


def test_tree_references_resolve():
    assert check(tree_files(ROOT, POLICY), tracked_files(ROOT), defined_tasks(ROOT), POLICY) == []
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "check_references.py")], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout


def test_the_manifest_and_the_checker_read_one_file_listing():
    """provenance describes what the checker reads; two listings could diverge."""
    assert provenance.tracked_files() == tracked_files(ROOT)


def test_external_references_attest_a_repository():
    assert all(value for value in POLICY.external.values())
    assert not any(token in tracked_files(ROOT) for token in POLICY.external)


def test_tokens():
    text = 'See `docs/spec.md`, ``pkg/a.mojo``, `a.mojo`, and `pixi run test`; "pixi run verify" is data.\nReplay with `pixi run replay`.'
    assert path_tokens(text) == ["docs/spec.md", "pkg/a.mojo", "a.mojo"]
    assert task_tokens(text) == ["test", "replay"]


def test_check_resolves_tracked_unique_basename_and_external_only():
    files = {"docs/spec.md": "`pkg/a.mojo` `a.mojo` `docs/other.md` `x.py` `test_a.mojo` `pixi run test-pkg` `pixi run smoke`"}
    attested = Policy(external={"docs/other.md": "elsewhere"}, skipped_prefixes=POLICY.skipped_prefixes)
    assert check(files, TRACKED, TASKS, attested) == [
        "docs/spec.md: task `pixi run smoke` is not defined in pixi.toml"]
    assert check(files, TRACKED, TASKS, BARE) == [
        "docs/spec.md: path `docs/other.md` is not a tracked file, a unique basename, or a listed external reference",
        "docs/spec.md: task `pixi run smoke` is not defined in pixi.toml"]
    ambiguous = TRACKED + ["other/x.py"]
    assert check({"README.md": "`x.py`"}, ambiguous, TASKS, BARE) == [
        "README.md: path `x.py` is not a tracked file, a unique basename, or a listed external reference"]


def test_audit_records_and_unchecked_suffixes_are_skipped():
    files = {"audit/POST_CONSOLIDATION_AUDIT_2026-09-15.md": "`gone.md` `pixi run smoke`", "fixtures/v.json": "`gone.md`",
             "tests/references/test_references.py": "`gone.md`"}
    assert check(files, TRACKED, TASKS, BARE) == []


def test_executables_are_not_tasks():
    assert check({"README.md": "`pixi run mojo run -I . x.mojo` and `pixi run python tools/x.py`"}, TRACKED, TASKS, BARE) == []


def test_a_policy_carries_its_own_executables_and_suffixes():
    """The engine decides nothing; a consumer that reads other files, or runs
    other executables directly, says so in its policy."""
    narrow = Policy(suffixes=(".md",), executables=frozenset({"zig"}))
    files = {"README.md": "`pixi run zig` `pixi run mojo`", "tools/x.py": "`gone.md`"}
    assert check(files, TRACKED, TASKS, narrow) == ["README.md: task `pixi run mojo` is not defined in pixi.toml"]


def test_tracked_files_falls_back_outside_a_repository(tmp_path):
    (tmp_path / "pkg").mkdir()
    (tmp_path / "pkg" / "a.py").write_text("x = 1\n", encoding="utf-8")
    (tmp_path / "pkg" / "a.pyc").write_bytes(b"\x00")
    (tmp_path / "__pycache__").mkdir()
    (tmp_path / "__pycache__" / "b.py").write_text("y = 2\n", encoding="utf-8")
    assert tracked_files(tmp_path) == ["pkg/a.py"]
