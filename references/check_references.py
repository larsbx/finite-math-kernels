# check_references.py
#
# The engine behind a consumer's reference check. See the package docstring
# for what this is for and what belongs to the consumer instead.

from __future__ import annotations

import os
import re
import subprocess
from collections import Counter
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from pathlib import Path

#: Text files worth reading for references, unless a policy narrows it.
CHECKED_SUFFIXES = (".md", ".mojo", ".py", ".toml", ".yml")

#: Directories no listing should descend into when git is unavailable.
EXCLUDED_DIRS = frozenset({".git", ".pixi", "__pycache__", ".pytest_cache"})

PATH_TOKEN = re.compile(r"`([A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:md|mojo|py|toml|json|yml|lock))`")
TASK_TOKEN = re.compile(r"pixi run ([A-Za-z0-9_-]+)")
QUOTED = re.compile(r'"[^"]*"')
TASK_DEFINITION = re.compile(r"^([A-Za-z0-9_-]+) = ", re.M)


@dataclass(frozen=True)
class Policy:
    """What a consumer decides about its own references.

    `external` and `external_tasks` are the ones that carry meaning: each
    entry attests which other repository a path or a pixi task lives in. An
    entry is a claim a reader can check, which is why both maps take a
    sentence rather than a bare `True`. A consumer that mirrors an upstream
    document needs them: the document names upstream's files and upstream's
    tasks, and neither is a defect here.
    """

    external: Mapping[str, str] = field(default_factory=dict)
    external_tasks: Mapping[str, str] = field(default_factory=dict)
    skipped_prefixes: tuple[str, ...] = ()
    suffixes: tuple[str, ...] = CHECKED_SUFFIXES
    executables: frozenset[str] = frozenset({"mojo", "python"})


def tracked_files(root: Path) -> list[str]:
    """Paths git tracks, or every file under `root` outside build directories."""
    try:
        out = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True).stdout
        return sorted(p for p in out.decode("utf-8").split("\0") if p)
    except (OSError, subprocess.CalledProcessError):
        paths = []
        for base, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
            paths += [str((Path(base) / f).relative_to(root)) for f in files if not f.endswith(".pyc")]
        return sorted(paths)


def path_tokens(text: str) -> list[str]:
    return PATH_TOKEN.findall(text)


def task_tokens(text: str) -> list[str]:
    """Task names outside double-quoted literals, which are data, not references."""
    return [m.group(1) for line in text.splitlines() for m in TASK_TOKEN.finditer(QUOTED.sub("", line))]


def check(files: Mapping[str, str], tracked: Iterable[str], tasks: Iterable[str], policy: Policy) -> list[str]:
    """Every unresolved reference, as `path: kind token`."""
    tracked = set(tracked)
    basenames = Counter(Path(p).name for p in tracked)
    known_tasks = set(tasks) | policy.executables
    errors = []
    for path, text in sorted(files.items()):
        if path.startswith(policy.skipped_prefixes) or not path.endswith(policy.suffixes):
            continue
        for token in path_tokens(text):
            if token in tracked or token in policy.external or ("/" not in token and basenames[token] == 1):
                continue
            errors.append(f"{path}: path `{token}` is not a tracked file, a unique basename, or a listed external reference")
        for task in task_tokens(text):
            if task not in known_tasks and task not in policy.external_tasks:
                errors.append(f"{path}: task `pixi run {task}` is not defined in pixi.toml")
    return errors


def tree_files(root: Path, policy: Policy) -> dict[str, str]:
    return {
        path: (root / path).read_text(encoding="utf-8", errors="replace")
        for path in tracked_files(root)
        if path.endswith(policy.suffixes)
    }


def defined_tasks(root: Path) -> set[str]:
    manifest = root / "pixi.toml"
    return set(TASK_DEFINITION.findall(manifest.read_text(encoding="utf-8"))) if manifest.exists() else set()


def run(root: Path, policy: Policy) -> int:
    """Check `root` under `policy`; print the report and return an exit code."""
    files = tree_files(root, policy)
    errors = check(files, tracked_files(root), defined_tasks(root), policy)
    if errors:
        print("unresolved references:\n  " + "\n  ".join(errors))
        return 1
    print(f"OK: every path and task reference in {len(files)} files resolves.")
    return 0
