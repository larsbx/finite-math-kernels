"""Model-check the census choreography (benchmarks/frontier/FrontierCensus.tla).

Runs in the polyglot environment (`pixi run test-choreography`) with
TLA_TOOLS naming a tla2tools.jar. A missing jar or Java fails the gate; it
does not skip. Each mutant orchestrator must trip exactly the invariant that
names its fault, which shows the invariants can fail.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "benchmarks" / "frontier" / "FrontierCensus.tla"
CONFIG = SPEC.with_suffix(".cfg")


def tlc(tmp_path: Path, mutant: str) -> str:
    jar = os.environ.get("TLA_TOOLS", "")
    assert jar and Path(jar).is_file(), "set TLA_TOOLS to a tla2tools.jar"
    assert shutil.which("java"), "java is not on PATH"
    shutil.copy(SPEC, tmp_path)
    config = CONFIG.read_text(encoding="utf-8")
    assert 'Mutant = "none"' in config
    (tmp_path / "MC.cfg").write_text(config.replace('Mutant = "none"', f'Mutant = "{mutant}"'), encoding="utf-8")
    cmd = ["java", "-XX:+UseSerialGC", "-cp", jar, "tlc2.TLC", "-workers", "1", "-config", "MC.cfg", SPEC.name]
    return subprocess.run(cmd, cwd=tmp_path, capture_output=True, text=True, timeout=600, check=False).stdout


def test_the_choreography_satisfies_every_invariant_and_terminates(tmp_path):
    log = tlc(tmp_path, "none")
    assert "Model checking completed. No error has been found." in log, log


@pytest.mark.parametrize(("mutant", "invariant"), [
    ("accept_unreplayed", "NoAcceptWithoutReplay"),
    ("retry_after_verdict", "NoRetryAfterVerdict"),
    ("unbounded_retry", "BoundedRestarts"),
])
def test_each_broken_orchestrator_is_caught(tmp_path, mutant, invariant):
    log = tlc(tmp_path, mutant)
    assert f"Invariant {invariant} is violated" in log, log
