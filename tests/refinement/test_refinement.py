"""The refinement facility: a declaration that can fail in both directions.

`docs/generator-refinement-spec.md`. Every test here is a negative control for
the facility itself, because a checker of corpora that accepted every corpus
would be exactly the instrument this repository already paid for lacking.
"""

from __future__ import annotations

import sys
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import property_oracle as po  # noqa: E402
from refinement import Class, Refinement, audit_all  # noqa: E402

INTEGERS = Refinement(
    "draw",
    "an integer",
    lambda v: isinstance(v, int),
    (
        Class("zero", lambda v: v == 0),
        Class("negative", lambda v: v < 0),
        Class("beyond a million", lambda v: abs(v) > 10**6, reason="the window stops at a thousand"),
    ),
)


# --- the two directions ------------------------------------------------------------


def test_a_corpus_that_meets_the_declaration_says_nothing():
    assert INTEGERS.audit([0, -1, 5]) == ()


def test_a_class_declared_reached_and_never_drawn_is_named():
    problems = INTEGERS.audit([1, 2, 3])
    assert [p.split(" and ")[0] for p in problems] == ["draw declares it reaches 'zero'", "draw declares it reaches 'negative'"]


def test_a_class_declared_missed_and_then_drawn_is_named():
    """The other direction, which keeps a declaration from rotting: the corpus
    grew past what the declaration says, and the declaration must be revised."""
    problems = INTEGERS.audit([0, -1, 10**9])
    assert len(problems) == 1
    assert "declares it misses 'beyond a million' (the window stops at a thousand) and a draw does" in problems[0]


def test_a_value_outside_the_codomain_is_named_with_examples():
    problems = INTEGERS.audit([0, -1, "x", 2.5], examples=2)
    assert problems[0] == "draw produces a value outside its codomain (an integer): 'x', 2.5"


def test_a_class_is_only_asked_about_values_that_reached_the_codomain():
    """`negative` would raise on a string, so an escapee is reported and then
    left out: one malformed draw must not turn every class into an error."""
    assert INTEGERS.audit([0, -1, "x"]) == ("draw produces a value outside its codomain (an integer): 'x'",)


def test_an_empty_corpus_fails_every_required_class():
    assert len(INTEGERS.audit([])) == 2


def test_audit_all_names_every_generator_in_one_pass():
    other = Refinement("other", "an integer", lambda v: isinstance(v, int), (Class("large", lambda v: v > 10**6),))
    problems = audit_all([(INTEGERS, [1]), (other, [1])])
    assert len(problems) == 3 and problems[-1].startswith("other declares it reaches 'large'")


def test_reached_and_missed_partition_the_classes():
    assert INTEGERS.reached() == ("zero", "negative")
    assert INTEGERS.missed() == ("beyond a million",)
    assert len(INTEGERS.reached()) + len(INTEGERS.missed()) == len(INTEGERS.classes)


# --- the declarations this repository ships ----------------------------------------


def test_the_property_probe_corpus_meets_its_declaration():
    assert po.distribution_problems() == ()
    assert po.distribution_problems(0) == ()


def test_the_interval_layer_is_not_asserted_against_a_corpus_it_never_draws():
    """`finite_exact` prints no interval case, so INTERVAL has nothing to judge
    and is not counted as unmet; `interval_q` runs the layer and it is."""
    assert po.declared(0) == (po.INTEGER, po.FRACTION)
    assert po.declared(po.I_CASES) == po.REFINEMENTS


def test_every_missed_class_states_the_branch_it_leaves_unexercised():
    """A gap is declared, not dismissed: each one says what goes untested."""
    for refinement in po.REFINEMENTS:
        for cls in refinement.classes:
            if not cls.required:
                assert len(cls.reason) > 40, (refinement.name, cls.name)


def test_the_probe_stream_still_misses_zero_and_the_unit():
    """Pinned because these are the gaps the declaration exists to record: if a
    change to the stream closes one, this fails and the declaration is revised
    rather than quietly kept."""
    draws = po.drawn(0)
    integers, fractions = draws.integers, draws.fractions
    assert not any(v == 0 for v in integers) and not any(abs(v) == 1 for v in integers)
    assert not any(f == 0 for f in fractions) and not any(f.denominator == 1 for f in fractions)
    assert any(abs(v) >= 1 << 63 for v in integers)


def test_a_generator_is_judged_on_every_call_not_only_the_printed_operands():
    """A fraction draws two integers and an interval draws two fractions. Judging
    `random_int` on the Z operands alone would audit it on a third of its own
    output, and a declaration the rest of the corpus contradicts would pass."""
    draws = po.drawn(po.I_CASES)
    printed = 2 * po.Z_CASES
    assert len(draws.integers) > printed
    # Every fraction contributes two integer draws, every interval two fractions.
    assert len(draws.integers) == printed + 2 * len(draws.fractions)
    assert len(draws.fractions) == 2 * po.Q_CASES + 2 * len(draws.intervals)


def test_the_declared_magnitude_bound_is_part_of_the_codomain():
    """The codomain names a limb count, so a draw past it must escape rather
    than pass because it happens to satisfy the named classes."""
    seventh_limb = po.BASE ** po.MAX_LIMBS
    problems = po.INTEGER.audit([0, -1, 10**3, 1 << 63, po.BASE - 1, seventh_limb])
    assert problems and "outside its codomain" in problems[0]
    assert po.INTEGER.holds(seventh_limb - 1) and not po.INTEGER.holds(seventh_limb)
    assert not po.FRACTION.holds(Fraction(seventh_limb, 1))
    assert not po.INTERVAL.holds((Fraction(0), Fraction(seventh_limb)))
