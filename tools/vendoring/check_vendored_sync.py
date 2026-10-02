#!/usr/bin/env python3
"""Check vendored packages against the digests pinned in ``vendored.toml``.

A consumer repository copies each upstream package directory byte-for-byte
and records, per package, the upstream repository, the upstream commit, the
local root that acts as the Mojo include path, and the SHA-256 of every
vendored file. This script verifies that every pinned file exists with the
pinned digest and that no unlisted ``.mojo`` or ``.py`` file sits inside a
vendored package directory, so no local patch can land unnoticed. Protocol:
the README of each consumer repository.

Usage:
    check_vendored_sync.py                 check every package; exit 1 on drift
    check_vendored_sync.py pin NAME COMMIT re-pin NAME's digests from the local
                                           files after copying them from COMMIT

Manifest shape::

    [[package]]
    name = "finite_exact"
    repository = "larsbx/finite_exact"
    commit = "<40 hex>"
    root = "mojo"                      # local include root; "." for the repo root

    [package.files]
    "finite_exact/__init__.mojo" = "<sha256>"
"""

from __future__ import annotations

import hashlib
import re
import sys
import tomllib
from pathlib import Path

MANIFEST_NAME = "vendored.toml"
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SOURCE_SUFFIXES = {".mojo", ".py"}


def repo_root(start: Path | None = None) -> Path:
    """The nearest ancestor of this file holding the manifest.

    The checker is itself vendored, so it cannot assume how deep inside a
    consumer it sits. Searching upward for the manifest makes the depth
    irrelevant; with no manifest anywhere above, the grandparent is returned
    and `check` reports the manifest missing rather than guessing.
    """
    here = (start or Path(__file__)).resolve()
    for parent in here.parents:
        if (parent / MANIFEST_NAME).exists():
            return parent
    return here.parents[1]


def sources(package_dir: Path) -> list[Path]:
    return sorted(p for p in package_dir.glob("**/*") if p.suffix in SOURCE_SUFFIXES) if package_dir.exists() else []


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(manifest: Path | None = None) -> list[dict]:
    manifest = manifest or repo_root() / MANIFEST_NAME
    return tomllib.loads(manifest.read_text(encoding="utf-8")).get("package", [])


def check_package(pkg: dict, root: Path) -> list[str]:
    name = pkg.get("name", "<unnamed>")
    errors: list[str] = []
    for key in ("name", "repository", "commit", "root", "files"):
        if key not in pkg:
            errors.append(f"{name}: manifest entry lacks {key!r}")
    if errors:
        return errors
    if not COMMIT_RE.match(pkg["commit"]):
        errors.append(f"{name}: commit must be a full 40-hex SHA")
    if not pkg["files"]:
        errors.append(f"{name}: no files pinned")
    base = root / pkg["root"]
    for rel, digest in pkg["files"].items():
        path = base / rel
        if not path.exists():
            errors.append(f"{name}: {rel} missing")
        elif sha256(path) != digest:
            errors.append(f"{name}: {rel} differs from {pkg['repository']}@{pkg['commit'][:12]}")
    package_dir = base / name
    listed = set(pkg["files"])
    for path in sources(package_dir):
        rel = path.relative_to(base).as_posix()
        if rel not in listed:
            errors.append(f"{name}: {rel} is not pinned in vendored.toml")
    return errors


def check(root: Path | None = None, manifest: Path | None = None) -> list[str]:
    root = root or repo_root()
    manifest = manifest or root / MANIFEST_NAME
    if not manifest.exists():
        return [f"missing manifest {manifest.name}"]
    packages = load(manifest)
    if not packages:
        return ["manifest pins no packages"]
    return [e for pkg in packages for e in check_package(pkg, root)]


def render(packages: list[dict]) -> str:
    out = ["# Vendored packages, checked by check_vendored_sync.py; re-pin with", "# `check_vendored_sync.py pin NAME COMMIT` after copying from upstream.", ""]
    for pkg in packages:
        out += ["[[package]]"]
        out += [f'{k} = "{pkg[k]}"' for k in ("name", "repository", "commit", "root")]
        out += ["", "[package.files]"]
        out += [f'"{rel}" = "{digest}"' for rel, digest in sorted(pkg["files"].items())]
        out += [""]
    return "\n".join(out)


def pin(name: str, commit: str, root: Path | None = None, manifest: Path | None = None) -> list[str]:
    root = root or repo_root()
    manifest = manifest or root / MANIFEST_NAME
    if not COMMIT_RE.match(commit):
        return ["commit must be a full 40-hex SHA"]
    packages = load(manifest)
    target = next((p for p in packages if p["name"] == name), None)
    if target is None:
        return [f"no package named {name!r} in {manifest.name}"]
    base = root / target["root"]
    files = dict(target["files"])
    files.update({p.relative_to(base).as_posix(): "" for p in sources(base / name)})
    missing = [rel for rel in files if not (base / rel).exists()]
    if missing:
        return [f"{name}: cannot pin missing file {rel}" for rel in missing]
    target["files"] = {rel: sha256(base / rel) for rel in files}
    target["commit"] = commit
    manifest.write_text(render(packages), encoding="utf-8")
    return []


def main(argv: list[str]) -> int:
    if len(argv) == 4 and argv[1] == "pin":
        errors = pin(argv[2], argv[3])
        print("\n".join(errors) if errors else f"pinned {argv[2]} at {argv[3]}")
        return 1 if errors else 0
    if len(argv) != 1:
        print(__doc__)
        return 2
    errors = check()
    if errors:
        print("vendored packages are out of sync with vendored.toml:\n")
        print("\n".join(errors))
        return 1
    names = ", ".join(p["name"] for p in load(repo_root() / MANIFEST_NAME))
    print(f"OK: vendored packages match their pins ({names}).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
