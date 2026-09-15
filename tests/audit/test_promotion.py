from tests.audit.conftest import make_policy, run_check


def policy(**extra):
    return make_policy(
        scan={"prose": ["docs/**/*.md"]},
        claim=[
            {"name": "G1", "status": "open", "aliases": ["finite BPA"]},
            {"name": "BoundedDiscrepancy", "status": "proved", "aliases": ["G1b-1"]},
        ],
        promotion={
            "proving_phrases": ["is proved", "we prove", "has been proved", "is a theorem"],
            "negating_context": ["not ", "remains open", "would", "conditional on", "without"],
            "settled_classes": ["proved", "imported", "finite-domain"],
            "radius": 30,
            **extra,
        },
    )


def test_open_claim_described_as_proved(tree):
    root = tree({"docs/a.md": "Finite BPA is proved in section 2.\n\nG1 remains open.\n\nG1b-1 is proved.\n"})
    findings = run_check("promotion", policy(), root)
    assert [(f.line, f.rule) for f in findings] == [(1, "G1")]


def test_negated_and_word_boundary_cases_pass(tree):
    root = tree({"docs/a.md": "G1-free PDS theorem is proved without G1.\nWe prove nothing conditional on G1.\nG1 is not proved.\n"})
    assert run_check("promotion", policy(), root) == ()


def test_allowlist_and_fenced_code(tree):
    root = tree({"docs/a.md": "```\nG1 is proved\n```\n", "docs/b.md": "G1 is a theorem.\n"})
    assert [f.path for f in run_check("promotion", policy(), root)] == ["docs/b.md"]
    assert run_check("promotion", policy(allow=["docs/b.md"]), root) == ()
