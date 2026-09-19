"""The provenance manifest matches the tree, and the verifier fails on divergence."""

from __future__ import annotations

import copy
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import provenance  # noqa: E402

FACADES = {"finite_exact/rational.mojo", "finite_exact/closed_interval.mojo", "finite_linear_algebra/matrix.mojo",
           "finite_linear_algebra/matrix3.mojo", "finite_linear_algebra/rational_elimination.mojo"}


def manifest() -> dict:
    return provenance.load()


def test_manifest_matches_the_working_tree():
    assert provenance.check(manifest(), provenance.current_blobs()) == []
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "provenance.py"), "--check"], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout


def test_update_is_idempotent_on_a_current_tree():
    m = manifest()
    assert provenance.render(provenance.update(m, provenance.current_blobs())) == provenance.render(m)


#: Every pinned source, its repository, and the subtree each import came from.
#: The first six are single-package extractions, where the package and the
#: repository share a name. The seventh is not an extraction at all: it is a
#: consumer of this monorepo, and two packages that grew there were lifted
#: back here, so its imports come from that repository's `src` and `tools`.
SOURCES = {
    "finite_exact": ("larsbx/finite_exact", ("finite_exact",)),
    "interval_q": ("larsbx/interval_q", ("interval_q",)),
    "finite_linear_algebra": ("larsbx/finite_linear_algebra", ("finite_linear_algebra",)),
    "substitution_dynamics": ("larsbx/substitution_dynamics", ("substitution_dynamics",)),
    "finite_proof_records": ("larsbx/finite_proof_records", ("finite_proof_records",)),
    "claim_governance_tools": ("larsbx/claim_governance_tools", ("claim_governance",)),
    "finite_mandelbrot_research": ("larsbx/finite-mandelbrot-research", ("src", "tools")),
}


def test_every_source_pins_a_commit_and_its_subtrees():
    sources = manifest()["sources"]
    assert set(sources) == set(SOURCES)
    for name, source in sources.items():
        repository, required = SOURCES[name]
        assert source["repository"] == repository
        assert len(source["commit"]) == 40 and all(c in "0123456789abcdef" for c in source["commit"])
        assert all(len(tree) == 40 for tree in source["subtrees"].values())
        for subtree in required:
            assert subtree in source["subtrees"], (name, source["subtrees"])


def test_imported_packages_are_copies_or_declared_modifications():
    files = manifest()["files"]
    for path, entry in files.items():
        if path.startswith(("finite_exact/", "finite_linear_algebra/", "substitution_dynamics/", "proof_records/", "audit/claim_governance/")):
            assert entry["relation"] in {"copy", "modified", "facade", "authored"}, path
    assert {p for p, e in files.items() if e["relation"] == "facade"} == FACADES
    copies = {p for p, e in files.items() if e["relation"] == "copy"}
    assert {"finite_exact/bigint_z.mojo", "finite_exact/rat_q.mojo", "finite_exact/closed_q.mojo", "finite_linear_algebra/qlinalg.mojo",
            "substitution_dynamics/words.mojo", "audit/claim_governance/findings.py"} <= copies
    # The coverage check is new here, so the two files that register and configure it have diverged from the retired source repository.
    assert {files[p]["relation"] for p in ("audit/claim_governance/runner.py", "audit/claim_governance/policy.py")} == {"modified"}
    assert files["audit/claim_governance/checks/coverage.py"]["relation"] == "authored"
    assert files["fixtures/vectors.json"]["relation"] == "generated"
    assert "audit/provenance.json" not in files
    assert any("must not describe itself" in e for e in provenance.check({**manifest(), "files": {**files, "audit/provenance.json": {"relation": "generated", "blob": "0" * 40, "generator": "x"}}}, provenance.current_blobs()))


def test_check_names_each_kind_of_divergence():
    m = manifest()
    blobs = provenance.current_blobs()
    drifted = dict(blobs, **{"finite_exact/bigint_z.mojo": "0" * 40})
    errors = provenance.check(m, drifted)
    assert any(e.startswith("finite_exact/bigint_z.mojo: blob") for e in errors)
    assert any("marked copy but differs from source blob" in e for e in errors)
    assert provenance.check(m, dict(blobs, **{"new_file.py": "1" * 40})) == [
        "new_file.py: not in the manifest (run tools/provenance.py --update and review the relation)"]
    missing = {p: b for p, b in blobs.items() if p != "README.md"}
    assert provenance.check(m, missing) == ["README.md: listed but missing from the tree"]
    forged = copy.deepcopy(m)
    forged["files"]["tools/make_vectors.py"]["relation"] = "copy"
    assert any("marked copy but differs" in e for e in provenance.check(forged, blobs))
    same = copy.deepcopy(m)
    same["files"]["finite_exact/bigint_z.mojo"]["relation"] = "modified"
    assert any("marked modified but is identical" in e for e in provenance.check(same, blobs))
    unpinned = copy.deepcopy(m)
    unpinned["files"]["finite_exact/bigint_z.mojo"]["source"] = "elsewhere"
    assert any("is not pinned" in e for e in provenance.check(unpinned, blobs))
    leaky = copy.deepcopy(m)
    leaky["files"]["README.md"]["source_blob"] = "2" * 40
    assert any("carries source fields" in e for e in provenance.check(leaky, blobs))


def test_update_reclassifies_and_adds_new_files_as_authored():
    m = manifest()
    blobs = dict(provenance.current_blobs(), **{"finite_exact/bigint_z.mojo": "0" * 40, "new_file.py": "1" * 40})
    updated = provenance.update(m, blobs)
    assert updated["files"]["finite_exact/bigint_z.mojo"]["relation"] == "modified"
    assert updated["files"]["finite_exact/bigint_z.mojo"]["source_blob"] == m["files"]["finite_exact/bigint_z.mojo"]["source_blob"]
    assert updated["files"]["new_file.py"] == {"relation": "authored", "blob": "1" * 40}
    assert updated["sources"] == m["sources"]
    assert provenance.check(updated, blobs) == []


def test_blob_id_is_the_git_blob_id():
    assert provenance.blob_id(b"") == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    assert provenance.blob_id(b"hello\n") == "ce013625030ba8dba906f756967f9e9ca394464a"
