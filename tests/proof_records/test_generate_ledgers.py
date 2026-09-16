"""Conformance tests for tools/generate_ledgers.py against docs/ledger-generation-spec.md."""

from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

import generate_ledgers as gl  # noqa: E402
import make_ledger_example as mle  # noqa: E402
import make_vectors as mv  # noqa: E402

ENV = {**os.environ, "PYTHONPATH": str(ROOT / "audit")}
FIXTURE = ROOT / "fixtures" / "ledger"


def ledger(**changes) -> gl.Ledger:
    data = copy.deepcopy(mle.example())
    data.update(changes)
    return gl.Ledger(
        repository=data["repository"], module=data["module"],
        records={n: gl.record_from_json(r) for n, r in data["records"].items()},
        assumption_sets={k: tuple(v) for k, v in data["assumption_sets"].items()},
        status_classes={**gl.DEFAULT_STATUS_CLASSES, **data["status_classes"]},
        status_labels=data["status_labels"], tla_dir=data["tla_dir"], index_path=data["index_path"], source="example.json",
    )


def with_records(**edits) -> gl.Ledger:
    data = copy.deepcopy(mle.example())
    for name, record in edits.items():
        if record is None:
            del data["records"][name]
        else:
            data["records"][name] = record
    return ledger(records=data["records"])


def refusal(led: gl.Ledger) -> str:
    with pytest.raises(gl.LedgerError) as caught:
        gl.analyse(led)
    return str(caught.value)


ANALYSIS = gl.analyse(ledger())


# --- committed example ------------------------------------------------------


def test_committed_example_is_current():
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "make_ledger_example.py"), "--check"], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout
    assert gl.load_ledger(FIXTURE / "example.json") == ledger()


def test_claim_governance_audit_of_the_example_passes():
    result = subprocess.run([sys.executable, "-m", "claim_governance.cli", "--root", str(FIXTURE), "--policy", str(FIXTURE / "policy.toml")],
                            capture_output=True, text=True, check=False, env=ENV)
    assert result.returncode == 0, result.stdout


# --- section 2: analysis ---------------------------------------------------


def test_partition_of_the_results():
    assert ANALYSIS.proved == ("Census", "Conditional", "Lemma", "OnRetracted", "Theorem", "WithinSweep")
    assert ANALYSIS.imported == ("Density",)
    assert ANALYSIS.bounded == ("Sweep",)
    assert ANALYSIS.withdrawn == ("Retracted",)
    requires = {e.name: e.requires for e in ANALYSIS.entries}
    assert requires["Conditional"] == ("Lemma", "Galois")
    assert requires["Lemma"] == ("Census", "Density")
    assert requires["Census"] == ()


def test_status_classes_follow_kind_tags_and_closure():
    status = {e.name: e.status for e in ANALYSIS.entries}
    assert status == {"Census": "proved", "Lemma": "proved", "Theorem": "proved", "WithinSweep": "proved",
                      "Conditional": "conditional", "Density": "imported", "Sweep": "finite-domain",
                      "Galois": "open-frontier", "Retracted": "retired", "OnRetracted": "blocked"}
    assert {e.name for e in ANALYSIS.entries if not e.closure.complete} == {"Conditional", "Galois", "OnRetracted", "Retracted", "Sweep"}


def test_established_is_the_least_fixpoint():
    assert gl.established(ANALYSIS, ()) == {"Census"}
    assert gl.established(ANALYSIS, ("Density",)) == {"Census", "Density", "Lemma", "Theorem"}
    assert gl.established(ANALYSIS, ("Galois",)) == {"Census", "Galois"}
    assert gl.established(ANALYSIS, ("Density", "Galois")) == {"Census", "Density", "Galois", "Lemma", "Theorem", "Conditional"}
    assert gl.established(ANALYSIS, ("Sweep",)) == {"Census", "Sweep", "WithinSweep"}


def test_assumptions_that_would_break_no_withdrawn_dependency_are_refused():
    # ProofArchitecture.Init establishes Assumed outright, so an assumed result
    # that is withdrawn or requires a withdrawn result violates the invariant
    # in the initial state; the ledger is refused instead of rendered.
    assert "GaloisAssumed: Retracted is withdrawn and cannot be assumed" in refusal(ledger(assumption_sets={"GaloisAssumed": ["Retracted"]}))
    assert "S: OnRetracted requires a withdrawn result and cannot be assumed" in refusal(ledger(assumption_sets={"S": ["OnRetracted"]}))
    tainted = mv.rec(mv.Kind.IMPORTED, "import citing the retracted lemma", mv.PISOT, (mv.edge(mle.RETRACTED, "tainted/retracted"),),
                     source="somewhere", hypotheses_checked="true")
    assert "ImportsAssumed: Tainted requires a withdrawn result and cannot be assumed" in refusal(with_records(Tainted=mle.record_json(tainted)))


def test_output_paths_stay_inside_the_root_and_never_collide():
    for bad in ("/tmp/tla", "../tla", "tla/../..", ""):
        assert f"tla_dir {bad!r} must be a normalized path" in refusal(ledger(tla_dir=bad))
    assert "index_path '/etc/index.md' must be a normalized path" in refusal(ledger(index_path="/etc/index.md"))
    assert "index_path 'tla/Example.tla' collides with a generated TLA+ file" in refusal(ledger(index_path="tla/Example.tla"))
    assert "index_path 'tla//MCExampleOpen.cfg' collides" in refusal(ledger(index_path="tla//MCExampleOpen.cfg"))
    assert gl.output_paths(ledger()) == ("tla/Example.tla", "tla/MCExampleOpen.tla", "tla/MCExampleOpen.cfg", "tla/MCExampleImports.tla",
                                         "tla/MCExampleImports.cfg", "ledger-index.md")


def tagged(record, *tags):
    return mle.record_json(mv.identified(mv.replace(record, tags=frozenset(tags))))


def test_each_refusal_names_its_reason():
    good = mle.record_json(mv.CENSUS)
    assert "bad-name: not a TLA+ identifier" in refusal(with_records(**{"bad-name": good}))
    assert "Twin: identifier already used by Census" in refusal(with_records(Twin=good))
    assert "Unchecked: rejected: imported theorem with unchecked hypotheses" in refusal(with_records(Unchecked=mle.record_json(mv.UNCHECKED)))
    assert "Lemma: depends on unknown record" in refusal(with_records(Census=None))
    assert "Census: tagged withdrawn but its outcome is 'accepted'" in refusal(with_records(Census=tagged(mv.CENSUS, "withdrawn")))
    assert "Census: more than one status override tag" in refusal(with_records(Census=tagged(mv.CENSUS, "status:a", "status:b")))
    assert "Bogus: rejected: unknown record kind" in refusal(with_records(Bogus={**good, "kind": "theorem"}))
    assert "module name 'MC Ledger' is not a TLA+ identifier" in refusal(ledger(module="MC Ledger"))
    assert "assumption set 'ProvedDef': invalid or reserved name" in refusal(ledger(assumption_sets={"ProvedDef": ["Census"]}))
    assert "assumption set 'Census' collides with a record name" in refusal(ledger(assumption_sets={"Census": []}))
    assert "assumption set 'S': unknown record 'Nobody'" in refusal(ledger(assumption_sets={"S": ["Nobody"]}))


def test_load_refuses_wrong_format_and_empty_ledgers(tmp_path):
    path = tmp_path / "l.json"
    path.write_text(json.dumps({"format": "other", "records": {}}))
    with pytest.raises(gl.LedgerError, match="unknown ledger format"):
        gl.load_ledger(path)
    path.write_text(json.dumps({"format": gl.FORMAT, "records": {}}))
    with pytest.raises(gl.LedgerError, match="no records"):
        gl.load_ledger(path)


# --- section 3: surfaces -----------------------------------------------------


def test_tla_ledger_rendering():
    text = gl.render_tla(ANALYSIS)
    assert text.startswith("---- MODULE Example ----\n")
    assert "EXTENDS ProofArchitecture" in text
    assert '      [] r = "Lemma" -> {"Census", "Density"}' in text
    assert '    CASE r = "Census" -> {}' in text
    assert '      [] r = "WithinSweep" -> {"Sweep"}]' in text
    proved = text[text.index("ProvedDef == {"):text.index("\nImportedDef == ")]
    assert '"Census"' in proved and '"Density"' not in proved and '"Sweep"' not in proved and '"Retracted"' not in proved
    assert 'ImportedDef == {\n    "Density"\n}' in text
    assert 'WithdrawnDef == {\n    "Retracted"\n}' in text
    assert 'GaloisAssumed == {\n    "Galois"\n}' in text
    assert "ImportsAssumed == ImportedDef" in text
    assert 'RetractedNotEstablished == "Retracted" \\notin established' in text
    assert text == gl.render_tla(gl.analyse(ledger()))


def test_models_list_the_unreachable_results_and_the_reachable_set():
    models = gl.render_models(ANALYSIS)
    assert set(models) == {"MCExampleOpen.tla", "MCExampleOpen.cfg", "MCExampleImports.tla", "MCExampleImports.cfg"}
    open_cfg, imports_cfg = models["MCExampleOpen.cfg"], models["MCExampleImports.cfg"]
    assert "CONSTANT Assumed   <- NoAssumptions" in open_cfg and "CONSTANT Assumed   <- ImportsAssumed" in imports_cfg
    invariants = lambda cfg: [l.strip() for l in cfg[cfg.index("INVARIANTS"):cfg.index("PROPERTY")].splitlines()[1:] if l.strip()]
    assert invariants(open_cfg) == list(gl.BASE_INVARIANTS) + [f"{n}NotEstablished" for n in
                                                                ("Conditional", "Density", "Galois", "Lemma", "OnRetracted", "Retracted", "Sweep", "Theorem", "WithinSweep")]
    assert "LemmaNotEstablished" not in invariants(imports_cfg) and "ConditionalNotEstablished" in invariants(imports_cfg)
    assert 'Reachable == {\n    "Census"\n}' in models["MCExampleOpen.tla"]
    assert '"Theorem"' in models["MCExampleImports.tla"]
    assert "EventuallyReachable == <>(established = Reachable)" in models["MCExampleImports.tla"]
    assert "EXTENDS Example" in models["MCExampleOpen.tla"]


def test_claims_rendering_and_splice():
    fragment = gl.render_claims(ANALYSIS)
    assert fragment.startswith(gl.CLAIMS_BEGIN) and fragment.rstrip("\n").endswith(gl.CLAIMS_END)
    assert fragment.count("[[claim]]") == len(ANALYSIS.entries)
    census = fragment[fragment.index('name = "Census"'):fragment.index('name = "Conditional"')]
    assert 'section = "ProvedDef == {"' in census and 'expect = "present"' in census and "anchor = '| Census |'" in census
    density = fragment[fragment.index('name = "Density"'):fragment.index('name = "Galois"')]
    assert 'section = "ImportedDef == {"' in density
    galois = fragment[fragment.index('name = "Galois"'):fragment.index('name = "Lemma"')]
    assert 'expect = "absent"' in galois and 'status = "open-frontier"' in galois
    head = "[repository]\nname = 'x'\n"
    spliced = gl.splice_claims(head, fragment)
    assert spliced.startswith(head) and spliced.endswith(fragment)
    assert gl.splice_claims(spliced, fragment) == spliced
    stale = spliced.replace('status = "proved"', 'status = "wrong"') + "\n# tail\n"
    assert gl.splice_claims(stale, fragment) == spliced + "\n# tail\n"


def test_policy_check_refuses_undeclared_classes_and_labels():
    policy = (FIXTURE / "policy.toml").read_text()
    assert gl.check_policy(policy, ANALYSIS) == []
    bare = "[repository]\nname = 'x'\n" + gl.render_claims(ANALYSIS)
    assert gl.check_policy(bare, ANALYSIS) == ["policy: claim 'Census' has undeclared status class 'proved'"]
    assert gl.check_policy("repository = []\n" + gl.render_claims(ANALYSIS), ANALYSIS) == ["policy: AttributeError(\"'list' object has no attribute 'get'\")"]
    assert gl.check_policy("[repository]\nname = 'x'\n[status]\nclasses = 'proved'\n", ANALYSIS)[0].startswith("policy: ")
    unlabelled = policy.replace('"theorem" = "proved"\n', "")
    assert gl.check_policy(unlabelled, ANALYSIS) == [f"{n}: index label 'theorem' is not a [status.synonyms] label of class 'proved'"
                                                     for n in ANALYSIS.names(lambda e: e.status == "proved")]


def test_index_rows_carry_label_dependencies_and_closure():
    text = gl.render_index(ANALYSIS)
    rows = {line.split(" | ")[0].strip("| "): line for line in text.splitlines() if line.startswith("| ") and not line.startswith("| Claim") and not line.startswith("| ---")}
    assert rows["Census"].startswith("| Census | theorem | verified_finite_computation | 4554 PIP specimens |")
    assert rows["Lemma"].endswith("| `Census`, `Density` | complete |")
    assert rows["Conditional"].endswith("| `Lemma`, `Galois` | incomplete: Galois (pending: source pending) |")
    assert rows["Sweep"].endswith("| none | incomplete: Sweep (bounded experiment is evidence, not a theorem) |")
    assert rows["Galois"].split(" | ")[1] == "open"
    assert "| Retracted |" not in rows["OnRetracted"]


# --- section 4: command line --------------------------------------------------


def test_cli_writes_checks_and_detects_hand_edits(tmp_path):
    out = tmp_path / "consumer"
    policy = out / "claim_governance.toml"
    out.mkdir()
    policy.write_text((FIXTURE / "policy.toml").read_text().split(gl.CLAIMS_BEGIN)[0])
    argv = ["gl", str(FIXTURE / "example.json"), "--out", str(out), "--claims", str(policy)]
    assert gl.main(argv) == 0
    assert gl.main(argv + ["--check"]) == 0
    assert (out / "tla" / "Example.tla").read_text() == (FIXTURE / "tla" / "Example.tla").read_text()
    assert policy.read_text() == (FIXTURE / "policy.toml").read_text()
    index = out / "ledger-index.md"
    index.write_text(index.read_text().replace("| Census | theorem |", "| Census | open |"))
    assert gl.main(argv + ["--check"]) == 1
    assert gl.main(argv) == 0 and gl.main(argv + ["--check"]) == 0
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({**mle.example(), "assumption_sets": {"ProvedDef": []}}))
    assert gl.main(["gl", str(bad), "--out", str(out)]) == 2
    assert gl.main(["gl", str(tmp_path / "missing.json"), "--out", str(out)]) == 2
    assert gl.main(argv[:-2] + ["--claims", str(out / "ledger-index.md")]) == 2
    assert gl.main(argv[:-2] + ["--claims", str(out / "tla" / ".." / "tla" / "Example.tla")]) == 2


# --- section 5: TLC, when available --------------------------------------------

TLA_TOOLS = os.environ.get("TLA_TOOLS")


def tlc(directory: Path, model: str) -> str:
    cmd = ["java", "-XX:+UseSerialGC", "-cp", TLA_TOOLS, "tlc2.TLC", "-workers", "1", "-config", f"{model}.cfg", f"{model}.tla"]
    return subprocess.run(cmd, cwd=directory, capture_output=True, text=True, check=False).stdout


@pytest.mark.skipif(not TLA_TOOLS or shutil.which("java") is None, reason="set TLA_TOOLS to a tla2tools.jar to model-check the example")
def test_tlc_verifies_both_models_and_rejects_a_wrong_configuration(tmp_path):
    for path in (FIXTURE / "tla").iterdir():
        shutil.copy(path, tmp_path / path.name)
    shutil.copy(ROOT / "proof_records" / "ProofArchitecture.tla", tmp_path / "ProofArchitecture.tla")
    for model, states in (("MCExampleOpen", 2), ("MCExampleImports", 4)):
        log = tlc(tmp_path, model)
        assert "No error has been found" in log, log
        assert f"{states} distinct states found" in log
    cfg = tmp_path / "MCExampleImports.cfg"
    cfg.write_text(cfg.read_text().replace("    TypeOK\n", "    TypeOK\n    LemmaNotEstablished\n"))
    assert "Invariant LemmaNotEstablished is violated" in tlc(tmp_path, "MCExampleImports")
