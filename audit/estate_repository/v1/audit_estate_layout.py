#!/usr/bin/env python3
"""Validate an Estate Repository Template v1 consumer.

This module is intentionally domain-agnostic. It validates repository architecture
and authority declarations only; domain theorem status, certificate acceptance,
effect authorization, and persisted operational state remain consumer responsibilities.
"""

from __future__ import annotations

import argparse
import glob
import re
import sys
import tomllib
from pathlib import Path

ALLOWED_PLANE_AUTHORITIES = {
    "governance",
    "canonical_executable",
    "claim_state",
    "non_authoritative_reference",
    "non_authoritative_oracle",
    "non_authoritative_experiment",
    "contract",
    "evidence",
    "pinned_external",
    "repository_tooling",
    "exposition",
    "publication",
    "example",
}
ALLOWED_LANGUAGE_AUTHORITIES = {"canonical", "supporting"}


def fail(message: str) -> None:
    raise AssertionError(message)


def load(root: Path, manifest: str = "estate.toml") -> dict:
    path = root / manifest
    if not path.is_file():
        fail(f"missing estate manifest: {manifest}")
    return tomllib.loads(path.read_text(encoding="utf-8"))


def matches(root: Path, pattern: str) -> list[Path]:
    return [Path(p) for p in glob.glob(str(root / pattern), recursive=True)]


def validate(data: dict, root: Path) -> None:
    if data.get("version") != 1:
        fail("estate.toml version must be 1")
    if data.get("template") != "estate-repository-v1":
        fail("estate.toml template must be estate-repository-v1")

    repository = data.get("repository", {})
    repository_id = repository.get("id", "")
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", repository_id):
        fail("repository.id must be OWNER/REPOSITORY")
    if repository.get("layout_status") not in {"transitional", "canonical"}:
        fail("repository.layout_status must be transitional or canonical")
    if not isinstance(repository.get("default_branch"), str) or not repository["default_branch"]:
        fail("repository.default_branch must be a nonempty string")

    principles = data.get("principles", {})
    if principles.get("ordering") != ["authority", "domain", "language"]:
        fail("principles.ordering must be authority, domain, language")
    if principles.get("cross_language_disagreement") != "fail_closed":
        fail("cross-language disagreement must fail closed")
    if principles.get("empty_silos") != "forbidden":
        fail("empty silos must be forbidden")

    planes = data.get("plane", [])
    if not isinstance(planes, list) or not planes:
        fail("at least one authority plane is required")

    ids: set[str] = set()
    targets: set[str] = set()
    for plane in planes:
        if not isinstance(plane, dict):
            fail("each plane must be a table")
        plane_id = plane.get("id", "")
        target = plane.get("target", "")
        authority = plane.get("authority", "")
        if not isinstance(plane_id, str) or not plane_id:
            fail("plane.id is required")
        if plane_id in ids:
            fail(f"duplicate plane id: {plane_id}")
        ids.add(plane_id)
        if not isinstance(target, str) or not target:
            fail(f"plane {plane_id}: target is required")
        if target in targets:
            fail(f"duplicate plane target: {target}")
        targets.add(target)
        if authority not in ALLOWED_PLANE_AUTHORITIES:
            fail(f"plane {plane_id}: unknown authority {authority!r}")

        current = plane.get("current", [])
        current_globs = plane.get("current_globs", [])
        if not isinstance(current, list) or not all(isinstance(x, str) and x for x in current):
            fail(f"plane {plane_id}: current must be a string list")
        if not isinstance(current_globs, list) or not all(
            isinstance(x, str) and x for x in current_globs
        ):
            fail(f"plane {plane_id}: current_globs must be a string list")
        if plane.get("required", False) and not (current or current_globs):
            fail(f"plane {plane_id}: required plane needs a current mapping")

        for rel in current:
            if not (root / rel).exists():
                fail(f"plane {plane_id}: missing current path {rel}")
        for pattern in current_globs:
            if not matches(root, pattern):
                fail(f"plane {plane_id}: current_globs pattern matches nothing: {pattern}")

    if "kernel" not in ids:
        fail("kernel plane is required for this template")
    if "policy" not in ids:
        fail("policy plane is required for this template")

    languages = data.get("language", [])
    if not isinstance(languages, list) or not languages:
        fail("at least one language declaration is required")

    names: set[str] = set()
    canonical = []
    for language in languages:
        if not isinstance(language, dict):
            fail("each language must be a table")
        name = language.get("name", "")
        authority = language.get("authority", "")
        roles = language.get("roles", [])
        if not isinstance(name, str) or not name:
            fail("language.name is required")
        if name in names:
            fail(f"duplicate language: {name}")
        names.add(name)
        if authority not in ALLOWED_LANGUAGE_AUTHORITIES:
            fail(f"language {name}: invalid authority {authority!r}")
        if not isinstance(roles, list) or not roles or not all(isinstance(x, str) and x for x in roles):
            fail(f"language {name}: roles must be a nonempty string list")
        if authority == "canonical":
            canonical.append(language)
        if language.get("acceptance_authority") and authority != "canonical":
            fail(f"language {name}: supporting language cannot have acceptance authority")

    if len(canonical) != 1:
        fail("exactly one canonical language is required")
    if "kernel" not in canonical[0].get("roles", []):
        fail("canonical language must own the kernel role")

    if not (root / "ARCHITECTURE.md").is_file():
        fail("missing architecture entrypoint: ARCHITECTURE.md")

    workspace = root / "pixi.toml"
    if workspace.is_file():
        wdata = tomllib.loads(workspace.read_text(encoding="utf-8"))
        expected_name = repository_id.split("/", 1)[1]
        if wdata.get("workspace", {}).get("name") != expected_name:
            fail(
                "pixi workspace identity disagrees with estate.toml: "
                f"expected {expected_name!r}"
            )

    polyglot = root / "polyglot.manifest.toml"
    if polyglot.is_file():
        pdata = tomllib.loads(polyglot.read_text(encoding="utf-8"))
        if pdata.get("repository") != repository_id:
            fail("polyglot.manifest.toml repository disagrees with estate.toml")
        estate_link = pdata.get("estate", {}).get("manifest")
        if estate_link != "estate.toml":
            fail("polyglot.manifest.toml must link to estate.toml")


def validate_tooling_pin(
    data: dict,
    expected_repository: str | None = None,
    expected_path: str | None = None,
    expected_revision: str | None = None,
) -> None:
    expected = (expected_repository, expected_path, expected_revision)
    if any(value is not None for value in expected) and not all(
        value is not None for value in expected
    ):
        fail("tooling pin expectations must provide repository, path, and revision together")

    tooling = data.get("estate_tooling")
    if tooling is None:
        if expected_repository is not None:
            fail("estate_tooling table is required when using pinned shared tooling")
        return
    if not isinstance(tooling, dict):
        fail("estate_tooling must be a table")

    repository = tooling.get("repository", "")
    path = tooling.get("path", "")
    revision = tooling.get("revision", "")
    if not isinstance(repository, str) or not re.fullmatch(r"[^/\\s]+/[^/\\s]+", repository):
        fail("estate_tooling.repository must be OWNER/REPOSITORY")
    if not isinstance(path, str) or not path or path.startswith("/"):
        fail("estate_tooling.path must be a nonempty repository-relative path")
    if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40}", revision):
        fail("estate_tooling.revision must be an immutable 40-hex commit SHA")

    if expected_repository is not None and repository != expected_repository:
        fail(
            "estate_tooling.repository disagrees with executing shared audit: "
            f"expected {expected_repository!r}"
        )
    if expected_path is not None and path != expected_path:
        fail(
            "estate_tooling.path disagrees with executing shared audit: "
            f"expected {expected_path!r}"
        )
    if expected_revision is not None and revision != expected_revision:
        fail(
            "estate_tooling.revision disagrees with executing shared audit: "
            f"expected {expected_revision!r}"
        )


def audit(
    root: Path,
    manifest: str = "estate.toml",
    tooling_repository: str | None = None,
    tooling_path: str | None = None,
    tooling_revision: str | None = None,
) -> None:
    data = load(root, manifest)
    validate(data, root)
    validate_tooling_pin(data, tooling_repository, tooling_path, tooling_revision)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="consumer repository root (default: current working directory)",
    )
    parser.add_argument(
        "--manifest",
        default="estate.toml",
        help="manifest path relative to --root (default: estate.toml)",
    )
    parser.add_argument(
        "--tooling-repository",
        help="expected shared tooling OWNER/REPOSITORY; requires path and revision",
    )
    parser.add_argument(
        "--tooling-path",
        help="expected shared tooling path; requires repository and revision",
    )
    parser.add_argument(
        "--tooling-revision",
        help="expected immutable 40-hex shared tooling commit SHA",
    )
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        audit(
            root,
            args.manifest,
            args.tooling_repository,
            args.tooling_path,
            args.tooling_revision,
        )
    except (AssertionError, tomllib.TOMLDecodeError) as exc:
        print(f"estate-layout audit failed: {exc}", file=sys.stderr)
        return 1
    print("estate-layout audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
