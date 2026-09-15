from tests.audit.conftest import make_policy, run_check


def policy(surfaces):
    return make_policy(claim=[{"name": "OverlapProductivity", "status": "open", "aliases": ["overlap productivity"], "surfaces": surfaces}])


def test_agreeing_surfaces_pass(tree):
    root = tree({
        "docs/map.md": "| Seedwise overlap productivity | **Open conjectural gate** | source |\n",
        "docs/ledger.md": "chain:\n=> one-seed overlap productivity   [OPEN]\n",
        "tla/Ledger.tla": '(* OverlapProductivity: the only open premise [OPEN] *)\n"OverlapProductivity" \\in OpenSet',
    })
    surfaces = [
        {"path": "docs/map.md"},
        {"path": "docs/ledger.md", "anchor": "one-seed overlap productivity", "window_lines": 0},
        {"path": "tla/Ledger.tla", "window_lines": 1},
    ]
    assert run_check("consistency", policy(surfaces), root) == ()


def test_each_failure_mode_is_named(tree):
    root = tree({
        "docs/wrong.md": "overlap productivity is **Repository-proved**\n",
        "docs/silent.md": "overlap productivity\nlong discussion\n",
        "docs/absent.md": "nothing relevant\n",
    })
    surfaces = [{"path": p, "window_lines": 1} for p in ("docs/wrong.md", "docs/silent.md", "docs/absent.md", "docs/missing.md")]
    findings = run_check("consistency", policy(surfaces), root)
    messages = {f.path: f.message for f in findings}
    assert "ledger records 'open'" in messages["docs/wrong.md"]
    assert "no status label" in messages["docs/silent.md"]
    assert "does not mention" in messages["docs/absent.md"]
    assert "missing" in messages["docs/missing.md"]


def test_surfaces_keep_markdown_code_fences_but_drop_tex_comments(tree):
    root = tree({
        "docs/chain.md": "```text\n=> overlap productivity   [OPEN]\n```\n",
        "manuscripts/m.tex": "overlap productivity % [OPEN] only in a comment\n",
    })
    surfaces = [{"path": "docs/chain.md", "window_lines": 0}, {"path": "manuscripts/m.tex", "window_lines": 0}]
    assert [f.path for f in run_check("consistency", policy(surfaces), root)] == ["manuscripts/m.tex"]


def test_source_surfaces_keep_string_literals_and_drop_comments(tree):
    root = tree({"src/ledger.mojo": 'def s():\n    return Block("OverlapProductivity", [OPEN])  # [PROVED]\n'})
    surfaces = [{"path": "src/ledger.mojo", "anchor": 'Block("OverlapProductivity"', "window_lines": 0}]
    assert run_check("consistency", policy(surfaces), root) == ()
    wrong = make_policy(claim=[{"name": "OverlapProductivity", "status": "proved", "surfaces": surfaces}])
    assert [f.message for f in run_check("consistency", wrong, root)] == ["surface shows ['open'] but the ledger records 'proved'"]


def test_window_may_mention_other_statuses_as_long_as_ledger_status_appears(tree):
    root = tree({"docs/m.md": "overlap productivity: **Open conjectural gate**; the bridge is an **Imported theorem**.\n"})
    assert run_check("consistency", policy([{"path": "docs/m.md", "window_lines": 0}]), root) == ()


TLA = '''ResultSet == {
    "OverlapProductivity", "SwapOverlapFiniteness"
}
ProvedDef == {
    "SwapOverlapFiniteness"
}
'''


def test_membership_surfaces(tree):
    root = tree({"tla/Ledger.tla": TLA})
    proved = {"path": "tla/Ledger.tla", "anchor": '"SwapOverlapFiniteness"', "section": "ProvedDef == {", "section_end": "}", "expect": "present"}
    absent = {"path": "tla/Ledger.tla", "section": "ProvedDef == {", "section_end": "}", "expect": "absent"}
    policy_ = make_policy(claim=[
        {"name": "OverlapProductivity", "status": "open", "surfaces": [absent]},
        {"name": "SwapOverlapFiniteness", "status": "proved", "surfaces": [proved]},
    ])
    assert run_check("consistency", policy_, root) == ()
    wrong = make_policy(claim=[
        {"name": "SwapOverlapFiniteness", "status": "open", "surfaces": [dict(absent)]},
        {"name": "OverlapProductivity", "status": "proved", "surfaces": [dict(proved, anchor=None)]},
        {"name": "Ghost", "status": "open", "surfaces": [dict(absent, section="Nowhere == {")]},
    ])
    findings = run_check("consistency", wrong, root)
    findings = tuple(sorted(findings))
    assert [(f.rule, f.line) for f in findings] == [("Ghost", 0), ("OverlapProductivity", 4), ("SwapOverlapFiniteness", 5)]
    assert "must be absent" in findings[2].message and "does not mention" in findings[1].message


def test_surface_policy_validation():
    import pytest
    from claim_governance.policy import PolicyError
    with pytest.raises(PolicyError, match="expect must be"):
        make_policy(claim=[{"name": "A", "status": "open", "surfaces": [{"path": "x", "expect": "maybe"}]}])
    with pytest.raises(PolicyError, match="together"):
        make_policy(claim=[{"name": "A", "status": "open", "surfaces": [{"path": "x", "section": "S"}]}])
