"""OFFLINE policy/failure tests: synthetic packets and profiles are NOT GPU evidence."""
from collections import Counter
import copy
from hashlib import sha256
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
from types import SimpleNamespace

import pytest

from experiments.frontier.lean_max import gpu_bridge as gpu
from experiments.frontier.lean_max import hardware_acceptance as gate
from experiments.frontier.lean_max import reference as ref
from experiments.frontier.lean_max import trace_codec as codec
from experiments.frontier.lean_max.corpus import problems, documents

UUID = "GPU-01234567-89ab-cdef-0123-456789abcdef"


@pytest.fixture
def synthetic_comparison(tmp_path):
    """Fabricated checker records exercise the validator only; never call accept."""
    directory = tmp_path / "synthetic-not-hardware"
    directory.mkdir()
    (directory / "corpus.json").write_text(json.dumps(documents(), sort_keys=True, separators=(",", ":")))
    rows = []
    for repeat in range(2):
        for case, p in enumerate(problems()):
            result = ref.construct(p, max_records=64, max_rounds=32)
            derived = result["status"] == "derived"
            for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind"):
                row = {"lane": lane, "case": case, "repeat": repeat, "result": copy.deepcopy(result),
                       "status": "proof_accepted" if derived else "not_derived", "proof_accepted": derived,
                       "trace_sha256": None, "end_to_end_ns": 100, "telemetry": [], "device_launches": 0,
                       "gpu_assisted": False, "verification": {"status": "accepted", "code": 0}}
                if lane == "lean_grind":
                    row["status"] = "lean_baseline_accepted" if derived else "lean_failed"
                    row["verification"] = {"status": "accepted" if derived else "lean_failed", "code": 0 if derived else 1}
                elif derived:
                    wire = codec.encode_trace(p, result)
                    row["trace_sha256"] = sha256(wire).hexdigest()
                    name = f"{lane}-{case}-{repeat}"
                    (directory / (name + ".trace")).write_bytes(wire)
                    (directory / (name + ".lean")).write_text(ref.lean_source(p, result))
                if lane == "mojo_gpu" and gpu.construct(p, Path("unused"), enabled=True, max_rounds=0)["status"] != "derived":
                    row.update(device_launches=1, gpu_assisted=True,
                               telemetry=[{"candidate_parity": True, "launches": 1, "runner_pid": 100 + repeat * 34 + case,
                                           "input_sha256": "a" * 64, "output_sha256": "b" * 64}])
                rows.append(row)
    return {"schema": "lean-max-comparison-v1", "corpus_sha256": gate.CORPUS_SHA256,
            "budgets": {"max_records": 64, "max_rounds": 32}, "rows": rows}, directory


def test_offline_policy_counts_controls_separately(synthetic_comparison):
    report, directory = synthetic_comparison
    coverage, launches = gate.validate_report(report, directory, 2)
    assert coverage["accepted_constructions"] == 28 * 3 * 2
    assert coverage["expected_nonderived_controls"] == 6 * 3 * 2
    assert coverage["gpu_assisted_accepted_constructions"] > 0 and launches
    assert not list(directory.glob("*acceptance*.json"))


@pytest.mark.parametrize("mutation", ["missing", "duplicate", "corpus", "budget", "runner_error", "unsuccessful",
    "false_accept", "lean_unavailable", "lean_exit", "cpu_divergence", "no_launch", "no_parity", "no_pid",
    "no_binding", "no_timing", "no_baseline", "control_as_proof", "bad_trace", "bad_source", "missing_trace"])
def test_offline_malformed_evidence_cannot_pass(mutation, synthetic_comparison):
    report, directory = synthetic_comparison
    row = next(r for r in report["rows"] if r["lane"] == "mojo_gpu" and r["case"] == 0)
    if mutation == "missing": report["rows"].pop()
    elif mutation == "duplicate": report["rows"][-1] = report["rows"][0]
    elif mutation == "corpus": report["corpus_sha256"] = "0" * 64
    elif mutation == "budget": report["budgets"]["max_rounds"] = 0
    elif mutation == "runner_error": row["status"] = "construction_error"
    elif mutation == "unsuccessful": row["result"] = {"status": "not_derived", "steps": []}
    elif mutation == "false_accept": row["proof_accepted"] = False
    elif mutation == "lean_unavailable": row["verification"]["status"] = "lean_unavailable"
    elif mutation == "lean_exit": row["verification"]["code"] = 1
    elif mutation == "cpu_divergence": row["result"]["steps"][-1]["lhs"] = 999
    elif mutation == "no_launch": row.update(telemetry=[], device_launches=0, gpu_assisted=False)
    elif mutation == "no_parity": row["telemetry"][0]["candidate_parity"] = False
    elif mutation == "no_pid": row["telemetry"][0]["runner_pid"] = 0
    elif mutation == "no_binding": row["telemetry"][0]["output_sha256"] = ""
    elif mutation == "no_timing": row["end_to_end_ns"] = None
    elif mutation == "no_baseline":
        next(r for r in report["rows"] if r["lane"] == "lean_grind")["status"] = "lean_unavailable"
    elif mutation == "control_as_proof":
        next(r for r in report["rows"] if r["lane"] == "mojo_gpu" and r["case"] == 3)["proof_accepted"] = True
    elif mutation == "bad_trace": (directory / "mojo_gpu-0-0.trace").write_bytes(b"LMTRACE\x01")
    elif mutation == "missing_trace": (directory / "mojo_gpu-0-0.trace").unlink()
    elif mutation == "bad_source": (directory / "mojo_gpu-0-0.lean").write_text("example : True := True.intro\n")
    with pytest.raises((gate.Rejected, OSError, ref.InvalidProblem)):
        gate.validate_report(report, directory, 2)


def synthetic_profile(path, *, name="candidates_kernel", pid=123, uuid=UUID, end=200, copies=1):
    with sqlite3.connect(path) as db:
        db.executescript("""CREATE TABLE StringIds (id INTEGER, value TEXT);
            CREATE TABLE TARGET_INFO_CUDA_DEVICE (pid INTEGER, cudaId INTEGER, uuid TEXT);
            CREATE TABLE CUPTI_ACTIVITY_KIND_KERNEL
                (globalPid INTEGER, deviceId INTEGER, start INTEGER, end INTEGER, demangledName INTEGER);""")
        db.execute("INSERT INTO StringIds VALUES (1, ?)", (name,))
        db.execute("INSERT INTO TARGET_INFO_CUDA_DEVICE VALUES (?, 0, ?)", (pid, uuid))
        for _ in range(copies):
            db.execute("INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES (?, 0, 100, ?, 1)", (pid << 24, end))


def test_synthetic_profiler_pid_and_uuid_policy(tmp_path):
    path = tmp_path / "synthetic.sqlite"
    synthetic_profile(path)
    assert gate.validate_profile(path, Counter({123: 1}), UUID)["launches"] == 1


@pytest.mark.parametrize("change", [{"copies": 0}, {"copies": 2}, {"pid": 124}, {"name": "cpu_stub"},
    {"end": 100}, {"uuid": "GPU-ffffffff-ffff-ffff-ffff-ffffffffffff"}, {"uuid": None}])
def test_synthetic_profiler_missing_or_inconsistent_launches_fail(tmp_path, change):
    path = tmp_path / "synthetic.sqlite"
    synthetic_profile(path, **change)
    with pytest.raises(gate.Rejected):
        gate.validate_profile(path, Counter({123: 1}), UUID)


def test_missing_profiler_schema_fails_closed(tmp_path):
    path = tmp_path / "empty.sqlite"
    sqlite3.connect(path).close()
    with pytest.raises(sqlite3.Error):
        gate.validate_profile(path, Counter({123: 1}), UUID)


@pytest.mark.parametrize("body", ["", "<testcase><skipped/></testcase>", "<testcase><error/></testcase>",
                                 "<testcase><failure/></testcase>"])
def test_empty_or_skipped_hardware_suite_not_acceptance(tmp_path, body):
    path = tmp_path / "tests.xml"
    path.write_text("<testsuites><testsuite>" + body * 10 + "</testsuite></testsuites>")
    with pytest.raises(gate.Rejected):
        gate.validate_junit(path)


def test_ordinary_skip_and_explicit_hardware_refusal_are_distinct(tmp_path):
    env = dict(os.environ)
    env.pop("LEAN_MAX_GPU_RUNNER", None)
    for strict, expected in ((False, 0), (True, 1)):
        env["LEAN_MAX_GPU_REQUIRED"] = "1" if strict else "0"
        proc = subprocess.run([sys.executable, "-m", "pytest", "-q", "tests/frontier/test_lean_max_gpu_hardware.py"],
                              cwd=gate.ROOT, env=env, capture_output=True, text=True, timeout=30)
        assert proc.returncode == expected, proc.stdout + proc.stderr
        assert ("skipped" if not strict else "hardware acceptance requires") in proc.stdout


def test_simulated_process_failure_and_timeout_have_archived_logs(tmp_path):
    commands = []
    with pytest.raises(gate.Rejected, match="exit 3"):
        gate.run_command([sys.executable, "-c", "print('simulated compiler failure'); raise SystemExit(3)"],
                         tmp_path, "compiler-failure", commands)
    assert "simulated compiler failure" in (tmp_path / "compiler-failure.stdout").read_text()
    with pytest.raises(subprocess.TimeoutExpired):
        gate.run_command([sys.executable, "-c", "import time; time.sleep(5)"],
                         tmp_path, "timeout", commands, timeout=0.01)
    assert commands[-1]["status"] == "interrupted_or_timeout"


@pytest.mark.parametrize("kind", ["missing_runner", "missing_binary", "compiler_failure", "accelerator_unavailable"])
def test_offline_failures_write_only_rejected_receipts(tmp_path, monkeypatch, kind):
    out = tmp_path / kind
    monkeypatch.setattr(gate, "repository_snapshot", lambda expected: {"revision": expected})
    args = SimpleNamespace(out=out, expected_revision="a" * 40, gpu_uuid=UUID, repeats=2,
                           gpu_runner=None if kind == "missing_runner" else out / "gpu",
                           mojo="mojo", lean="lean", nsys="nsys")
    if kind == "missing_binary":
        monkeypatch.setattr(gate.shutil, "which", lambda name: None)
    elif kind in {"compiler_failure", "accelerator_unavailable"}:
        monkeypatch.setattr(gate, "executable", lambda name: Path(sys.executable).resolve())
        def simulated(argv, directory, label, commands, **kwargs):
            if label == "mojo-version": return gate.MOJO_VERSION
            if label == "lean-version": return "Lean (version 4.35.0)"
            if label == "pixi-packages":
                return json.dumps([{"name": name, "version": version} for name, version in
                                  (("mojo", gate.MOJO_VERSION), ("modular", gate.MODULAR_VERSION), ("max", gate.MODULAR_VERSION))])
            if label == "gpu-inventory": return f"test GPU,{UUID},test driver,1024\n"
            if label == "lean-negative-control":
                (directory / (label + ".stderr")).write_text("")
                return "error: simulated checker diagnostic"
            if label in {"cpu-build", "gpu-build"}:
                if kind == "compiler_failure" and label == "gpu-build":
                    raise gate.Rejected("simulated compiler failure")
                target = Path(argv[-1]); target.write_bytes(b"offline test only"); target.chmod(0o755)
            if label == "hardware-tests": raise gate.Rejected("simulated accelerator unavailable")
            return "offline test only"
        monkeypatch.setattr(gate, "run_command", simulated)
    result = gate.accept(args)
    assert result["accepted"] is False and result["status"] == "rejected"
    assert json.loads((out / "hardware-acceptance.json").read_text())["accepted"] is False
    assert result["error"]
    with pytest.raises(FileExistsError):
        gate.accept(args)  # A stale receipt cannot be reused by a second invocation.


def test_revision_guard_rejects_wrong_revision_and_dirty_tree(tmp_path, monkeypatch):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    file = tmp_path / "source.py"
    file.write_text("# reviewed\n")
    subprocess.run(["git", "-C", str(tmp_path), "add", "source.py"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "-c", "user.name=Offline Test", "-c", "user.email=test@example.invalid",
                    "commit", "-qm", "offline fixture"], check=True)
    revision = subprocess.check_output(["git", "-C", str(tmp_path), "rev-parse", "HEAD"]).decode().strip()
    monkeypatch.setattr(gate, "ROOT", tmp_path)
    snapshot = gate.repository_snapshot(revision)
    assert snapshot["source_sha256"]["source.py"] == gate.digest(file)
    with pytest.raises(gate.Rejected, match="expected revision"):
        gate.repository_snapshot("0" * 40)
    file.write_text("# unreviewed\n")
    with pytest.raises(gate.Rejected, match="dirty"):
        gate.repository_snapshot(revision)
