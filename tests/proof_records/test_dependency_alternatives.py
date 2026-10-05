"""Alternative proof routes establish one canonical conclusion, fail closed."""
import json
import shutil
from dataclasses import replace

import pytest

from test_generate_ledgers import ledger, refusal, tlc, TLA_TOOLS, ROOT
from proof_records import generate_ledgers as gl
from proof_records import graph
import make_vectors as mv
import make_ledger_example as mle


def fixture(groups=None, withdrawn=False):
    a = mv.rec(mv.Kind.PENDING, "renewal gate", mv.PISOT, reason="open")
    b = mv.rec(mv.Kind.PENDING, "overlap gate", mv.PISOT, reason="open",
               tags=frozenset({"withdrawn"}) if withdrawn else frozenset())
    c = mv.rec(mv.Kind.REPOSITORY, "finite graph", mv.PISOT, source="finite graph proof", proof_reviewed="true")
    routes = groups(a, b, c) if groups else [[a.id], [b.id, c.id]]
    g = mv.rec(mv.Kind.REPOSITORY, "canonical conclusion", mv.PISOT,
               (mv.edge(a, "g/renewal"), mv.edge(b, "g/overlap"), mv.edge(c, "g/finite")),
               source="two conditional assembly proofs", proof_reviewed="true",
               dependency_alternatives=json.dumps(routes), tags=frozenset({"status:open-frontier"}))
    d = mv.rec(mv.Kind.REPOSITORY, "downstream result", mv.PISOT, (mv.edge(g, "downstream/g"),),
               source="downstream proof", proof_reviewed="true")
    records = dict(zip(("Renewal", "Overlap", "Finite", "Canonical", "Downstream"),
                       map(mle.record_json, (a, b, c, g, d))))
    return ledger(records=records, aliases={}, surfaces={}, assumption_sets={"RenewalAssumed": ["Renewal"], "OverlapAssumed": ["Overlap"]} if not withdrawn else {})


def test_each_alternative_establishes_canonical_and_its_downstream():
    a = gl.analyse(fixture())
    assert gl.established(a, ()) == {"Finite"}
    assert gl.established(a, ("Renewal",)) == {"Finite", "Renewal", "Canonical", "Downstream"}
    assert gl.established(a, ("Overlap",)) == {"Finite", "Overlap", "Canonical", "Downstream"}
    assert next(e for e in a.entries if e.name == "Canonical").status == "open-frontier"
    # The second alternative is conjunctive: its overlap premise alone does
    # not suffice until the finite graph theorem can be discharged.
    entries = tuple(replace(e, outcome="open") if e.name == "Finite" else e for e in a.entries)
    assert gl.established(replace(a, entries=entries), ("Overlap",)) == {"Overlap"}
    assert "Canonical" in gl.established(replace(a, entries=entries), ("Renewal",))


@pytest.mark.parametrize("groups", [
    lambda a,b,c: [], lambda a,b,c: [[]], lambda a,b,c: [a.id],
    lambda a,b,c: [[a.id], [b.id]],
    lambda a,b,c: [[a.id], [b.id, c.id, "sha256:unknown"]],
    lambda a,b,c: [[a.id, a.id], [b.id, c.id]],
    lambda a,b,c: [[a.id], [b.id, c.id], [c.id, b.id]],
])
def test_malformed_or_uncited_routes_are_refused(groups):
    assert "dependency_alternatives" in refusal(fixture(groups))


def test_invalid_json_is_refused_and_grouping_is_digest_bound():
    led = fixture()
    r = led.records["Canonical"]
    bad = mv.identified(replace(r, id="", evidence=tuple((k,"broken") if k == "dependency_alternatives" else (k,v) for k,v in r.evidence)))
    assert "dependency_alternatives must be JSON" in refusal(replace(led, records={**led.records, "Canonical": bad}))
    assert bad.id != r.id  # grouping is bound into the proof-record identity


def test_withdrawn_branch_blocks_only_that_branch():
    a = gl.analyse(fixture(withdrawn=True))
    assert "Canonical" not in gl.established(a, ())
    assert "Canonical" in gl.established(a, ("Renewal",))
    assert "Overlap" not in gl.established(a, ("Renewal",))
    assert "withdrawn and cannot be assumed" in refusal(replace(fixture(withdrawn=True), assumption_sets={"Bad": ["Overlap"]}))
    gl.analyse(replace(fixture(withdrawn=True), assumption_sets={"Clean": ["Canonical"]}))


def test_bounded_or_imported_route_premises_are_not_auto_discharged():
    a = gl.analyse(fixture())
    for kind, outcome in ((mv.Kind.BOUNDED, "bounded"), (mv.Kind.IMPORTED, "accepted")):
        entries = tuple(replace(e, record=replace(e.record, kind=kind), outcome=outcome)
                        if e.name == "Finite" else e for e in a.entries)
        changed = replace(a, entries=entries)
        assert "Canonical" not in gl.established(changed, ("Overlap",))
        assert "Canonical" in gl.established(changed, ("Overlap", "Finite"))
        assert "Canonical" in gl.established(changed, ("Renewal",))


def test_rendered_models_and_graph_preserve_the_alternatives():
    a = gl.analyse(fixture())
    assert 'r = "Canonical" -> {{"Renewal"}, {"Overlap", "Finite"}}' in gl.render_tla(a)
    assert '(`Renewal`) OR (`Overlap` AND `Finite`)' in gl.render_index(a)
    models = gl.render_models(a)
    for model in ("RenewalAssumed", "OverlapAssumed"):
        assert "CanonicalNotEstablished" not in models[f"MCExample{model}.cfg"]
        assert '"Downstream"' in models[f"MCExample{model}.tla"]
    assert "CanonicalNotEstablished" in models["MCExampleOpen.cfg"]
    deps = [e for e in graph.build(a).edges if e.target == "Canonical"]
    assert len(deps) == 3
    assert all("alternative dependency branch(es):" in e.leaks for e in deps)


@pytest.mark.skipif(not TLA_TOOLS or shutil.which("java") is None, reason="set TLA_TOOLS for the dependency state machine")
def test_tlc_accepts_both_routes_and_rejects_a_false_nonestablishment(tmp_path):
    a = gl.analyse(fixture())
    for path, text in gl.render_all(a).items():
        dst = tmp_path / path
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(text)
    directory = tmp_path / "tla"
    shutil.copy(ROOT / "kernel/proof_records/ProofArchitecture.tla", directory)
    for model in ("Open", "RenewalAssumed", "OverlapAssumed"):
        log = tlc(directory, "MCExample" + model)
        assert "No error has been found" in log, log
    cfg = directory / "MCExampleOverlapAssumed.cfg"
    cfg.write_text(cfg.read_text().replace("    TypeOK\n", "    TypeOK\n    CanonicalNotEstablished\n"))
    assert "Invariant CanonicalNotEstablished is violated" in tlc(directory, "MCExampleOverlapAssumed")
