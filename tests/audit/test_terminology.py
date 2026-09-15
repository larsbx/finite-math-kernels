from tests.audit.conftest import make_policy, run_check

FIELDS = ["Terminology declaration:", "Genealogy:", "Bridge claim:", "Known leaks:", "Use discipline:"]
REGISTRY = """
# Registry

## Project terms

### PointVertex

Terminology declaration: `PointVertex` is a project term.
Genealogy: incidence geometry.
Bridge claim: definition-only.
Known leaks: no topology.
Use discipline: finite carriers only.
"""


def policy(**extra):
    base = {
        "scan": {"prose": ["docs/**/*.md"], "source": ["src/**/*.mojo"]},
        "terminology": {
            "registry": "docs/registry.md",
            "registry_sections": ["## Project terms"],
            "declaration_fields": FIELDS,
            "project_terms": ["PointVertex", "rank-2 coordinate record"],
            "scoped": [{"term": "wake ambiguity", "home": ["docs/C1_"]}],
            "deprecated": [{"term": "catalogue extensionality", "replacement": "SeparatorCatalogueAdequacy", "allow": ["docs/legacy.md"]}],
            "risky_phrases": ["isomorphic to", "essentially the same"],
            "negating_context": ["not ", "no ", "never"],
            "migration_context": ["deprecated", "legacy"],
            "allow": ["docs/registry.md"],
            **extra,
        },
    }
    return make_policy(**base)


def rules(findings):
    return sorted((f.path, f.rule) for f in findings)


def test_registry_missing_is_a_finding(tree):
    findings = run_check("terminology", policy(), tree({"docs/a.md": "plain prose\n"}))
    assert rules(findings) == [("docs/registry.md", "registry")]


def test_registry_declares_required_terms_and_sections(tree):
    root = tree({"docs/registry.md": REGISTRY})
    findings = run_check("terminology", policy(), root)
    assert rules(findings) == [("docs/registry.md", "rank-2 coordinate record")]


def test_clean_repository_has_no_findings(tree):
    root = tree({
        "docs/registry.md": REGISTRY + "\n### rank-2 coordinate record\n\nTerminology declaration: x.\nGenealogy: y.\nBridge claim: z.\nKnown leaks: w.\nUse discipline: v.\n",
        "docs/a.md": "This is not isomorphic to anything. See docs/registry.md for wake ambiguity.\n",
        "docs/C1_home.md": "wake ambiguity is at home here.\n",
        "src/k.mojo": "# isomorphic to a comment\nfn f(): pass\n",
    })
    assert run_check("terminology", policy(), root) == ()


def test_risky_phrase_without_declaration_or_negation(tree):
    root = tree({"docs/registry.md": REGISTRY, "docs/a.md": "The nest is isomorphic to the fiber.\n"})
    findings = [f for f in run_check("terminology", policy(project_terms=["PointVertex"]), root)]
    assert rules(findings) == [("docs/a.md", "isomorphic to")]
    assert findings[0].line == 1


def test_full_declaration_governs_risky_phrases_but_partial_does_not(tree):
    governed = "Terminology declaration: nest.\nGenealogy: a.\nBridge claim: b.\nKnown leaks: c.\nUse discipline: d.\n\nIt is isomorphic to X under the bridge.\n"
    partial = "Terminology declaration: nest.\nGenealogy: a.\n\nIt is isomorphic to X.\n"
    root = tree({"docs/registry.md": REGISTRY, "docs/g.md": governed, "docs/p.md": partial})
    findings = run_check("terminology", policy(project_terms=["PointVertex"]), root)
    assert rules(findings) == [("docs/p.md", "declaration"), ("docs/p.md", "isomorphic to")]


def test_scoped_term_outside_home_needs_pointer(tree):
    root = tree({
        "docs/registry.md": REGISTRY,
        "docs/other.md": "We discuss wake ambiguity here.\n",
        "docs/C1_x.md": "wake ambiguity at home.\n",
        "docs/pointed.md": "wake ambiguity, see docs/registry.md.\n",
    })
    findings = run_check("terminology", policy(project_terms=["PointVertex"]), root)
    assert rules(findings) == [("docs/other.md", "wake ambiguity")]


def test_deprecated_term_needs_migration_context_unless_allowlisted(tree):
    root = tree({
        "docs/registry.md": REGISTRY,
        "docs/new.md": "We prove catalogue extensionality.\n",
        "docs/mig.md": "The deprecated phrase catalogue extensionality is replaced.\n",
        "docs/legacy.md": "catalogue extensionality everywhere.\n",
    })
    findings = run_check("terminology", policy(project_terms=["PointVertex"]), root)
    assert rules(findings) == [("docs/new.md", "catalogue extensionality")]


def test_fenced_code_and_source_comments_are_ignored(tree):
    root = tree({
        "docs/registry.md": REGISTRY,
        "docs/a.md": "```\nisomorphic to\n```\n",
        "src/k.mojo": 'var s = "essentially the same"\n',
    })
    assert run_check("terminology", policy(project_terms=["PointVertex"]), root) == ()


def test_marker_in_a_heading_is_a_title_not_a_declaration(tree):
    doc = "### 0.1 Terminology declaration: schema\n\nTerminology declaration: a schema.\nGenealogy: a.\nBridge claim: b.\nKnown leaks: c.\nUse discipline: d.\n\n### 0.2 Next\n\nIt is isomorphic to X under the declaration above.\n"
    root = tree({"docs/registry.md": REGISTRY, "docs/bridge.md": doc})
    assert run_check("terminology", policy(project_terms=["PointVertex"]), root) == ()
