from claim_governance.checks.claims import statement_pattern
from tests.audit.conftest import make_policy, run_check

KINDS = ["Theorem", "Proposition", "Lemma", "Conjecture", "Hypothesis", "Open Problem"]


def policy(**extra):
    return make_policy(claims={"paths": ["docs/**/*.md", "manuscripts/*.tex"], "statement_kinds": KINDS, "window_lines": 2, **extra})


def test_statement_pattern_shapes():
    pattern = statement_pattern(tuple(KINDS))
    for line in ["## Theorem 4.4", "**Proposition 5.20.**", "**Lemma 1.1 (occurrence).**", "### Lemma 1", "\\begin{theorem}[x]", "\\begin{lemma}", "## Open Problem 5.35", "# Theorem"]:
        assert pattern.search(line), line
    for line in ["by Theorem 4.4 we get", "Lemma 5.36 proves the density side", "Theorem 2.16 (PDS implies termination)", "# Hypothesis firewall", "# Conjecture ledger", "theoremhood"]:
        assert not pattern.search(line), line


def test_labelled_statements_pass_and_unlabelled_fail(tree):
    root = tree({
        "docs/a.md": "## Theorem 1 (finite graph)\n\n**Status: Repository-proved.**\n\n## Lemma 2\n\nSome text\nmore text\nstill no label\n",
        "manuscripts/m.tex": "\\begin{theorem}[main] % Repository-proved in a comment does not count\nbody\n\\end{theorem}\n\\begin{proposition}\n[OPEN]\n\\end{proposition}\n",
    })
    findings = run_check("claims", policy(), root)
    assert [(f.path, f.line, f.rule) for f in findings] == [("docs/a.md", 5, "Lemma"), ("manuscripts/m.tex", 1, "theorem")]


def test_file_level_status_governs_all_statements(tree):
    root = tree({
        "docs/governed.md": "# Note\n\n**Status:** proved finite reduction.\n\n### Lemma 1\n\nbody\n",
        "docs/late.md": "# Note\n" + "\n" * 12 + "**Status:** too far down.\n\n### Lemma 1\n\nbody\n",
        "docs/none.md": "### Lemma 1\n\nbody\n",
    })
    findings = run_check("claims", policy(file_status_marker="**Status:**"), root)
    assert [f.path for f in findings] == ["docs/late.md", "docs/none.md"]


def test_allowlisted_files_are_skipped(tree):
    root = tree({"docs/a.md": "## Theorem 1\n\nnothing\n"})
    assert run_check("claims", policy(allow=["docs/a.md"]), root) == ()
    assert len(run_check("claims", policy(), root)) == 1
