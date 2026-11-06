"""Run canonical native code and compare with independent Python integers."""
import importlib.util
import copy
import json
from pathlib import Path
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("word_oracle", ROOT / "tools/word_counter_oracle.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


def test_native_count_boundaries_and_propagated_refusal():
    # Absence of the pinned native compiler is a failure, not a skip.
    result = subprocess.run(["mojo", "run", "-I", "kernel", "tests/lean/word_counter_overflow.mojo"],
                            cwd=ROOT, text=True, capture_output=True, timeout=180)
    assert result.returncode == 0, result.stderr
    rows = oracle.check_transcript(result.stdout)
    # Admission must reject a wrapped result, blanket refusal, an unrelated
    # exception, and treating an oversized equal pair's K3 as accepted zero.
    for index, changes in [(6, dict(value=-7780085407041551616, error="")),
                           (4, dict(value=None, error=oracle.ADDITION_ERROR)),
                           (6, dict(error="allocation failed")),
                           (16, dict(value=0, error=""))]:
        corrupted = copy.deepcopy(rows)
        corrupted[index].update(changes)
        with pytest.raises(ValueError):
            oracle.check_transcript("\n".join(json.dumps(r) for r in corrupted))
