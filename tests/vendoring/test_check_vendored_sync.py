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
sys.path.insert(0, str(ROOT / "kernel"))

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


def test_pin_drops_a_file_that_the_fresh_copy_no_longer_has(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    removed = tmp_path / "src" / "widget" / "core.mojo"
    removed.unlink()
    assert checker.pin("widget", "a" * 40, tmp_path, manifest) == []
    assert "core.mojo" not in manifest.read_text()
    assert checker.check(tmp_path, manifest) == []


def test_pin_keeps_a_listed_non_source_file_that_is_still_present(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    (tmp_path / "src" / "widget" / "Spec.tla").write_text("---- MODULE Spec ----\n", encoding="utf-8")
    manifest.write_text(manifest.read_text().replace(
        "[package.files]\n", '[package.files]\n"widget/Spec.tla" = "0"\n'), encoding="utf-8")
    assert checker.pin("widget", "a" * 40, tmp_path, manifest) == []
    assert '"widget/Spec.tla"' in manifest.read_text()
    assert checker.check(tmp_path, manifest) == []


def test_pin_refuses_a_package_with_nothing_left_to_pin(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    for path in (tmp_path / "src" / "widget").iterdir():
        path.unlink()
    assert checker.pin("widget", "a" * 40, tmp_path, manifest) == ["widget: nothing to pin under src/widget"]


def test_pin_records_a_non_source_file_that_upstream_renamed(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    manifest.write_text(manifest.read_text().replace(
        "[package.files]\n", '[package.files]\n"widget/Spec.tla" = "0"\n'), encoding="utf-8")
    (tmp_path / "src" / "widget" / "Model.tla").write_text("---- MODULE Model ----\n", encoding="utf-8")
    assert checker.pin("widget", "a" * 40, tmp_path, manifest) == []
    pinned = manifest.read_text()
    assert '"widget/Model.tla"' in pinned and "Spec.tla" not in pinned
    assert checker.check(tmp_path, manifest) == []


def test_an_unlisted_non_source_file_inside_the_package_is_drift(tmp_path):
    build_consumer(tmp_path)
    (tmp_path / "src" / "widget" / "Model.tla").write_text("---- MODULE Model ----\n", encoding="utf-8")
    assert checker.check(tmp_path, tmp_path / "vendored.toml") == [
        "widget: widget/Model.tla is not pinned in vendored.toml"]


def test_bytecode_caches_are_neither_pinned_nor_drift(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    cache = tmp_path / "src" / "widget" / "__pycache__"
    cache.mkdir()
    (cache / "core.cpython-311.pyc").write_bytes(b"\0")
    (tmp_path / "src" / "widget" / "stale.pyc").write_bytes(b"\0")
    assert checker.check(tmp_path, manifest) == []
    assert checker.pin("widget", "a" * 40, tmp_path, manifest) == []
    assert ".pyc" not in manifest.read_text()


def _single_file_package(tmp_path: Path) -> Path:
    """A package pinned as one file under its root, with no directory named after it."""
    (tmp_path / "proof").mkdir()
    (tmp_path / "proof" / "Spec.tla").write_text("---- MODULE Spec ----\n", encoding="utf-8")
    manifest = tmp_path / "vendored.toml"
    manifest.write_text("\n".join([
        "[[package]]", 'name = "spec"', 'repository = "larsbx/finite-math-kernels"',
        f'commit = "{COMMIT}"', 'root = "proof"', "", "[package.files]", '"Spec.tla" = "0"', ""]), encoding="utf-8")
    return manifest


def test_pin_keeps_a_listed_file_outside_the_package_directory(tmp_path):
    manifest = _single_file_package(tmp_path)
    assert checker.pin("spec", "a" * 40, tmp_path, manifest) == []
    assert '"Spec.tla"' in manifest.read_text()
    assert checker.check(tmp_path, manifest) == []


def test_pin_refuses_a_listed_file_outside_the_package_directory_that_is_gone(tmp_path):
    manifest = _single_file_package(tmp_path)
    (tmp_path / "proof" / "Spec.tla").unlink()
    assert checker.pin("spec", "a" * 40, tmp_path, manifest) == ["spec: cannot pin missing file Spec.tla"]


def test_pin_refuses_a_short_commit(tmp_path):
    build_consumer(tmp_path)
    manifest = tmp_path / "vendored.toml"
    assert checker.pin("widget", "abc1234", tmp_path, manifest) == ["commit must be a full 40-hex SHA"]


ESTATE_TEMPLATE = '[repo]\nid = "consumer"\n\n[[dep]]\nid = "finite-math-kernels"\nrev = "{commit}"\npin = "{pin}"\n'


def test_a_consumer_without_estate_has_no_estate_pins_to_keep(tmp_path):
    build_consumer(tmp_path)
    assert checker.estate_drift(tmp_path) == []
    assert checker.write_estate_pins(tmp_path) == []


def test_the_estate_pin_is_derived_and_drift_is_rederived(tmp_path):
    build_consumer(tmp_path)
    want = checker.estate_pins(tmp_path)["finite-math-kernels"]
    assert want.startswith("sha256:") and len(want) == 7 + 64
    estate = tmp_path / "ESTATE.toml"
    estate.write_text(ESTATE_TEMPLATE.format(commit=COMMIT, pin="sha256:" + "0" * 64), encoding="utf-8")
    assert any("pin" in e for e in checker.check(tmp_path))
    assert checker.write_estate_pins(tmp_path) == []
    assert estate.read_text(encoding="utf-8") == ESTATE_TEMPLATE.format(commit=COMMIT, pin=want)
    assert checker.check(tmp_path) == []


def test_the_estate_pin_covers_file_contents(tmp_path):
    build_consumer(tmp_path)
    before = checker.estate_pins(tmp_path)
    (tmp_path / "src" / "widget" / "core.mojo").write_text("def core() -> Bool:\n    return False\n", encoding="utf-8")
    assert checker.estate_pins(tmp_path) != before


def test_a_missing_estate_dep_fails_closed(tmp_path):
    build_consumer(tmp_path)
    (tmp_path / "ESTATE.toml").write_text(ESTATE_TEMPLATE.format(commit=COMMIT, pin="x").replace('id = "finite-math-kernels"', 'id = "renamed"'), encoding="utf-8")
    assert any("no [[dep]]" in e for e in checker.check(tmp_path))
    assert any("no [[dep]]" in e for e in checker.write_estate_pins(tmp_path))


def test_a_commented_dep_header_is_still_rewritten(tmp_path):
    build_consumer(tmp_path)
    estate = tmp_path / "ESTATE.toml"
    estate.write_text(ESTATE_TEMPLATE.format(commit=COMMIT, pin="stale").replace("[[dep]]\n", "[[dep]]   # vendored packages\n"), encoding="utf-8")
    assert checker.write_estate_pins(tmp_path) == []
    assert checker.check(tmp_path) == []


def test_vendored_directories_are_read_from_the_manifest(tmp_path):
    build_consumer(tmp_path)
    assert checker.vendored_directories(tmp_path) == ("src/widget",)


def test_vendored_directories_normalise_a_root_at_the_repository_root(tmp_path):
    (tmp_path / "vendored.toml").write_text(
        '[[package]]\nname = "b"\nroot = "."\n\n[[package]]\nname = "a"\nroot = "vendor/python"\n'
        '\n[[package]]\nroot = "nameless"\n',
        encoding="utf-8",
    )
    assert checker.vendored_directories(tmp_path) == ("b", "vendor/python/a")


def test_no_manifest_vendors_nothing(tmp_path):
    """The fail-closed direction: an absent manifest exempts nothing."""
    assert checker.vendored_directories(tmp_path) == ()
