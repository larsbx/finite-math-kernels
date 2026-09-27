"""Every Modular package is pinned to one nightly build.

`modular` is a metapackage over MAX and Mojo. A range on it lets a fresh solve
pick up any later nightly, so the kernels would compile under a compiler no one
chose. Each package it brings in is pinned by `==` in `pixi.toml`, and all of
them name the same nightly build date.
"""

from __future__ import annotations

import re
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = tomllib.loads((ROOT / "pixi.toml").read_text(encoding="utf-8"))
MAX_PACKAGES = ("modular", "max", "max-core", "max-serve", "max-benchmark", "mblack")
MOJO_PACKAGES = ("mojo", "mojo-compiler", "mojo-python")
EXACT = re.compile(r"^==(?P<version>\d+\.\d+\.\d+\.dev(?P<build>\d{10}))$")


def pins() -> dict[str, re.Match]:
    deps = MANIFEST["dependencies"]
    return {name: EXACT.match(deps.get(name, "")) for name in MAX_PACKAGES + MOJO_PACKAGES}


def test_every_modular_package_is_pinned_exactly() -> None:
    loose = sorted(name for name, pin in pins().items() if pin is None)
    assert loose == [], f"not pinned by == to a nightly: {loose}"


def test_one_nightly_build_across_max_and_mojo() -> None:
    found = pins()
    assert len({pin["build"] for pin in found.values()}) == 1
    assert len({found[name]["version"] for name in MAX_PACKAGES}) == 1
    assert len({found[name]["version"] for name in MOJO_PACKAGES}) == 1


def test_nightly_pins_resolve_from_the_nightly_channel() -> None:
    assert MANIFEST["workspace"]["channels"][0].rstrip("/").endswith("/max-nightly")
