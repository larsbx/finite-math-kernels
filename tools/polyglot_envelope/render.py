#!/usr/bin/env python3
"""Render a repository's polyglot boundary envelope from the canonical template.

The facts come from ``polyglot.manifest.toml`` at the repository root:
``repository = "OWNER/REPO"`` and ``boundary_id``. Each template beside this
file is written to ``.polyglot/`` with ``{{owner}}``, ``{{repo}}`` and
``{{boundary}}`` substituted, and nothing else changed.

Every ``*.json`` file in ``.polyglot/`` is generated: one that renders no
current template (a template renamed or removed) is drift, and writing
removes it. Other files there (``README.md``, a manifest) are the
repository's own and are never read or touched.

Usage:
    render.py [--root ROOT]            write .polyglot/ from the template
    render.py [--root ROOT] --check    exit 1 if .polyglot/ is not the rendering

ROOT defaults to the nearest ancestor of this file holding the manifest.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

MANIFEST = "polyglot.manifest.toml"
OUT = ".polyglot"
HERE = Path(__file__).resolve().parent
FACTS = ("owner", "repo", "boundary")
#: The generated files: every template is a ``*.json``, and so is its rendering.
GENERATED = "*.json"
PLACEHOLDER = re.compile(r"\{\{(\w+)\}\}")
# A fact lands inside a JSON string and a URN, so it is a plain lowercase slug.
SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def templates() -> dict[str, str]:
    """Published file name -> template text."""
    return {p.name: p.read_text(encoding="utf-8") for p in sorted(HERE.glob(GENERATED))}


def reserved() -> frozenset[str]:
    """Boundaries the vectors use as someone else's: a repository may not claim one."""
    vectors = json.loads(templates()["conformance-v1.json"])
    return frozenset(case["value"].get("boundary") for case in vectors["rejected"]) - {"{{boundary}}"}


def validated(facts: dict) -> dict[str, str]:
    if set(facts) != set(FACTS):
        raise ValueError(f"facts must be exactly {list(FACTS)}, got {sorted(facts)}")
    bad = [k for k in FACTS if not (isinstance(facts[k], str) and SLUG.match(facts[k]))]
    if bad:
        raise ValueError(f"facts are not lowercase slugs: {bad}")
    if facts["boundary"] in reserved():
        raise ValueError(f"boundary {facts['boundary']!r} is reserved by the rejected vectors")
    return dict(facts)


def render(facts: dict) -> dict[str, str]:
    """Published file name -> rendered text. Refuses unsafe facts and unknown placeholders."""
    facts = validated(facts)

    def fact(match: re.Match[str]) -> str:
        if match[1] not in facts:
            raise ValueError(f"template names unknown placeholder {match[0]}")
        return facts[match[1]]

    rendered = {name: PLACEHOLDER.sub(fact, text) for name, text in templates().items()}
    for text in rendered.values():
        json.loads(text)
    return rendered


def facts(manifest: dict) -> dict[str, str]:
    """The three facts a polyglot manifest declares."""
    owner_repo = manifest.get("repository", "").split("/")
    if len(owner_repo) != 2 or "boundary_id" not in manifest:
        raise ValueError(f"{MANIFEST} needs repository = \"OWNER/REPO\" and boundary_id")
    return {"owner": owner_repo[0], "repo": owner_repo[1], "boundary": manifest["boundary_id"]}


def rendering(root: Path) -> dict[str, str]:
    manifest = tomllib.loads((root / MANIFEST).read_text(encoding="utf-8"))
    return render(facts(manifest))


def stale(root: Path, rendered: dict[str, str]) -> list[Path]:
    """Generated files in ``.polyglot/`` that render no current template."""
    return sorted(p for p in (root / OUT).glob(GENERATED) if p.name not in rendered)


def drift(root: Path) -> list[str]:
    """Every published file that is missing, is not its rendering, or renders no template."""
    rendered = rendering(root)
    out = []
    for name, text in sorted(rendered.items()):
        path = root / OUT / name
        if not path.is_file():
            out.append(f"{OUT}/{name} missing")
        elif path.read_text(encoding="utf-8") != text:
            out.append(f"{OUT}/{name} differs from its rendering")
    out += [f"{OUT}/{path.name} is not the rendering of any template" for path in stale(root, rendered)]
    return out


def write(root: Path) -> None:
    rendered = rendering(root)
    (root / OUT).mkdir(exist_ok=True)
    for path in stale(root, rendered):
        path.unlink()
    for name, text in rendered.items():
        (root / OUT / name).write_text(text, encoding="utf-8")


def repo_root() -> Path:
    """The nearest ancestor holding the manifest: the package is vendored at any depth."""
    return next((p for p in HERE.parents if (p / MANIFEST).is_file()), HERE.parents[1])


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=None)
    ap.add_argument("--check", action="store_true", help="verify, do not write")
    args = ap.parse_args(argv)
    root = args.root or repo_root()
    try:
        if not args.check:
            write(root)
            print(f"rendered {OUT}/ from the polyglot envelope template")
            return 0
        problems = drift(root)
    except (OSError, ValueError) as error:
        print(f"polyglot envelope: {error}", file=sys.stderr)
        return 1
    if problems:
        print("polyglot envelope has drifted from its template:", *problems,
              "re-render with: render.py (vendored polyglot_envelope)", sep="\n  ", file=sys.stderr)
        return 1
    print(f"OK: {OUT}/ is the rendering of the polyglot envelope template")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
