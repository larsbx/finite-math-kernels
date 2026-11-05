"""Acceptance accounting must not turn missing/mismatched Lean into success."""
from hashlib import sha256
import json

from experiments.frontier.lean_max import benchmark as bench
from experiments.frontier.lean_max.corpus import documents, problems


def test_corpus_is_fixed_and_contains_nonderivable_control():
    raw = json.dumps(documents(), sort_keys=True, separators=(",", ":")).encode()
    assert len(problems()) == 34
    assert sha256(raw).hexdigest() == "c21b0cb4215c490a825d7972db4efef3a176b8ecffff0ee7d84c535b0f891aa3"
    assert bench.ref.construct(problems()[3])["status"] == "not_derived"


def test_grind_uses_original_goal_and_no_constructed_proof():
    source = bench.grind_source(problems()[0])
    assert ": (f a) = (f c) := by\n  grind\n" in source
    assert "maxHeartbeats 100000" in source
    assert "Eq.trans" not in source and "have p" not in source


def test_missing_lean_and_version_mismatch_never_accept(tmp_path):
    p = problems()[0]
    source = bench.ref.lean_source(p, bench.ref.construct(p))
    assert bench.lean_check(source, None, {"status": "unavailable"}, tmp_path, "missing")["status"] == "lean_unavailable"
    assert bench.lean_check(source, "/does/not/exist", {"status": "ok", "stdout": "Lean (version 4.34.0)"}, tmp_path, "wrong")["status"] == "lean_version_mismatch"
    assert bench.lean_check(source, None, {"status": "negative_control_failed"}, tmp_path, "negative")["status"] == "lean_negative_control_failed"
