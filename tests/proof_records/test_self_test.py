"""The boot gate refuses a wrong codec, and can be made to refuse.

Round-three item R10, adopted from `larsbx/coop_substrate`. A gate nothing can
make fail proves nothing, so every check below corrupts an expectation and
asserts the raise, the way the substrate's own suite drives its application
env.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from proof_records import SelfTestError, self_test  # noqa: E402
from proof_records import known_answers as known  # noqa: E402
from proof_records.records import canonical_bytes, identity, preimage_bytes  # noqa: E402
import make_vectors as mv  # noqa: E402


@pytest.fixture(autouse=True)
def clean_overrides():
    self_test.OVERRIDES.clear()
    yield
    self_test.OVERRIDES.clear()


# --- it passes, and it is not vacuous ---------------------------------------------


def test_the_committed_codec_passes_its_own_gate():
    assert self_test.problems() == ()
    assert self_test.verify() is None


@pytest.mark.parametrize("name", ["PREIMAGE_HEX", "IDENTITY", "DIGEST"])
def test_each_known_answer_is_load_bearing(name):
    """Corrupt one expectation at a time: each must be the only failure."""
    self_test.OVERRIDES[name] = "00" * 32
    found = self_test.problems()
    assert len(found) == 1, found
    with pytest.raises(SelfTestError, match="refuses to load"):
        self_test.verify()


def test_the_digest_check_calls_the_exported_function(monkeypatch):
    """`digest` is checked by calling it, not by recomputing SHA-256 over
    `canonical_bytes`. A `digest` that alone had moved would otherwise pass the
    gate and hand a consumer the wrong value."""
    monkeypatch.setattr(self_test, "digest", lambda record: "sha256:" + "0" * 64)
    found = self_test.problems()
    assert found == ("digest no longer produces the committed digest",)


def test_a_broken_hash_is_named_as_a_broken_hash(monkeypatch):
    """The primitive is checked first, and it short-circuits: a hash that is
    not sha256 would fail every codec answer too, and reporting three
    consequences hides the one cause."""
    monkeypatch.setattr(self_test, "FIPS_KNOWN_ANSWERS", ((b"", "00" * 32),))
    found = self_test.problems()
    assert len(found) == 1 and "FIPS 180-4" in found[0]


def test_the_message_says_what_to_do():
    self_test.OVERRIDES["IDENTITY"] = "sha256:" + "0" * 64
    with pytest.raises(SelfTestError) as caught:
        self_test.verify()
    message = str(caught.value)
    assert "tools/make_vectors.py" in message and "docs/proof-records-specification.md" in message


# --- the gate is at import, not at the test suite ----------------------------------


def test_importing_the_package_runs_the_gate():
    assert "verify()" in (ROOT / "proof_records" / "__init__.py").read_text(encoding="utf-8")


def test_a_wrong_codec_makes_the_package_unimportable(tmp_path):
    """The point of the gate: a consumer that vendors this package and never
    runs the suite still cannot use a codec that has moved. The subprocess
    patches the committed constant, so the failure is a real import failure."""
    script = (
        "import sys; sys.path.insert(0, %r)\n"
        "import proof_records.known_answers as k\n"
        "k.IDENTITY = 'sha256:' + '0' * 64\n"
        "import importlib, proof_records\n"
        "importlib.reload(proof_records)\n" % str(ROOT)
    )
    done = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True)
    assert done.returncode != 0
    assert "refuses to load" in done.stderr and "identity no longer" in done.stderr


# --- the known answers are generated, not asserted by hand -------------------------


def test_the_known_answers_are_the_generated_ones():
    assert (ROOT / "proof_records" / "known_answers.py").read_text(encoding="utf-8") == mv.render_known_answers()


def test_the_pinned_record_is_chosen_by_a_rule():
    """The lexicographically first entry stored under its own identifier, so it
    is never one of the ledger's deliberately malformed specimens."""
    key = mv.pinned_key()
    assert key == mv.LEDGER[key].id == known.RECORD_ID
    assert key == min(k for k, r in mv.LEDGER.items() if k == r.id)


def test_the_pinned_answers_are_what_the_codec_produces():
    record = self_test.pinned()
    assert preimage_bytes(record).hex() == known.PREIMAGE_HEX
    assert identity(record) == known.IDENTITY
    assert hashlib.sha256(canonical_bytes(record)).hexdigest() == known.DIGEST
    assert record == mv.LEDGER[known.RECORD_ID]


def test_the_generator_check_covers_both_outputs():
    done = subprocess.run([sys.executable, str(ROOT / "tools" / "make_vectors.py"), "--check"], capture_output=True, text=True)
    assert done.returncode == 0, done.stdout
    assert "fixtures/vectors.json is up to date" in done.stdout
    assert "proof_records/known_answers.py is up to date" in done.stdout


# --- the generator can still run when the answers it replaces are stale ------------


def _transplant(tmp_path):
    """A standalone copy of the package and its generator, so a corrupted
    `known_answers.py` can be repaired without touching the checkout."""
    shutil.copytree(ROOT / "proof_records", tmp_path / "proof_records", ignore=shutil.ignore_patterns("__pycache__"))
    (tmp_path / "tools").mkdir()
    shutil.copy(ROOT / "tools" / "make_vectors.py", tmp_path / "tools" / "make_vectors.py")
    known_py = tmp_path / "proof_records" / "known_answers.py"
    known_py.write_text(known_py.read_text(encoding="utf-8").replace(known.IDENTITY, "sha256:" + "0" * 64), encoding="utf-8")
    return known_py


def test_the_door_is_named_the_same_on_both_sides():
    """The generator spells the variable out rather than importing it, since
    importing it would run the gate it opens. Drift between the two would
    silently restore the deadlock."""
    assert mv.REGENERATING == self_test.REGENERATING == "PROOF_RECORDS_REGENERATING"


def test_stale_answers_stop_a_consumer(tmp_path):
    """The premise of the test below: with the answers corrupted, an ordinary
    import of the copy fails."""
    _transplant(tmp_path)
    done = subprocess.run([sys.executable, "-c", "import proof_records"], capture_output=True, text=True, cwd=tmp_path)
    assert done.returncode != 0 and "refuses to load" in done.stderr


def test_stale_answers_do_not_stop_the_generator(tmp_path):
    """An intended codec change makes the committed answers wrong, and the tool
    that rewrites them must still run. Without the door the import gate would
    fail first and the repair would be unreachable."""
    known_py = _transplant(tmp_path)
    done = subprocess.run([sys.executable, str(tmp_path / "tools" / "make_vectors.py")], capture_output=True, text=True, cwd=tmp_path)
    assert done.returncode == 0, done.stderr
    assert known_py.read_text(encoding="utf-8") == (ROOT / "proof_records" / "known_answers.py").read_text(encoding="utf-8")


def test_skipping_the_gate_is_announced(tmp_path):
    """A check that can be turned off silently is not a check."""
    done = subprocess.run([sys.executable, "-c", "import proof_records"], capture_output=True, text=True,
                          cwd=tmp_path, env={**os.environ, self_test.REGENERATING: "1", "PYTHONPATH": str(ROOT)})
    assert done.returncode == 0, done.stderr
    assert "the known-answer gate did not run" in done.stderr
