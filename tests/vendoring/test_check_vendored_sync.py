"""The vendoring checker, against a consumer built in a temporary directory.

The checker is itself vendored, so the depth at which it sits inside a
consumer must not matter. Each case below builds a small consumer, puts the
checker at a different depth, and asks what it reports.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from vendoring import check_vendored_sync as checker  # noqa: E402

COMMIT = "0" * 40


def build_consumer(tmp_path: Path, depth: int = 1) -> Path:
    """A consumer with one vendored package and the checker `depth` levels down."""
    package = tmp_path / "src" / "widget"
    package.mkdir(parents=True)
    (package / "__init__.mojo").write_text("# widget\n", encoding="utf-8")
    (package / "core.mojo").write_text("def core() -> Bool:\n    return True\n", encoding="utf-8")
    digests = {
        f"widget/{name}": hashlib.sha256((package / name).read_bytes()).hexdigest()
        for name in ("__init__.mojo", "core.mojo")
    }
    manifest = "\n".join(
        [
            "[[package]]",
            'name = "widget"',
            'repository = "larsbx/finite-math-kernels"',
            f'commit = "{COMMIT}"',
            'root = "src"',
            "",
            "[package.files]",
            *[f'"{rel}" = "{digest}"' for rel, digest in sorted(digests.items())],
            "",
        ]
    )
    (tmp_path / "vendored.toml").write_text(manifest, encoding="utf-8")
    here = tmp_path.joinpath(*[f"level{i}" for i in range(depth)])
    here.mkdir(parents=True, exist_ok=True)
    return here / "check_vendored_sync.py"


@pytest.mark.parametrize("depth", [1, 2, 3])
def test_repo_root_is_found_at_any_depth(tmp_path, depth):
    placed = build_consumer(tmp_path, depth)
    assert checker.repo_root(placed) == tmp_path


def test_a_faithful_copy_reports_no_errors(tmp_path):
    build_consumer(tmp_path)
    assert checker.check(tmp_path, tmp_path / "vendored.toml") == []


def test_a_patched_file_is_drift(tmp_path):
    build_consumer(tmp_path)
    (tmp_path / "src" / "widget" / "core.mojo").write_text("# patched\n", encoding="utf-8")
    errors = checker.check(tmp_path, tmp_path / "vendored.toml")
    assert len(errors) == 1 and "differs from" in errors[0]


def test_an_unlisted_file_inside_the_package_is_drift(tmp_path):
    build_consumer(tmp_path)
    (tmp_path / "src" / "widget" / "extra.mojo").write_text("# extra\n", encoding="utf-8")
    errors = checker.check(tmp_path, tmp_path / "vendored.toml")
    assert len(errors) == 1 and "not pinned" in errors[0]


def test_a_missing_file_is_drift(tmp_path):
    build_consumer(tmp_path)
    (tmp_path / "src" / "widget" / "core.mojo").unlink()
    errors = checker.check(tmp_path, tmp_path / "vendored.toml")
    assert any("missing" in error for error in errors)


def test_a_missing_manifest_is_reported_not_guessed(tmp_path):
    assert checker.check(tmp_path, tmp_path / "vendored.toml") == ["missing manifest vendored.toml"]


def test_a_short_commit_is_refused(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    manifest.write_text(manifest.read_text().replace(COMMIT, "abc1234"), encoding="utf-8")
    errors = checker.check(tmp_path, manifest)
    assert any("full 40-hex SHA" in error for error in errors)


def test_pin_rewrites_the_digests_it_was_given(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    (tmp_path / "src" / "widget" / "core.mojo").write_text("# patched\n", encoding="utf-8")
    assert checker.check(tmp_path, manifest) != []
    commit = "a" * 40
    assert checker.pin("widget", commit, tmp_path, manifest) == []
    assert checker.check(tmp_path, manifest) == []
    assert commit in manifest.read_text()


def test_pin_refuses_a_short_commit(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    assert checker.pin("widget", "abc1234", tmp_path, manifest) == ["commit must be a full 40-hex SHA"]
