#!/usr/bin/env python3
"""Pin and verify the consolidation provenance of every tracked file.

``audit/provenance.json`` records, per source repository, the branch, the
commit, and the git tree id of every top-level directory at that commit, and,
per tracked file in this repository except the manifest itself:

  relation      copy | modified | facade | authored | generated
  blob          the file's git blob id (SHA-1 over ``blob <size>\\0`` + bytes)
  source        for copy and modified: the pinned source repository
  source_path   for copy and modified: the path in that repository
  source_blob   for copy and modified: the blob id at the pinned commit
  generator     for generated: the tool that writes the file

``copy`` means byte-for-byte identical to the pinned source blob (whatever the
path, so relocations are copies); ``modified`` means imported and then
changed here; ``facade`` is a stable re-export module written for the
monorepo; ``authored`` is any other file written here; ``generated`` is
written by a tool from other tracked inputs.

Usage:
    provenance.py --check    exit 1 on any unexplained divergence
    provenance.py --update   refresh blobs and relations, add new files as
                             authored, drop deleted files; never touches
                             source pins

The verifier needs no network and no source checkout: source pins are data,
and every relation is decided from the manifest and the working tree.
"""

from __future__ import annotations

import hashlib
import json
import sys
from collections.abc import Mapping
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from references.check_references import tracked_files as listing  # noqa: E402
MANIFEST = ROOT / "audit" / "provenance.json"
MANIFEST_PATH = "audit/provenance.json"  # the one tracked file the manifest cannot describe: itself
FORMAT = "finite-math-kernels provenance 1"
RELATIONS = frozenset({"copy", "modified", "facade", "authored", "generated"})
IMPORTED = frozenset({"copy", "modified"})


def blob_id(data: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def tracked_files(root: Path = ROOT) -> list[str]:
    """Paths git tracks, or every file under ``root`` outside build directories.

    One listing, in `references/check_references.py`, so the file set this
    manifest describes and the file set the reference check reads cannot
    diverge."""
    return listing(root)


def current_blobs(root: Path = ROOT) -> dict[str, str]:
    return {path: blob_id((root / path).read_bytes()) for path in tracked_files(root) if path != MANIFEST_PATH}


def load(path: Path = MANIFEST) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def render(manifest: dict) -> str:
    return json.dumps(manifest, indent=2, sort_keys=True) + "\n"


def check(manifest: dict, blobs: Mapping[str, str]) -> list[str]:
    """Every divergence between the manifest and the current blobs."""
    errors = []
    if manifest.get("format") != FORMAT:
        errors.append(f"unknown manifest format {manifest.get('format')!r}")
    files = manifest.get("files", {})
    sources = manifest.get("sources", {})
    if MANIFEST_PATH in files:
        errors.append(f"{MANIFEST_PATH}: the manifest must not describe itself")
    for path in sorted(set(blobs) - set(files)):
        errors.append(f"{path}: not in the manifest (run tools/provenance.py --update and review the relation)")
    for path, entry in sorted(files.items()):
        if path not in blobs:
            errors.append(f"{path}: listed but missing from the tree")
            continue
        relation = entry.get("relation")
        if relation not in RELATIONS:
            errors.append(f"{path}: unknown relation {relation!r}")
            continue
        if entry.get("blob") != blobs[path]:
            errors.append(f"{path}: blob {blobs[path]} differs from the manifest ({entry.get('blob')})")
        if relation in IMPORTED:
            missing = [k for k in ("source", "source_path", "source_blob") if not entry.get(k)]
            if missing:
                errors.append(f"{path}: {relation} entry lacks {', '.join(missing)}")
                continue
            if entry["source"] not in sources:
                errors.append(f"{path}: source {entry['source']!r} is not pinned")
            if relation == "copy" and entry["source_blob"] != blobs[path]:
                errors.append(f"{path}: marked copy but differs from source blob {entry['source_blob']}")
            if relation == "modified" and entry["source_blob"] == blobs[path]:
                errors.append(f"{path}: marked modified but is identical to its source blob")
        elif any(entry.get(k) for k in ("source", "source_path", "source_blob")):
            errors.append(f"{path}: {relation} entry carries source fields")
        if relation == "generated" and not entry.get("generator"):
            errors.append(f"{path}: generated entry lacks a generator")
    for name, source in sorted(sources.items()):
        for key in ("repository", "branch", "commit", "subtrees"):
            if not source.get(key):
                errors.append(f"source {name}: lacks {key}")
        if len(str(source.get("commit", ""))) != 40:
            errors.append(f"source {name}: commit is not a full SHA-1")
    return errors


def update(manifest: dict, blobs: Mapping[str, str]) -> dict:
    """The manifest with blobs refreshed, copy/modified re-decided against the
    pinned source blobs, new files added as authored, and deleted files dropped."""
    files = {}
    for path, blob in sorted(blobs.items()):
        entry = dict(manifest.get("files", {}).get(path) or {"relation": "authored"})
        entry["blob"] = blob
        if entry["relation"] in IMPORTED:
            entry["relation"] = "copy" if entry.get("source_blob") == blob else "modified"
        files[path] = entry
    return {"format": FORMAT, "sources": manifest.get("sources", {}), "files": files}


def main(argv: list[str]) -> int:
    manifest = load() if MANIFEST.exists() else {"format": FORMAT, "sources": {}, "files": {}}
    blobs = current_blobs()
    if argv[1:] == ["--update"]:
        MANIFEST.write_text(render(update(manifest, blobs)), encoding="utf-8")
        print(f"wrote {MANIFEST.relative_to(ROOT)}")
        return 0
    if argv[1:] != ["--check"]:
        print(__doc__)
        return 2
    errors = check(manifest, blobs)
    if errors:
        print("provenance divergence:\n  " + "\n  ".join(errors))
        return 1
    print(f"OK: {len(blobs)} tracked files match audit/provenance.json.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
