"""The exact-arithmetic audit engine, on trees built to pass and trees built to fail.

An audit that has only ever seen a passing tree is a claim, not a check. Each
case builds a small consumer that violates one rule and asserts the audit
names it. The cases are the union of the two consumers' suites
(larsbx/finite-julia-set-research tests/test_exact_arithmetic_audit.py and
larsbx/finite-mandelbrot-research tests/test_exact_arithmetic_spec.py), run
under each consumer's policy where the policies differ, plus one case per
policy field.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path

import pytest

from exact_arithmetic_audit import CLASSES, Policy, allowlisted, audit, binding_rows, run

SPEC = "docs/rational-interval-arithmetic-spec.md"
BINDING = "docs/exact-arithmetic-binding.md"
TICK = "`"

JULIA_SECTIONS = (
    "## 0. The problem being solved",
    "## 5. Conformance criteria",
    "## 6. Consumers and binding tables",
    "## 7. Hook: how a consumer enforces the specification",
)
JULIA = Policy(
    repository="larsbx/finite-julia-set-research",
    binding=BINDING,
    required_sections=JULIA_SECTIONS,
    scan_roots=("src",),
)

HEADING = "### 6.2 " + TICK + "larsbx/finite-mandlebrot-research" + TICK
MANDELBROT = Policy(
    repository="larsbx/finite-mandlebrot-research",
    binding_heading=HEADING,
    required_sections=("## 0. The problem being solved", "## 6. Repository binding", HEADING),
    classes=None,
    arithmetic_modules=("rat_q", "rational", "closed_q", "closed_interval"),
    skip_hidden=True,
    exempt_vendored_citations=False,
    scan_roots=("src",),
)

CONSUMER = "from finite_exact.rat_q import Q\n\ndef f() -> Q:\n    return Q(1, 2)\n"
HEADER = f"# Specification: {SPEC}.\n"


def code(path: str) -> str:
    return TICK + path + TICK


def row(path: str, cls: str, notes: str = "notes") -> str:
    return f"| item | {code(path)} | {cls} | {notes} |\n"


TABLE_HEAD = "| Spec item | Module | Class | Notes |\n| --- | --- | --- | --- |\n"


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def bind(root: Path, policy: Policy, *rows: str) -> None:
    """Write the binding table where the policy reads it."""
    table = TABLE_HEAD + "".join(rows)
    if policy.binding is not None:
        write(root, policy.binding, table)
    else:
        spec = (root / policy.spec).read_text(encoding="utf-8")
        head, _, _ = spec.partition(HEADING)
        write(root, policy.spec, head + HEADING + "\n\n" + table + "\n## 7. Hook\n")


def build(root: Path, policy: Policy) -> Path:
    """A minimal consumer: one bound, citing, exact module."""
    if policy.binding is not None:
        spec = "\n".join(JULIA_SECTIONS) + f"\n| {code(policy.repository)} | {code(BINDING)} |\n"
        write(root, policy.spec, spec)
    else:
        write(root, policy.spec, "## 0. The problem being solved\n## 6. Repository binding\n")
    bind(root, policy, row("src/kernel.mojo", "DEMO", "the one module"))
    write(root, policy.allowlist, "Empty by design; see `tools/audit_exact_arithmetic.py`.\n")
    write(root, "src/kernel.mojo", HEADER + CONSUMER)
    return root


BOTH = pytest.mark.parametrize("policy", [JULIA, MANDELBROT], ids=["julia", "mandelbrot"])


# --- shared rules, under both policies --------------------------------------------------


@BOTH
def test_a_faithful_tree_passes(tmp_path, policy, capsys):
    root = build(tmp_path, policy)
    assert audit(root, policy) == []
    assert run(root, policy) == 0 and "OK:" in capsys.readouterr().out


@BOTH
def test_an_unbound_arithmetic_consumer_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    write(root, "src/stray.mojo", HEADER + CONSUMER)
    assert audit(root, policy) == ["arithmetic consumer lacks binding row: src/stray.mojo"]


@BOTH
def test_a_bound_module_that_does_not_cite_the_spec_is_named(tmp_path, policy, capsys):
    root = build(tmp_path, policy)
    write(root, "src/kernel.mojo", CONSUMER)
    assert audit(root, policy) == [f"src/kernel.mojo does not cite {SPEC} (C7)"]
    assert run(root, policy) == 1 and "does not cite" in capsys.readouterr().out


@BOTH
def test_a_bound_module_that_does_not_exist_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    (root / "src" / "kernel.mojo").unlink()
    assert audit(root, policy) == ["binding row names missing file src/kernel.mojo"]


@BOTH
@pytest.mark.parametrize("literal", ["1e-3", "2.", ".5", "1.25", "1_000.5_0", "2E+4"])
def test_every_mojo_decimal_float_form_is_named(tmp_path, policy, literal):
    root = build(tmp_path, policy)
    write(root, "src/kernel.mojo", HEADER + CONSUMER + f"var x = {literal}\n")
    assert audit(root, policy) == [f"src/kernel.mojo:6: floating point in kernel scope (C1): var x = {literal}"]


@BOTH
@pytest.mark.parametrize("spelling", ["var x: Float64 = 0", "var x: Float = 0", "alias T = DType.float32",
                                      "var v = SIMD[DType.bfloat16, 4](0)", "var y = float(3)"])
def test_float_types_and_dtypes_are_named(tmp_path, policy, spelling):
    root = build(tmp_path, policy)
    write(root, "src/kernel.mojo", HEADER + CONSUMER + spelling + "\n")
    assert any("floating point in kernel scope (C1)" in e for e in audit(root, policy))


@BOTH
@pytest.mark.parametrize("clean", ["# the bound is 0.25 here", 'var s = "0.25"', '"""\nA docstring: 1.5.\n"""',
                                   "var v = version_1_2", "var r = x.5_field", "var n = 1_000"])
def test_comments_strings_and_identifiers_are_not_violations(tmp_path, policy, clean):
    root = build(tmp_path, policy)
    write(root, "src/kernel.mojo", HEADER + clean + "\n" + CONSUMER)
    assert audit(root, policy) == []


@BOTH
def test_a_quarantine_without_an_allowlist_entry_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    bind(root, policy, row("src/kernel.mojo", "QUARANTINED", "float substrate"))
    assert audit(root, policy) == ["src/kernel.mojo is QUARANTINED but not allowlisted"]


@BOTH
def test_an_allowlist_entry_without_a_quarantine_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    write(root, policy.allowlist, f"- {code('src/kernel.mojo')}\n")
    assert audit(root, policy) == ["src/kernel.mojo is allowlisted but not a QUARANTINED binding row"]


@BOTH
def test_a_quarantined_allowlisted_module_may_hold_floats(tmp_path, policy):
    root = build(tmp_path, policy)
    bind(root, policy, row("src/kernel.mojo", "QUARANTINED"))
    write(root, policy.allowlist, f"- {code('src/kernel.mojo')} — demo substrate\n")
    write(root, "src/kernel.mojo", HEADER + CONSUMER + "var x: Float64 = 1.5\n")
    assert audit(root, policy) == []


@BOTH
def test_prose_in_the_allowlist_is_not_a_grant(tmp_path, policy):
    root = build(tmp_path, policy)
    write(root, policy.allowlist, f"Entries must be rows of {code('src/kernel.mojo')}'s table.\n")
    assert allowlisted(root, policy) == set()
    assert audit(root, policy) == []


@BOTH
def test_a_spec_that_does_not_name_this_consumer_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    spec = root / SPEC
    spec.write_text(spec.read_text(encoding="utf-8").replace(policy.repository, "larsbx/somewhere-else"), encoding="utf-8")
    errors = audit(root, policy)
    assert f"{SPEC} does not name {policy.repository} as a consumer" in errors


@BOTH
def test_a_missing_spec_is_named_before_anything_else(tmp_path, policy):
    root = build(tmp_path, policy)
    (root / SPEC).unlink()
    assert audit(root, policy) == [f"missing {SPEC}"]


@BOTH
def test_a_missing_required_section_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    spec = root / SPEC
    spec.write_text(spec.read_text(encoding="utf-8").replace("## 0. The problem being solved", ""), encoding="utf-8")
    assert "spec lacks section '## 0. The problem being solved'" in audit(root, policy)


@BOTH
def test_an_empty_binding_table_is_named(tmp_path, policy):
    root = build(tmp_path, policy)
    bind(root, policy)
    assert audit(root, policy) == [f"{policy.binding or SPEC} has no binding rows"]


# --- vendored exemptions, read through the vendoring package -----------------------------


def vendor(root: Path, package: str = "borrowed") -> None:
    write(root, "vendored.toml", f'[[package]]\nname = "{package}"\nrepository = "elsewhere"\n'
          f'commit = "{"0" * 40}"\nroot = "src"\n\n[package.files]\n')
    write(root, f"src/{package}/lifted.mojo", CONSUMER)


def test_a_vendored_module_is_exempt_from_the_citation(tmp_path):
    root = build(tmp_path, JULIA)
    vendor(root)
    bind(root, JULIA, row("src/kernel.mojo", "DEMO"), row("src/borrowed/lifted.mojo", "CONFORMS"))
    assert audit(root, JULIA) == []


def test_a_tree_without_a_manifest_exempts_nothing(tmp_path):
    root = build(tmp_path, JULIA)
    write(root, "src/borrowed/lifted.mojo", CONSUMER)
    bind(root, JULIA, row("src/kernel.mojo", "DEMO"), row("src/borrowed/lifted.mojo", "CONFORMS"))
    assert audit(root, JULIA) == [f"src/borrowed/lifted.mojo does not cite {SPEC} (C7)"]


def test_an_unvendored_module_still_owes_the_citation(tmp_path):
    root = build(tmp_path, JULIA)
    vendor(root)
    write(root, "src/lifted.mojo", CONSUMER)
    bind(root, JULIA, row("src/kernel.mojo", "DEMO"), row("src/borrowed/lifted.mojo", "CONFORMS"),
         row("src/lifted.mojo", "DEMO"))
    assert audit(root, JULIA) == [f"src/lifted.mojo does not cite {SPEC} (C7)"]


def test_the_mandelbrot_policy_exempts_only_the_files_it_names(tmp_path):
    root = build(tmp_path, MANDELBROT)
    vendor(root)
    bind(root, MANDELBROT, row("src/kernel.mojo", "DEMO"), row("src/borrowed/lifted.mojo", "CONFORMS"))
    assert audit(root, MANDELBROT) == [f"src/borrowed/lifted.mojo does not cite {SPEC} (C7)"]
    named = replace(MANDELBROT, citation_exempt=frozenset({"src/borrowed/lifted.mojo"}))
    assert audit(root, named) == []


# --- one case per policy field where the consumers differ ---------------------------------


def test_classes_are_checked_when_the_policy_lists_them(tmp_path):
    root = build(tmp_path, JULIA)
    bind(root, JULIA, row("src/kernel.mojo", "CONFORM"))
    assert audit(root, JULIA) == [
        "binding row for src/kernel.mojo has unknown class 'CONFORM'",
        "arithmetic consumer lacks binding row: src/kernel.mojo",
    ]
    assert audit(root, replace(JULIA, classes=None)) == []
    assert set(CLASSES) == {"CONFORMS-CHECKED", "CONFORMS", "DEMO", "QUARANTINED"}


def test_arithmetic_modules_narrow_what_makes_a_consumer(tmp_path):
    root = build(tmp_path, MANDELBROT)
    write(root, "src/gcd_user.mojo", "from finite_exact.integer_gcd import gcd_int\n")
    assert audit(root, MANDELBROT) == []
    assert audit(root, replace(MANDELBROT, arithmetic_modules=None)) == [
        "arithmetic consumer lacks binding row: src/gcd_user.mojo"
    ]


def test_skip_hidden_leaves_dot_directories_unscanned(tmp_path):
    root = build(tmp_path, MANDELBROT)
    write(root, "src/.cache/build.mojo", "var x: Float64 = 1.5\n")
    assert audit(root, MANDELBROT) == []
    assert len(audit(root, replace(MANDELBROT, skip_hidden=False))) == 1


def test_float_exempt_prefixes_skip_the_c1_scan_only(tmp_path):
    root = build(tmp_path, JULIA)
    write(root, "src/upstream/x.mojo", "var x: Float64 = 1.5\n")
    assert len(audit(root, JULIA)) == 1
    assert audit(root, replace(JULIA, float_exempt_prefixes=("src/upstream/",))) == []


def test_binding_rows_are_read_from_the_named_section_only(tmp_path):
    root = build(tmp_path, MANDELBROT)
    spec = (root / SPEC).read_text(encoding="utf-8")
    other = "### 6.1 elsewhere\n\n" + TABLE_HEAD + row("src/other.mojo", "DEMO") + "\n"
    (root / SPEC).write_text(spec.replace(HEADING, other + HEADING), encoding="utf-8")
    assert binding_rows(root, MANDELBROT) == [("DEMO", ["src/kernel.mojo"])]
    assert audit(root, MANDELBROT) == []


def test_a_missing_binding_heading_fails_closed(tmp_path):
    root = build(tmp_path, MANDELBROT)
    policy = replace(MANDELBROT, binding_heading="### 6.9 nowhere", required_sections=())
    assert audit(root, policy) == [f"{SPEC}: binding heading '### 6.9 nowhere' not found"]


def test_python_files_are_scanned_when_the_policy_asks(tmp_path):
    root = build(tmp_path, JULIA)
    write(root, "src/oracle.py", "x = 0.5\n")
    assert audit(root, JULIA) == []
    assert audit(root, replace(JULIA, suffixes=(".mojo", ".py"))) == [
        "src/oracle.py:1: floating point in kernel scope (C1): x = 0.5"
    ]


def test_a_missing_binding_document_is_named(tmp_path):
    root = build(tmp_path, JULIA)
    (root / BINDING).unlink()
    assert audit(root, JULIA) == [f"missing {BINDING}"]
