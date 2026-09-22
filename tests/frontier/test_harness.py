"""The frontier harness records honest rows and refuses to compare unlike things."""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FRONTIER = ROOT / "benchmarks" / "frontier"
sys.path.insert(0, str(FRONTIER))
sys.path.insert(0, str(FRONTIER / "ff_orbit_census"))

import harness  # noqa: E402

ORACLE = {"run": [sys.executable, str(FRONTIER / "ff_orbit_census" / "reference.py"), "--kernel"], "version": [sys.executable, "--version"]}
LIAR = {"run": [sys.executable, "-c", "import sys; print('contract u32-prime-field-orbit-v1'); print('kernel_ns 1', file=sys.stderr)"]}
REFUSER = {"run": [sys.executable, "-c", "import sys; sys.exit('unsupported: no threads')"]}


def row(**kw) -> dict:
    base = {"implementation": "x", "lane": "cpu_single", "status": "ok", "semantic_contract": "c", "corpus_sha256": "s", "output_digest": "d"}
    return base | kw


def test_manifest_ranks_the_orbit_census_first_with_every_required_field():
    manifest = harness.load_manifest()
    first = min(manifest["candidate"], key=lambda c: c["rank"])
    assert first["id"] == "ff_orbit_census" and first["contract"] == harness.oracle("ff_orbit_census").CONTRACT
    assert "python_only" == manifest["result_requirements"]["forbid_speedup_denominator"]


def test_compare_refuses_a_semantic_contract_or_corpus_mismatch():
    with pytest.raises(harness.ContractMismatch):
        harness.compare([row(), row(implementation="y", semantic_contract="other")])
    with pytest.raises(harness.ContractMismatch):
        harness.compare([row(), row(implementation="y", corpus_sha256="other")])


def test_compare_reports_divergence_and_ignores_rows_that_did_not_run():
    assert harness.compare([row(), row(implementation="y"), row(implementation="z", status="unsupported", output_digest=None)]) == []
    assert harness.compare([row(), row(implementation="y", output_digest="e")]) == ["y/cpu_single digest e != x/cpu_single digest d"]


def test_rows_carry_every_required_field_and_the_honest_status(tmp_path):
    registry = {"oracle": ORACLE, "liar": LIAR, "refuser": REFUSER, "bend": {"status": "not_implemented"}}
    rows = harness.run_candidate("ff_orbit_census", "smoke", registry, lanes=["cpu_single"], repeats=2, build_dir=tmp_path)
    required = harness.load_manifest()["result_requirements"]["required"]
    assert all(set(required) <= set(r) for r in rows)
    status = {r["implementation"]: r["status"] for r in rows}
    assert status == {"oracle": "ok", "liar": "replay_rejected", "refuser": "unsupported", "bend": "not_implemented"}
    oracle = next(r for r in rows if r["implementation"] == "oracle")
    assert oracle["replay_verdict"] == "accepted (full)" and len(oracle["warm_wall_time_distribution"]["kernel_ns"]) == 2
    assert oracle["peak_memory"]["max_rss_kib"] > 0 and oracle["transfer_time"] is None
    assert json.loads(json.dumps(rows)) == rows


def test_gpu_lane_without_a_runner_is_a_row_not_an_omission(tmp_path):
    rows = harness.run_candidate("ff_orbit_census", "smoke", {"oracle": ORACLE}, lanes=["gpu_one"], repeats=1, build_dir=tmp_path)
    assert [r["status"] for r in rows] == ["no_runner"]


TOOLCHAINS = {"mojo": "mojo", "rust": "cargo", "bend": "bend"}


def installed(env: dict[str, str] | None = None) -> set[str]:
    """Kernels whose toolchain is on PATH; fails if one that FRONTIER_REQUIRE names is not."""
    env = os.environ if env is None else env
    have = {name for name, tool in TOOLCHAINS.items() if shutil.which(tool)}
    required = {name for name in env.get("FRONTIER_REQUIRE", "").split(",") if name}
    assert required <= set(TOOLCHAINS), f"FRONTIER_REQUIRE names unknown kernels: {sorted(required - set(TOOLCHAINS))}"
    assert required <= have, f"required kernel toolchains missing: {sorted(required - have)}"
    return have


def test_a_required_toolchain_that_is_missing_fails_rather_than_skips(monkeypatch):
    monkeypatch.setattr(shutil, "which", lambda tool: None if tool == "bend" else "/bin/" + tool)
    assert installed({}) == {"mojo", "rust"}
    with pytest.raises(AssertionError, match=r"missing: \['bend'\]"):
        installed({"FRONTIER_REQUIRE": "rust,bend"})
    with pytest.raises(AssertionError, match="unknown kernels"):
        installed({"FRONTIER_REQUIRE": "fortran"})


def test_julia_is_registered_as_not_implemented_rather_than_omitted():
    assert harness.load_registry("ff_orbit_census")["julia"] == {"status": "not_implemented"}


def test_every_installed_kernel_agrees_with_the_oracle_on_the_regression_corpus(tmp_path):
    have = installed()
    registry = {name: impl for name, impl in harness.load_registry("ff_orbit_census").items() if name in have}
    if not registry:
        pytest.skip("no kernel toolchain on PATH")
    lanes = ["cpu_single", "cpu_all"]
    rows = harness.run_candidate("ff_orbit_census", "regress", registry, lanes=lanes, repeats=1, build_dir=tmp_path)
    status = {(r["implementation"], r["lane"]): r["status"] for r in rows}
    assert status == {(n, lane): "unsupported" if (n, lane) == ("mojo", "cpu_all") else "ok" for n in registry for lane in lanes}
    assert harness.compare(rows) == []
    assert all(r["replay_verdict"] == "accepted (full)" for r in rows if r["status"] == "ok")
