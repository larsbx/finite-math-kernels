"""The lexical audit engine, on texts and trees built to pass and built to fail.

Each rule kind is pinned in both directions: the breach it exists for is
reported, and each exemption it grants is honoured. The cases are the union
of the planted-violation suites of the audits this engine replaces
(the terminology audit test of larsbx/finite-julia-set-research, the
no-limits audit test of larsbx/mandelbrot-bulbs-and-ford-circles-research,
and the rules of the terminology audit of larsbx/finite-mandelbrot-research,
which had none), each run under a policy shaped like its consumer's.
"""

from __future__ import annotations

import re
from dataclasses import replace
from pathlib import Path

import pytest

from lexical_audit import (
    ClauseRule,
    ContextRule,
    Declaration,
    DeclarationRule,
    Document,
    Policy,
    Requirement,
    Scope,
    all_of,
    audit,
    contains,
    run,
)

# --- a policy shaped like Julia's terminology audit -----------------------

CIRCLES = r"(?i)\b(circles?|circular|discs?|disks?|arcs?|circumferences?|polar angles?|radians?)\b"
CIRCLE_DENIAL = r"(?i)\b(no|not|nor|never|none|without|undefined|unavailable|cannot|forbidden|forbids|refuses)\b"
TERMINOLOGY = ClauseRule(
    scope=Scope(("docs/**/*.md", "tools/**/*.py"), exclude=("*/literature-gate*",)),
    banned=CIRCLES,
    message="{path}:{line}: '{match}' is not available at rank 2",
    denial=CIRCLE_DENIAL,
    reach=48,
    clause=r"(?<=[.;:])\s+",
    exempt_sections=("(?i)forbidden",),
    marker="terminology-exempt",
    allowed=("Siegel disk", "circular points", "Ford circles"),
)
REJECTED = ContextRule(
    scope=Scope(("docs/**/*.md",)),
    terms=("CutCatalogueRayEquivalence",),
    message="{path}: {term!r} is a rejected claim and must be cited as one",
    context=("reject",),
    radius=320,
)


def circles(text: str, name: str = "docs/note.md") -> list[str]:
    return [hit.match for hit in TERMINOLOGY.hits(name, text)]


@pytest.mark.parametrize("breach", [
    "A box straddling the unit circle at `c = 0`.",
    "Each point leaves the disc of radius `R`.",
    "The locus carries an arc of positive circumference.",
    "Read off the polar angle of the record.",
])
def test_a_banned_term_is_caught(breach):
    assert circles(breach)


def test_a_denial_is_not_a_breach():
    assert not circles("It is not a circle at rank 2, and no arc, angle, or circumference is available from it.")


def test_a_denial_only_covers_what_follows_it_within_reach():
    assert circles("Each leaves the disc of radius `R`, and by the criterion it never returns.")
    assert circles("For `lam` on the unit circle and not a root of unity.")
    assert circles("Nothing here is a problem, and the values at the largest computed N show the circle.") == ["circle"]


def test_a_denial_does_not_cross_a_clause():
    assert circles("No bound is claimed. The circle closes.") == ["circle"]


def test_a_denial_reaches_across_a_line_break_inside_one_clause():
    assert not circles("It is not\na circle.")


def test_an_allowed_phrase_is_masked_and_only_it_is():
    assert not circles("The boundary of the Siegel disk contains no critical point here.")
    assert not circles("See `larsbx/mandelbrot-bulbs-and-ford-circles-research`.")
    assert circles("The Ford circles meet a unit circle.") == ["circle"]


def test_an_exempt_section_covers_its_subsections_and_ends_at_its_level():
    text = "## Forbidden usages\n\n- calling the locus a circle;\n\n### Detail\n\nA circle.\n\n## Usages\n\nA circle.\n"
    hits = TERMINOLOGY.hits("docs/note.md", text)
    assert [(hit.line, hit.match) for hit in hits] == [(11, "circle")]


def test_a_heading_outside_an_exempt_section_is_audited():
    assert circles("## Circles everywhere\n") == ["Circles"]


def test_the_marker_exempts_exactly_one_paragraph():
    marked = "<!-- terminology-exempt: a classical device -->\nEvery circle passes\nthrough them.\n"
    assert not circles(marked)
    assert circles(marked + "\nEvery circle passes through them.\n") == ["circle"]
    assert circles("<!-- terminology-exempt: x -->\n\nEvery circle.\n") == ["circle"], "a blank line disarms the marker"


def test_the_marker_is_consumed_by_the_one_block_after_it():
    # A list item and a table row are each a block: the marker covers the first only.
    marker = "<!-- terminology-exempt: a classical device -->\n"
    assert circles(marker + "- a classical circle\n- a later circle\n") == ["circle"]
    assert [hit.line for hit in TERMINOLOGY.hits("docs/note.md", marker + "- a disc\n- a circle\n- an arc\n")] == [3, 4]
    assert circles(marker + "| a | disc |\n| b | circle |\n") == ["circle"]
    assert circles(marker + "Every circle passes.\n- a later disc\n") == ["disc"]
    assert circles("# <!-- terminology-exempt: x -->\n# a circle\n# a disc\n", name="tools/note.py") == ["disc"]


def test_source_files_are_read_with_their_comment_markers_removed():
    assert circles("# The unit circle is the boundary here.\n", name="tools/note.py") == ["circle"]
    assert circles('"""A disc."""\n', name="tools/note.py") == ["disc"]


def test_a_source_file_is_read_line_by_line():
    # A denial on one comment line must not reach a term on the next.
    assert circles("# no estimate\n# circle exists\n", name="tools/note.py") == ["circle"]
    assert circles('"""Nothing is\nbounded by a disc."""\n', name="tools/note.py") == ["disc"]
    assert not circles("# no circle exists\n", name="tools/note.py")


def test_the_reported_line_is_the_line_of_the_match():
    hits = TERMINOLOGY.hits("docs/note.md", "First line of a paragraph\nthat names a circle.\n")
    assert [(hit.line, hit.text) for hit in hits] == [(2, "that names a circle.")]


def test_scope_exclusions(tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "registry.md").write_text("## Forbidden usages\n\nA circle.\n", encoding="utf-8")
    (tmp_path / "docs" / "literature-gate-2026.md").write_text("On the unit circle.\n", encoding="utf-8")
    (tmp_path / "docs" / "note.md").write_text("On the unit circle.\n", encoding="utf-8")
    policy = Policy("Terminology audit", rules=(TERMINOLOGY,))
    assert audit(tmp_path, policy) == ["docs/note.md:1: 'circle' is not available at rank 2"]


def test_an_exempt_section_that_matches_no_heading_fails_closed(tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "note.md").write_text("# Title\n\nNothing.\n", encoding="utf-8")
    assert audit(tmp_path, Policy("t", rules=(TERMINOLOGY,))) == [
        "exempt section pattern '(?i)forbidden' matches no heading in scope"
    ]


def test_a_rejected_claim_needs_its_rejection_within_reach():
    def hits(text: str) -> list[str]:
        return [hit.term for hit in REJECTED.hits("docs/note.md", text)]

    assert hits("This rests on CutCatalogueRayEquivalence, which is not yet gated.\n")
    assert not hits("CutCatalogueRayEquivalence is rejected; see the gate.\n")
    assert not hits("The gate rejects it. " + "x" * 200 + " CutCatalogueRayEquivalence\n")
    assert hits("It is rejected. " + "x" * 400 + " CutCatalogueRayEquivalence is the bridge.\n")


# --- a policy shaped like the bulbs no-limits audit -----------------------

LIMITS = ClauseRule(
    scope=Scope(("REGISTER.md",)),
    banned=(r"(?i)→|⟶|->|\blim(?:_|\b|sup|inf)|\blimits?\b|(?<![\w])[Oo]\(|\bconverg(?:e|es|ed|ence|ing)\b"
            r"|\basymptotic\w*|\btends? to\b|\bapproach(?:es|ed|ing)?\b"),
    message="{path}:{line}: limit idiom {match!r} outside an exemption: {text:.120}",
    denial=r"(?i)\b(no|not|nor|never|none|nothing|without|withdrawn|removed|replaces?|unused)\b",
    reach=48,
    clause=r"(?<=[.;])\s+",
    exempt_sections=(r"^0\. Statement forms$",),
    marker="limit-exempt",
)


def limits(claims: str, exempt: str = "") -> list[str]:
    text = f"# Title\n\n## 0. Statement forms\n\n{exempt}\n\n## 2. PROVEN\n\n{claims}\n"
    return [hit.match for hit in LIMITS.hits("REGISTER.md", text)]


@pytest.mark.parametrize(("claim", "term"), [
    ("G tends to 1.12 along the family.", "tends to"),
    ("The sequence converges fast.", "converges"),
    ("so `κ → 0.0545` along p = 3.", "→"),
    ("with `lim_{q} G` equal to 1.1.", "lim_"),
    ("d = 2|c'| q⁻² (1 + O(q⁻²)).", "O("),
    ("G = Ĝ(x̃) + o(1).", "o("),
    ("The asymptotic law holds.", "asymptotic"),
    ("The one-sided limit at ⅓.", "limit"),
    ("G approaches 1.008.", "approaches"),
])
def test_each_limit_idiom_is_caught(claim, term):
    assert limits(claim) == [term]


def test_limit_exemptions():
    assert limits("The convergents p_n/q_n of 3/7; a convergent power series.") == []
    assert limits("No law `d = … (1 + O(q⁻²))` is asserted.") == []
    assert limits("A table at q = 59.", exempt="Replaces `lim` and `O(q⁻²)`.") == []
    assert limits("<!-- limit-exempt: quoting -->\nG → 1.12 as quoted.\n\nG → 1.12 again.") == ["→"]


def test_a_message_template_renders_the_line_text():
    (hit,) = LIMITS.hits("REGISTER.md", "## 0. Statement forms\n\nx\n\n## 1\n\nG converges.\n")
    assert hit.render(LIMITS.message) == "REGISTER.md:7: limit idiom 'converges' outside an exemption: G converges."


# --- rules shaped like Mandelbrot's terminology governance ----------------

DECLARATION = Declaration("Terminology declaration:", ("Terminology declaration:", "Genealogy:", "Known leaks:"))
NEGATING = ("not ", "no ", "without ", "forbidden", "reject", "cannot", "is not")
RISKY = ContextRule(
    scope=Scope(("docs/**/*.md", "kernel/**/*.mojo")),
    terms=("isomorphic to", "same as"),
    message="{path}: risky phrase '{term}' requires terminology declaration with genealogy and leaks",
    context=NEGATING,
    radius=140,
    exempt_declared=DECLARATION,
)
SCOPED = ContextRule(
    scope=Scope(("docs/**/*.md",), exclude=("docs/C1_*",)),
    terms=("wake ambiguity",),
    message="{path}: C1-scoped term '{term}' requires local declaration or registry pointer outside C1 files",
    context=NEGATING,
    exempt_declared=DECLARATION,
    exempt_if_contains=("docs/terminology-registry.md",),
)


def test_a_risky_phrase_needs_a_negation_or_a_declaration():
    assert RISKY.hits("docs/a.md", "This is isomorphic to that.")
    assert RISKY.hits("kernel/a.mojo", "# This is the SAME AS that.\n"), "comments and case are read"
    assert not RISKY.hits("docs/a.md", "This is not isomorphic to that.")
    declared = "Terminology declaration: x\nGenealogy: y\nKnown leaks: z\n\nThis is isomorphic to that."
    assert not RISKY.hits("docs/a.md", declared)
    assert RISKY.hits("docs/a.md", declared.replace("Known leaks: z", "")), "a partial declaration governs nothing"


def test_every_occurrence_is_read_not_only_the_first():
    text = "wake ambiguity is not here." + " " * 300 + "A wake ambiguity."
    assert [hit.line for hit in SCOPED.hits("docs/a.md", text)] == [1]
    assert len(SCOPED.hits("docs/a.md", text)) == 1


def test_a_registry_pointer_exempts_a_scoped_term():
    assert not SCOPED.hits("docs/a.md", "A wake ambiguity; see docs/terminology-registry.md.")


def test_the_window_is_centred_on_the_start_of_the_occurrence():
    rule = replace(RISKY, radius=10)
    assert rule.hits("docs/a.md", "isomorphic to is not"), "the marker is in reach of the end, not of the start"
    assert not rule.hits("docs/a.md", "it is not isomorphic to")


def test_a_context_rule_without_markers_reports_every_occurrence():
    rule = ContextRule(Scope(("k.mojo",)), ("unit circle",), "{path}: '{term}'")
    assert [hit.line for hit in rule.hits("k.mojo", "not a unit circle\nunit circle\n")] == [1, 2]


def test_a_declaration_must_be_complete(tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "a.md").write_text("Terminology declaration: x\nGenealogy: y\n", encoding="utf-8")
    rule = DeclarationRule(Scope(("docs/**/*.md",)), DECLARATION, "{path}: terminology declaration missing fields: {missing}")
    assert audit(tmp_path, Policy("t", rules=(rule,))) == ["docs/a.md: terminology declaration missing fields: Known leaks:"]


# --- documents --------------------------------------------------------------


def test_documents_must_exist_and_match(tmp_path):
    registry = Document(
        "docs/registry.md",
        "docs/registry.md: missing",
        (
            contains("## Terms", "docs/registry.md: no terms section"),
            Requirement(r"Terminology declaration:\s*.", "docs/registry.md: too few declarations", minimum=2),
            Requirement(all_of(r"Genealogy:", r"Known leaks:"), "docs/registry.md: incomplete declarations"),
        ),
    )
    rule = ContextRule(Scope(("docs/**/*.md",)), ("isomorphic to",), "{path}: risky")
    policy = Policy("t", documents=(registry,), rules=(rule,))
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "note.md").write_text("isomorphic to\n", encoding="utf-8")
    assert audit(tmp_path, policy) == ["docs/registry.md: missing"], "a failed document stops the scan by default"
    assert audit(tmp_path, replace(policy, stop_on_documents=False)) == ["docs/registry.md: missing", "docs/note.md: risky"]
    (tmp_path / "docs" / "registry.md").write_text("## Terms\nTerminology declaration: a\nGenealogy:\n", encoding="utf-8")
    assert audit(tmp_path, policy) == ["docs/registry.md: too few declarations", "docs/registry.md: incomplete declarations"]
    (tmp_path / "docs" / "registry.md").write_text(
        "## Terms\nTerminology declaration: a\nTerminology declaration: b\nKnown leaks:\nGenealogy:\n", encoding="utf-8")
    assert audit(tmp_path, policy) == ["docs/note.md: risky"]


def test_a_conditional_requirement_is_a_pattern():
    rule = Requirement(r"\A(?![\s\S]*catalogue extensionality)|(?i:deprecated)", "legacy term must be marked deprecated")
    assert rule.met("nothing to see")
    assert rule.met("catalogue extensionality is Deprecated")
    assert not rule.met("catalogue extensionality")


# --- scope and the run --------------------------------------------------------


def test_vendored_packages_are_skipped_when_the_scope_says_so(tmp_path):
    (tmp_path / "vendored.toml").write_text('[[package]]\nname = "pkg"\nroot = "vendor/python"\n', encoding="utf-8")
    for rel in ("vendor/python/pkg/a.py", "vendor/python/own.py"):
        (tmp_path / rel).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / rel).write_text("# a circle\n", encoding="utf-8")
    scope = Scope(("vendor/**/*.py",), skip_vendored=True)
    assert scope.files(tmp_path) == ("vendor/python/own.py",)
    assert replace(scope, skip_vendored=False).files(tmp_path) == ("vendor/python/own.py", "vendor/python/pkg/a.py")


def test_findings_are_named_once_in_a_stable_order(tmp_path):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "b.md").write_text("isomorphic to; isomorphic to\n", encoding="utf-8")
    (tmp_path / "docs" / "a.md").write_text("isomorphic to\n", encoding="utf-8")
    rule = ContextRule(Scope(("docs/**/*.md",)), ("isomorphic to",), "{path}: risky")
    assert audit(tmp_path, Policy("t", rules=(rule,))) == ["docs/a.md: risky", "docs/b.md: risky"]


def test_run_reports_and_returns_an_exit_code(tmp_path, capsys):
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "a.md").write_text("isomorphic to\n", encoding="utf-8")
    rule = ContextRule(Scope(("docs/**/*.md",)), ("isomorphic to",), "{path}: risky", context=("not ",))
    assert run(tmp_path, Policy("Terminology audit", rules=(rule,))) == 1
    assert capsys.readouterr().out == "Terminology audit failed:\n- docs/a.md: risky\n"
    (tmp_path / "docs" / "a.md").write_text("not isomorphic to\n", encoding="utf-8")
    assert run(tmp_path, Policy("Terminology audit", rules=(rule,))) == 0
    assert capsys.readouterr().out == "OK: Terminology audit passed: 1 files.\n"


def test_a_malformed_pattern_fails_when_the_policy_is_built():
    with pytest.raises(re.error):
        ClauseRule(Scope(("a",)), "(", "{path}")
    with pytest.raises(ValueError):
        ClauseRule(Scope(("a",)), "x", "{path}", reach=-1)
