import pytest

from claim_governance.policy import PolicyError, policy_from_mapping
from tests.audit.conftest import make_policy, run_check

LEDGER = [
    {"name": "BoundedExclusion", "status": "finite-domain", "aliases": ["bounded exclusion"]},
    {"name": "OverlapProductivity", "status": "open"},
    {"name": "WedgeBound", "status": "proved"},
]
COVERAGE = {"tests": ["tests/test_*.mojo"], "require_classes": ["finite-domain"]}
RECEIPTS = "# finite proof-test receipts 1"


def policy(**overrides):
    return make_policy(claim=LEDGER, coverage={**COVERAGE, **overrides})


def test_a_guarded_claim_and_a_stated_contract_both_satisfy_the_declaration_rule(tree):
    root = tree({
        "tests/test_a.mojo": 'def main() raises:\n    require_claim("BoundedExclusion")\n',
        "tests/test_b.mojo": 'def main() raises:\n    require_contract("the vendored arithmetic contract")\n',
    })
    assert run_check("coverage", policy(), root) == ()


def test_an_alias_guards_the_claim_it_names(tree):
    root = tree({"tests/test_a.mojo": 'require_claim("bounded exclusion")\n'})
    assert run_check("coverage", policy(), root) == ()


def test_a_test_declaring_nothing_is_a_finding(tree):
    root = tree({"tests/test_a.mojo": 'require_claim("BoundedExclusion")\n', "tests/test_b.mojo": "def main():\n    pass\n"})
    findings = run_check("coverage", policy(), root)
    assert [(f.path, f.rule) for f in findings] == [("tests/test_b.mojo", "declaration")]
    assert "names no ledger claim" in findings[0].message


def test_a_claim_outside_the_ledger_is_a_finding_and_guards_nothing(tree):
    root = tree({"tests/test_a.mojo": 'require_claim("BoundedExclusion")\nrequire_claim("Invented")\n'})
    assert [(f.line, f.rule) for f in run_check("coverage", policy(), root)] == [(2, "Invented")]


def test_a_required_class_with_no_test_is_reported_against_the_policy(tree):
    root = tree({"tests/test_a.mojo": 'require_contract("nothing in the ledger")\n'})
    findings = run_check("coverage", policy(), root)
    assert [(f.path, f.rule) for f in findings] == [("claim_governance.toml", "BoundedExclusion")]
    assert findings[0].message == "no test guards this 'finite-domain' claim"


def test_classes_outside_require_classes_need_no_test(tree):
    root = tree({"tests/test_a.mojo": 'require_claim("BoundedExclusion")\n'})
    assert run_check("coverage", policy(), root) == ()


def test_a_declaration_in_a_comment_does_not_count(tree):
    root = tree({"tests/test_a.mojo": '# require_claim("BoundedExclusion")\nrequire_contract("x")\n'})
    assert [f.rule for f in run_check("coverage", policy(), root)] == ["BoundedExclusion"]


@pytest.mark.parametrize("example", [
    '\'require_claim("BoundedExclusion")\'',
    '\'\'\'require_claim("BoundedExclusion")\'\'\'',
    '"""Example:\nrequire_claim("BoundedExclusion")\n"""',
    'r\'require_claim("BoundedExclusion")\'',
    'f\'require_claim("BoundedExclusion")\'',
    r'"""Example: \""" require_claim("BoundedExclusion") """',
])
@pytest.mark.parametrize("receipts", [None, "build/absent.tsv"])
@pytest.mark.parametrize("suffix", [".mojo", ".py"])
def test_string_examples_cannot_guard_a_claim(tree, example, receipts, suffix):
    path = "tests/test_a" + suffix
    root = tree({path: example + '\nrequire_contract("x")\n'})
    assert [f.rule for f in run_check("coverage", policy(receipts=receipts, tests=[path]), root)] == ["BoundedExclusion"]


def test_a_docstring_is_not_a_contract_declaration(tree):
    root = tree({"tests/test_a.mojo": '\'require_contract("x")\'\n'})
    assert [f.rule for f in run_check("coverage", policy(), root)] == ["declaration", "BoundedExclusion"]


def test_real_declarations_after_docstrings_keep_their_line_numbers(tree):
    root = tree({"tests/test_a.mojo": '"""Example:\nrequire_claim("Invented")\n"""\nrequire_claim("BoundedExclusion")\nrequire_claim("Unknown")\n'})
    assert [(f.line, f.rule) for f in run_check("coverage", policy(), root)] == [(5, "Unknown")]


def test_a_receipt_cannot_turn_a_string_example_into_a_declaration(tree):
    root = tree({
        "tests/test_a.mojo": '\'require_claim("BoundedExclusion")\'\nrequire_contract("x")\n',
        "build/receipts.tsv": f"{RECEIPTS}\ntests/test_a.mojo\tclaim\tBoundedExclusion\ntests/test_a.mojo\tcontract\tx\n",
    })
    assert [f.rule for f in run_check("coverage", policy(receipts="build/receipts.tsv"), root)] == ["BoundedExclusion", "BoundedExclusion"]


def test_no_test_globs_means_the_check_is_silent(tree):
    root = tree({"tests/test_a.mojo": "def main():\n    pass\n"})
    assert run_check("coverage", make_policy(claim=LEDGER), root) == ()


# --- receipts: a declaration counts only if the run reached it ----------------------


def test_receipts_credit_only_the_declarations_the_run_reached(tree):
    root = tree({
        "tests/test_a.mojo": 'require_claim("BoundedExclusion")\n',
        "tests/test_b.mojo": 'require_contract("kernel contract")\n',
        "build/receipts.tsv": f"{RECEIPTS}\ntests/test_a.mojo\tclaim\tBoundedExclusion\ntests/test_b.mojo\tcontract\tkernel contract\n",
    })
    assert run_check("coverage", policy(receipts="build/receipts.tsv"), root) == ()


def test_a_declaration_the_run_never_reached_neither_counts_nor_passes(tree):
    root = tree({
        "tests/test_a.mojo": 'require_claim("BoundedExclusion")\n',
        "build/receipts.tsv": f"{RECEIPTS}\n",
    })
    findings = run_check("coverage", policy(receipts="build/receipts.tsv"), root)
    assert [(f.path, f.line, f.rule) for f in findings] == [
        ("tests/test_a.mojo", 1, "BoundedExclusion"),
        ("claim_governance.toml", 0, "BoundedExclusion"),
    ]
    assert "did not reach it" in findings[0].message


def test_a_receipt_nothing_declares_is_drift(tree):
    root = tree({
        "tests/test_a.mojo": 'require_claim("BoundedExclusion")\n',
        "build/receipts.tsv": f"{RECEIPTS}\ntests/test_a.mojo\tclaim\tBoundedExclusion\ntests/test_gone.mojo\tclaim\tWedgeBound\n",
    })
    findings = run_check("coverage", policy(receipts="build/receipts.tsv"), root)
    assert [(f.path, f.rule) for f in findings] == [("build/receipts.tsv", "WedgeBound")]


def test_a_malformed_receipts_file_is_one_finding_and_credits_nothing(tree):
    """A broken run log says nothing about what executed, so the claim its
    declaration would have guarded is reported uncovered.  Reading it as an
    absent log instead would make a green suite out of a file nobody can
    read -- which is what this test asserted before it asserted it."""
    for body in ("wrong banner\n", f"{RECEIPTS}\ntests/test_a.mojo\tclaim\n", f"{RECEIPTS}\ntests/test_a.mojo\tguess\tBoundedExclusion\n"):
        root = tree({"tests/test_a.mojo": 'require_claim("BoundedExclusion")\n', "build/receipts.tsv": body})
        findings = run_check("coverage", policy(receipts="build/receipts.tsv"), root)
        assert [f.rule for f in findings] == ["receipts", "BoundedExclusion"], body
        assert findings[1].message == "no test guards this 'finite-domain' claim"


def test_a_parsed_receipts_file_still_credits_what_the_run_reached(tree):
    """The other side of the same rule: malformed credits nothing, but a log
    that parses must not be treated as malformed."""
    root = tree({
        "tests/test_a.mojo": 'require_claim("BoundedExclusion")\n',
        "build/receipts.tsv": f"{RECEIPTS}\n# a comment, and a blank line follow\n\ntests/test_a.mojo\tclaim\tBoundedExclusion\n",
    })
    assert run_check("coverage", policy(receipts="build/receipts.tsv"), root) == ()


def test_absent_receipts_leave_the_static_layer_alone(tree):
    root = tree({"tests/test_a.mojo": 'require_claim("BoundedExclusion")\n'})
    assert run_check("coverage", policy(receipts="build/receipts.tsv"), root) == ()


# --- policy validation ------------------------------------------------------------


def test_an_undeclared_required_class_is_a_policy_error():
    with pytest.raises(PolicyError, match="require_classes names undeclared classes"):
        make_policy(coverage={"tests": ["t/*.mojo"], "require_classes": ["invented"]})


@pytest.mark.parametrize("key,pattern,message", [
    ("claim_pattern", "(", "invalid pattern"),
    ("claim_pattern", 'require_claim\\("([^"]*)"\\)', "must capture a group named 'claim'"),
    ("contract_pattern", 'guards\\("(?P<claim>[^"]*)"\\)', "must capture a group named 'contract'"),
])
def test_a_declaration_pattern_must_compile_and_name_its_group(key, pattern, message):
    with pytest.raises(PolicyError, match=message):
        make_policy(coverage={key: pattern})


def test_custom_patterns_are_honoured(tree):
    custom = {"tests": ["tests/*.zig"], "require_classes": ["proved"], "claim_pattern": r'requireProof\("(?P<claim>[^"]*)"\)', "contract_pattern": r'statement\("(?P<contract>[^"]*)"\)'}
    root = tree({"tests/t.zig": 'requireProof("WedgeBound");\n'})
    assert run_check("coverage", policy_from_mapping({"repository": {"name": "x/y"}, "status": {"classes": ["proved"], "synonyms": {}},
                                                     "claim": [{"name": "WedgeBound", "status": "proved"}], "coverage": custom}), root) == ()


@pytest.mark.parametrize("body", [
    '// requireProof("WedgeBound");\n',
    '/// requireProof("WedgeBound");\n',
    '//! requireProof("WedgeBound");\n',
    'const example =\n    \\\\requireProof("WedgeBound");\n;\n',
    'const example = "requireProof(\\"WedgeBound\\")";\n',
])
@pytest.mark.parametrize("receipts", [None, "missing.tsv"])
def test_custom_zig_patterns_only_credit_code(tree, body, receipts):
    custom = {"tests": ["tests/*.zig"], "require_classes": ["proved"], "receipts": receipts,
              "claim_pattern": r'requireProof\("(?P<claim>[^"]*)"\)'}
    root = tree({"tests/t.zig": body})
    configured = policy_from_mapping({"repository": {"name": "x/y"},
                                      "status": {"classes": ["proved"], "synonyms": {}},
                                      "claim": [{"name": "WedgeBound", "status": "proved"}], "coverage": custom})
    assert [f.rule for f in run_check("coverage", configured, root)] == ["declaration", "WedgeBound"]


def test_coverage_fails_closed_for_sources_without_a_lexer(tree):
    root = tree({"tests/example.txt": 'require_claim("BoundedExclusion")\n'})
    assert [f.rule for f in run_check("coverage", policy(tests=["tests/*.txt"]), root)] == ["declaration", "BoundedExclusion"]


def test_escaped_newline_stays_inside_a_source_string(tree):
    root = tree({"tests/test_a.py": "'example \\\nrequire_claim(\"BoundedExclusion\")'\n"})
    assert [f.rule for f in run_check("coverage", policy(tests=["tests/*.py"]), root)] == ["declaration", "BoundedExclusion"]
