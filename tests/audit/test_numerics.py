from tests.audit.conftest import make_policy, run_check

TRIG = r"\b(?:sin|cos|tan|exp|log|sqrt)\b|unit circle"
FLOAT = r"\b(?:Float64|Float32|float)\b|(?<![\w.])\d+\.\d+(?![\w.])"


def policy(**extra):
    return make_policy(numerics={"rule": [
        {"name": "no-trig", "pattern": TRIG, "paths": ["src/**/*.mojo"], "message": "transcendental primitive"},
        {"name": "no-float", "pattern": FLOAT, "paths": ["src/**/*.mojo", "src/**/*.py"], "allow_files": ["src/quarantine.mojo"], "allow_lines": ["var eps = 0.5"], **extra},
    ]})


def test_rules_report_line_and_rule_and_skip_masked_text(tree):
    root = tree({
        "src/k.mojo": '# sqrt in a comment\nvar s = "cos"\nvar x = sqrt(2)\nvar y: Float64 = 1.5\nvar eps = 0.5\nvar z = 3\n',
        "src/quarantine.mojo": "var f: Float64 = 0.1\n",
        "src/o.py": "x = 2.0\n",
    })
    findings = run_check("numerics", policy(), root)
    assert [(f.path, f.line, f.rule) for f in findings] == [
        ("src/k.mojo", 3, "no-trig"),
        ("src/k.mojo", 4, "no-float"),
        ("src/o.py", 1, "no-float"),
    ]
    assert findings[0].message.startswith("transcendental primitive: ")


def test_excluded_paths_are_not_scanned(tree):
    policy_ = make_policy(scan={"exclude": ["src/vendored/**"]}, numerics={"rule": [{"name": "no-trig", "pattern": TRIG, "paths": ["src/**/*.mojo"]}]})
    root = tree({"src/vendored/x.mojo": "sin(x)\n", "src/y.mojo": "sin(x)\n"})
    assert [f.path for f in run_check("numerics", policy_, root)] == ["src/y.mojo"]


def test_negating_context_exempts_prose_that_forbids_a_primitive(tree):
    rule = {"name": "rank2-loci", "pattern": "unit circle|disk object", "paths": ["docs/*.md"], "negating_context": ["not ", "does not", "forbidden"], "radius": 40}
    root = tree({"docs/r.md": "The finite core does not introduce a unit circle.\n\nLater prose.\n\nHere a unit circle is used as a primitive.\n"})
    findings = run_check("numerics", make_policy(numerics={"rule": [rule]}), root)
    assert [(f.line, f.rule) for f in findings] == [(5, "rank2-loci")]


def test_multiline_pattern_reports_each_line_once(tree):
    rule = {"name": "x", "pattern": "x", "paths": ["src/*.py"]}
    root = tree({"src/a.py": "x = x + x\ny = 1\nx = 2\n"})
    assert [f.line for f in run_check("numerics", make_policy(numerics={"rule": [rule]}), root)] == [1, 3]
