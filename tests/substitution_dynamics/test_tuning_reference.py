"""Behavioural tests of the tuning reference model against docs/tuning-substitutions-spec.md.

Every pinned constant here is also asserted by the Mojo test
``tests/substitution_dynamics/test_tuning.mojo``, so the kernels and this oracle agree.
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import tuning_reference as tr  # noqa: E402

PERIOD_DOUBLING = tr.dgp_pattern((1,))
THUE_MORSE = ((0, 1), (1, 0))
FIBONACCI = ((0, 1), (0,))
THREE_LETTER_DEPTH_TWO = ((0, 1), (2, 0), (2, 1))


# --- section 1: patterns, twist, star product ----------------------------------


def test_boundary_rejects_bad_prefixes():
    with pytest.raises(ValueError):
        tr.checked_pattern((), False)
    with pytest.raises(ValueError):
        tr.checked_pattern((0, 2), False)
    assert tr.checked_pattern([1, 0], True) == ((1, 0), True)


def test_period_doubling_is_the_dgp_tuning_of_the_period_two_centre():
    assert PERIOD_DOUBLING == ((1,), True)
    assert tr.period(PERIOD_DOUBLING) == 2
    assert tr.tuning_substitution(PERIOD_DOUBLING) == ((1, 1), (1, 0))


def test_star_product_of_period_doubling_with_itself():
    a2 = tr.star_product(PERIOD_DOUBLING, PERIOD_DOUBLING)
    assert a2 == ((1, 0, 1), False)
    assert tr.period(a2) == 4
    assert tr.tuning_substitution(a2) == ((1, 0, 1, 0), (1, 0, 1, 1))
    assert tr.tuning_substitution(a2) == tr.compose(tr.tuning_substitution(PERIOD_DOUBLING), tr.tuning_substitution(PERIOD_DOUBLING))


def test_feigenbaum_kneading_prefix():
    assert tr.kneading_prefix([PERIOD_DOUBLING]) == (1,)
    assert tr.kneading_prefix([PERIOD_DOUBLING] * 2) == (1, 0, 1)
    assert tr.kneading_prefix([PERIOD_DOUBLING] * 3) == (1, 0, 1, 1, 1, 0, 1)
    assert len(tr.kneading_prefix([PERIOD_DOUBLING] * 5)) == 31
    with pytest.raises(ValueError):
        tr.kneading_prefix([])


def test_star_product_is_composition_for_arbitrary_twists():
    rng = random.Random(20260916)
    for _ in range(300):
        a = tr.checked_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 4))], rng.random() < 0.5)
        b = tr.checked_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 4))], rng.random() < 0.5)
        assert tr.tuning_substitution(tr.star_product(a, b)) == tr.compose(tr.tuning_substitution(a), tr.tuning_substitution(b))
        assert tr.period(tr.star_product(a, b)) == tr.period(a) * tr.period(b)


def test_dgp_parity_is_closed_under_the_star_product():
    rng = random.Random(1978)
    for _ in range(300):
        a = tr.dgp_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 5))])
        b = tr.dgp_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 5))])
        prefix, twist = tr.star_product(a, b)
        assert twist == tr.dgp_twist(prefix)


def test_star_product_is_associative():
    rng = random.Random(3)
    for _ in range(100):
        pats = [tr.checked_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 3))], rng.random() < 0.5) for _ in range(3)]
        a, b, c = pats
        assert tr.star_product(tr.star_product(a, b), c) == tr.star_product(a, tr.star_product(b, c))


# --- section 2: directive prefixes ------------------------------------------------


def test_directive_composite_and_application_agree():
    subs = [tr.tuning_substitution(PERIOD_DOUBLING), THUE_MORSE, ((1, 0), (0, 0))]
    comp = tr.directive_composite(subs)
    for w in ((0,), (1,), (0, 1, 1), (1, 1, 0, 0)):
        assert tr.apply(comp, w) == tr.apply_directive(subs, w)
    with pytest.raises(ValueError):
        tr.compose(THUE_MORSE, ((0, 1, 2), (0,), (1,)))
    with pytest.raises(ValueError):
        tr.directive_composite([])
    with pytest.raises(ValueError):
        tr.apply_directive([], (0, 1))


def test_kneading_prefix_is_a_prefix_of_every_tuning_image():
    rng = random.Random(7)
    for _ in range(50):
        pats = [tr.dgp_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 3))]) for _ in range(rng.randint(1, 4))]
        prefix = tr.kneading_prefix(pats)
        comp = tr.directive_composite([tr.tuning_substitution(p) for p in pats])
        for s in (0, 1):
            assert comp[s][: len(prefix)] == prefix
            assert len(comp[s]) == len(prefix) + 1


# --- section 3: column coincidence ------------------------------------------------


def test_every_tuning_substitution_has_a_coincidence_in_its_first_column():
    rng = random.Random(11)
    for _ in range(100):
        p = tr.checked_pattern([rng.randint(0, 1) for _ in range(rng.randint(1, 5))], rng.random() < 0.5)
        assert tr.column_coincidence(tr.tuning_substitution(p)) == (1, (0,))


def test_thue_morse_has_no_column_coincidence():
    assert tr.column_coincidence(THUE_MORSE) is None


def test_three_letter_example_needs_depth_two():
    assert tr.column_coincidence(THREE_LETTER_DEPTH_TWO) == (2, (0, 1))
    assert tr.column_coincidence(((0,),)) == (0, ())


def test_non_constant_length_is_rejected():
    assert tr.constant_length(FIBONACCI) is None
    with pytest.raises(ValueError):
        tr.column_coincidence(FIBONACCI)
    with pytest.raises(ValueError):
        tr.column_coincidence(tuple((0,) for _ in range(tr.MAX_COINCIDENCE_ALPHABET + 1)))
