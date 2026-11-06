"""OFFLINE fault injection only: no Mojo compilation, Lean or GPU evidence.

Synthetic runner text, comparison rows and profiler SQLite fixtures test refusal
logic; none is a hardware acceptance run or a contributed mathematical result.
"""
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

import pytest

from experiments.frontier.lean_max import hardware_acceptance as gate

HARDWARE = {"name": "offline-test-only", "uuid": "GPU-12345678-abcd", "driver": "test", "memory_mib": 1}


def args(directory):
    return SimpleNamespace(out=directory, gpu_runner=directory / "gpu", cpu_runner=directory / "cpu",
                           expected_revision="a" * 40, mojo=sys.executable, lean=sys.executable,
                           nsys=sys.executable, smi=sys.executable)


def fixture_packet(problem, steps):
    rows = gate.gpu.offline_slots(problem, steps)
    size = 4 * (3 * len(problem.terms) + 2 * len(steps))
    count = len(rows)
    metrics = [1] * 5 + [size + max(4, count * 24), size, count * 24, int(count > 0)]
    return (f"LMGPU1 {count}\nDEVICE {HARDWARE['name']}\nMETRICS " + " ".join(map(str, metrics)) + "\n"
            + "".join(" ".join(map(str, row)) + "\n" for row in rows)).encode()


def sqlite_fixture(path, *, count=1, kernel="candidates_kernel", duration=1, uuid=None):
    with gate.sqlite3.connect(path) as db:
        db.executescript("""
          CREATE TABLE StringIds(id INTEGER, value TEXT);
          CREATE TABLE CUPTI_ACTIVITY_KIND_KERNEL(start INTEGER, end INTEGER, deviceId INTEGER,
               correlationId INTEGER, demangledName INTEGER);
          CREATE TABLE TARGET_INFO_GPU(id INTEGER, name TEXT, uuid TEXT);
        """)
        db.execute("INSERT INTO StringIds VALUES(1, ?)", (kernel,))
        db.execute("INSERT INTO TARGET_INFO_GPU VALUES(0, ?, ?)", (HARDWARE["name"], uuid or HARDWARE["uuid"]))
        for i in range(count):
            db.execute("INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES(?, ?, 0, ?, 1)", (i, i + duration, i + 1))


def probe_fixture(directory, doc):
    p = gate.ref.Problem.parse(doc)
    seeds = [gate.ref.Step(a, b, "hyp", data=i) for i, (a, b) in enumerate(p.premises)]
    seeds += [gate.ref.Step(i, i, "refl") for i in range(len(p.terms))]
    gate.write_json(directory / "call-0.json", [s.json() for s in seeds])
    packet = fixture_packet(p, seeds)
    (directory / "call-0.stdout").write_bytes(packet)
    _, metrics = gate.gpu.parse_output(p, seeds, packet)
    gate.write_json(directory / "result.json", {"result": gate.ref.construct(p), "calls": ["call-0"], "telemetry": [metrics]})
    sqlite_fixture(directory / "profile.sqlite")


def test_missing_runner_writes_rejected_receipt_and_no_skip(tmp_path):
    config = args(tmp_path / "run")
    config.gpu_runner = None
    receipt = gate.run(config)
    assert receipt["accepted"] is False and receipt["status"] == "rejected"
    assert "explicit --gpu-runner" in receipt["error"]
    assert json.loads((config.out / "hardware-receipt.json").read_text())["accepted"] is False
    with pytest.raises(FileExistsError):
        gate.run(config)  # cannot reuse a directory carrying an older receipt


def test_cli_without_runner_exits_nonzero(tmp_path):
    proc = subprocess.run([sys.executable, "-m", gate.MODULE, "--expected-revision", "a" * 40,
                           "--out", str(tmp_path / "cli")], capture_output=True, cwd=gate.ROOT)
    assert proc.returncode == 1
    assert json.loads((tmp_path / "cli/hardware-receipt.json").read_text())["status"] == "rejected"


def test_output_inside_repository_rejected():
    with pytest.raises(gate.Rejected, match="outside"):
        gate.run(args(gate.ROOT / "unsafe-output"))


@pytest.fixture
def repo(tmp_path):
    path = tmp_path / "repo"
    path.mkdir()
    def git(*argv):
        return subprocess.check_output(["git", *argv], cwd=path).decode().strip()
    git("init", "-q")
    git("config", "user.email", "offline@example.invalid")
    git("config", "user.name", "Offline test")
    (path / "source.py").write_text("pass\n")
    git("add", ".")
    git("commit", "-qm", "fixture")
    return path, git


def test_exact_revision_dirty_untracked_and_hidden_changes(repo):
    path, git = repo
    head = git("rev-parse", "HEAD")
    good = gate.snapshot(head, path)
    assert good["source_sha256"]["source.py"] == sha256(b"pass\n").hexdigest()
    with pytest.raises(gate.Rejected, match="revision mismatch"):
        gate.snapshot("0" * 40, path)
    with pytest.raises(gate.Rejected, match="full expected"):
        gate.snapshot(head[:8], path)
    (path / "extra").write_text("untracked")
    with pytest.raises(gate.Rejected, match="clean checkout"):
        gate.snapshot(head, path)
    (path / "extra").unlink()
    git("update-index", "--assume-unchanged", "source.py")
    (path / "source.py").write_text("changed\n")
    with pytest.raises(gate.Rejected, match="differs from HEAD"):
        gate.snapshot(head, path)


@pytest.mark.parametrize("failure", ["compiler", "no_binary", "no_gpu", "missing_tool", "wrong_lean", "wrong_mojo",
                                     "wrong_max", "positive", "negative", "no_profiler"])
def test_preflight_faults_cannot_accept(tmp_path, monkeypatch, failure):
    config = args(tmp_path)
    monkeypatch.setattr(gate, "snapshot", lambda *a: {"revision": "a" * 40, "source_sha256": {}})
    monkeypatch.setattr(gate, "inventory", lambda *a: HARDWARE)
    def packages():
        if failure == "wrong_max": raise gate.Rejected("Modular/MAX version mismatch")
        return {}
    monkeypatch.setattr(gate, "package_versions", packages)
    def fake(argv, timeout=60):
        text = "Lean (version 4.35.0) Mojo " + gate.MOJO_VERSION
        code = 0
        if "--version" in argv:
            if failure == "missing_tool":
                raise FileNotFoundError("simulated missing binary")
            if failure == "wrong_lean": text = text.replace("4.35.0", "4.34.0")
            if failure == "wrong_mojo": text = text.replace(gate.MOJO_VERSION, "old")
            if failure == "no_profiler" and len(calls) == 2: code = 1
        if "--print-prefix" in argv:
            prefix = tmp_path / "toolchain"
            (prefix / "bin").mkdir(parents=True, exist_ok=True)
            (prefix / "bin/lean").write_text("offline kernel fixture")
            text = str(prefix)
        if "build" in argv:
            if failure == "compiler": code = 1
            elif failure != "no_binary":
                Path(argv[-1]).write_text("offline fake executable")
                Path(argv[-1]).chmod(0o755)
        if str(argv[-1]).endswith("Negative.lean"): code = 0 if failure == "negative" else 1
        if str(argv[-1]).endswith("Positive.lean") and failure == "positive": code = 1
        calls.append(argv)
        return {"status": "ok" if code == 0 else "failed", "code": code, "stdout": text, "stderr": ""}
    calls = []
    monkeypatch.setattr(gate, "checked", fake)
    if failure == "no_gpu":
        def no_gpu(*a): raise gate.Rejected("accelerator unavailable")
        monkeypatch.setattr(gate, "inventory", no_gpu)
    with pytest.raises((gate.Rejected, FileNotFoundError)):
        gate.preflight(config, {})


@pytest.mark.parametrize("output", ["", "gpu, GPU-a, driver, 1\ngpu, GPU-b, driver, 1", "bad", "gpu, N/A, x, 1"])
def test_inventory_requires_one_identifiable_accelerator(monkeypatch, output):
    monkeypatch.setattr(gate, "checked", lambda *a: {"status": "ok", "stdout": output})
    with pytest.raises(gate.Rejected):
        gate.inventory("unused")


@pytest.mark.parametrize("fault", ["no_launch", "wrong_kernel", "zero_time", "wrong_uuid", "schema", "missing"])
def test_profiler_refuses_missing_or_malformed_observations(tmp_path, fault):
    path = tmp_path / "profile.sqlite"
    if fault != "missing":
        sqlite_fixture(path, count=0 if fault == "no_launch" else 1,
                       kernel="cpu_fallback" if fault == "wrong_kernel" else "candidates_kernel",
                       duration=0 if fault == "zero_time" else 1,
                       uuid="GPU-other" if fault == "wrong_uuid" else None)
        if fault == "schema":
            with gate.sqlite3.connect(path) as db:
                db.execute("DROP TABLE CUPTI_ACTIVITY_KIND_KERNEL")
    with pytest.raises((gate.Rejected, gate.sqlite3.Error)):
        gate.observed_kernels(path, HARDWARE)


@pytest.mark.parametrize("fault", ["valid_fixture", "candidate", "missing_batch", "parity", "metrics", "launch_count"])
def test_profiled_proof_validation_offline(tmp_path, fault):
    doc = gate.documents()[0]
    probe_fixture(tmp_path, doc)
    if fault == "candidate":
        path = tmp_path / "call-0.stdout"
        path.write_bytes(path.read_bytes().replace(b"2 1 0 0 -1 -1", b"2 999 0 0 -1 -1"))
    if fault == "missing_batch": (tmp_path / "call-0.stdout").unlink()
    data = json.loads((tmp_path / "result.json").read_text())
    if fault == "parity": data["result"]["status"] = "not_derived"
    if fault == "metrics": data["telemetry"][0]["launches"] = 0
    if fault == "launch_count":
        with gate.sqlite3.connect(tmp_path / "profile.sqlite") as db:
            db.execute("INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES(2, 3, 0, 2, 1)")
    gate.write_json(tmp_path / "result.json", data)
    if fault == "valid_fixture":
        checked = gate.validate_probe(tmp_path, doc, HARDWARE)
        assert checked["launches"] == 1 and checked["trace_sha256"]
    else:
        with pytest.raises((gate.Rejected, gate.ref.InvalidProblem, FileNotFoundError)):
            gate.validate_probe(tmp_path, doc, HARDWARE)


@pytest.fixture(scope="module")
def comparison(tmp_path_factory):
    directory = tmp_path_factory.mktemp("synthetic-comparison")
    docs, _ = gate.corpus()
    rows = []
    for case, doc in enumerate(docs):
        p = gate.ref.Problem.parse(doc)
        expected = gate.ref.construct(p)
        for repeat in range(gate.REPEATS):
            for lane in ("python", "mojo_cpu", "mojo_gpu", "lean_grind"):
                derived = expected["status"] == "derived"
                row = {"lane": lane, "case": case, "repeat": repeat, "result": expected,
                       "status": "proof_accepted" if derived else expected["status"], "proof_accepted": derived,
                       "verification": {"status": "accepted", "code": 0}}
                if lane == "mojo_gpu":
                    seeds = set(p.premises) | {(i, i) for i in range(len(p.terms))}
                    row.update(telemetry=[{"launches": 1}] if p.goal not in seeds else [],
                               device_launches=int(p.goal not in seeds))
                if lane == "lean_grind":
                    row["status"] = "lean_baseline_accepted" if derived else "lean_failed"
                elif derived:
                    wire = gate.codec.encode_trace(p, expected)
                    name = f"{lane}-{case}-{repeat}"
                    (directory / (name + ".trace")).write_bytes(wire)
                    (directory / (name + ".lean")).write_text(gate.ref.lean_source(p, expected))
                    row["trace_sha256"] = sha256(wire).hexdigest()
                rows.append(row)
    return directory, docs, {"schema": "lean-max-comparison-v1", "corpus_sha256": gate.CORPUS_HASH,
                             "budgets": {"max_records": 64, "max_rounds": 32}, "rows": rows}


@pytest.mark.parametrize("fault", ["valid_fixture", "partial", "duplicate", "lean_missing", "lean_failed", "wrong_trace",
                                   "wrong_corpus", "budget", "parity", "no_launch", "unavailable_baseline"])
def test_complete_comparison_gate_offline(comparison, fault):
    directory, docs, original = comparison
    report = deepcopy(original)
    row = next(r for r in report["rows"] if r["lane"] == "mojo_gpu" and r["case"] == 0)
    if fault == "partial": report["rows"].pop()
    if fault == "duplicate": report["rows"][-1] = report["rows"][0]
    if fault == "lean_missing": row["status"] = "lean_unavailable"
    if fault == "lean_failed": row["verification"]["status"] = "failed"
    if fault == "wrong_trace": row["trace_sha256"] = "0" * 64
    if fault == "wrong_corpus": report["corpus_sha256"] = "0" * 64
    if fault == "budget": report["budgets"]["max_records"] = 1
    if fault == "parity":
        r = next(r for r in report["rows"] if r["lane"] == "mojo_cpu" and r["case"] == 3)
        r["status"] = "construction_error"
    if fault == "no_launch": row.update(telemetry=[{}], device_launches=0)
    if fault == "unavailable_baseline":
        next(r for r in report["rows"] if r["lane"] == "lean_grind")["status"] = "lean_unavailable"
    if fault == "valid_fixture":
        assert len(gate.validate_comparison(report, directory, docs)) == 28
    else:
        with pytest.raises(gate.Rejected):
            gate.validate_comparison(report, directory, docs)


@pytest.mark.parametrize("failure", [RuntimeError("simulated runner failure"), KeyboardInterrupt(),
                                     subprocess.TimeoutExpired("simulated profiler", 1)])
def test_failures_never_emit_accepted_receipts(tmp_path, monkeypatch, failure):
    def fail(*a): raise failure
    monkeypatch.setattr(gate, "execute", fail)
    receipt = gate.run(args(tmp_path / "run"))
    assert receipt["accepted"] is False and receipt["status"] == "rejected"


@pytest.mark.parametrize("fault", ["valid_fixture", "missing", "wrong_version", "duplicate"])
def test_installed_pixi_package_identity(tmp_path, monkeypatch, fault):
    monkeypatch.setattr(gate.sys, "prefix", str(tmp_path))
    directory = tmp_path / "conda-meta"
    directory.mkdir()
    names = ["modular", "max", "max-core", "max-serve", "max-benchmark", "mblack",
             "mojo", "mojo-compiler", "mojo-python"]
    for name in names:
        if fault == "missing" and name == "max": continue
        version = gate.MOJO_VERSION if name.startswith("mojo") else gate.MODULAR_VERSION
        if fault == "wrong_version" and name == "max": version = "old"
        gate.write_json(directory / (name + ".json"), {"name": name, "version": version, "build": "fixture"})
    if fault == "duplicate":
        (directory / "duplicate.json").write_bytes((directory / "max.json").read_bytes())
    if fault == "valid_fixture":
        assert set(gate.package_versions()) == set(names)
    else:
        with pytest.raises(gate.Rejected):
            gate.package_versions()
