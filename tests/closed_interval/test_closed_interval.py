"""The vendorable Python closed_interval package (oracles/closed_interval).

Golden values come from tests/interval/test_interval_q.mojo and the demos in
kernel/finite_exact/closed_q.mojo, so the twin is held to the same pinned
examples as the Mojo layer, and from larsbx/finite-julia-set-research
(tests/test_box_classifier.py, tests/test_scaled.py), whose reference copies
this package replaces.
"""

from __future__ import annotations

import random
from fractions import Fraction as F

import pytest

from closed_interval import (
    DEFAULT_PRECISION,
    IQ,
    ComplexBox,
    ComplexIQ,
    round_down,
    round_interval,
    round_outward,
    round_up,
    scale_for,
    significant_bits,
)

# --- the pinned Mojo examples ------------------------------------------------------


def test_closed_q_demos():
    product = IQ.of(1, 2).mul(IQ.of(3, 5))
    assert (product.lo, product.hi) == (3, 10)
    quadrance = ComplexIQ.singleton(3, 4).quadrance()
    assert (quadrance.lo, quadrance.hi) == (25, 25)


def test_interval_enclosure_laws():
    x, y, z = IQ.of(1, 3), IQ.of(-1, 2), IQ.of(2, 5)
    d = x.sub(x)
    assert (d.lo, d.hi) == (-2, 2) and d.contains_zero()
    assert x.mul(y.add(z)).subset_of(x.mul(y).add(x.mul(z)))
    assert y.square().subset_of(y.mul(y)) and not y.mul(y).subset_of(y.square())
    assert x.excludes_zero() and not y.excludes_zero()


def test_the_complex_square_uses_the_sharp_coordinate_square():
    box = ComplexIQ(IQ.of(F(1, 4), F(1, 2)), IQ.of(F(-1, 4), F(1, 4)))
    sharp, expanded = box.square(), box.mul(box)
    assert (sharp.re.lo, sharp.re.hi) == (0, F(1, 4))
    assert (sharp.im.lo, sharp.im.hi) == (F(-1, 4), F(1, 4))
    assert sharp.subset_of(expanded) and not expanded.subset_of(sharp)
    assert ComplexIQ.singleton(2, 3).square().re.lo == -5


def test_three_valued_sign_and_fail_closed_reciprocal():
    positive, negative = IQ.of(F(1, 2), 3), IQ.of(-3, F(-1, 2))
    straddling, reversed_ = IQ.of(-1, 1), IQ.of(2, 1)
    assert (positive.sign(), negative.sign(), straddling.sign()) == (1, -1, 0)
    assert straddling.reciprocal().rejected and not positive.reciprocal().rejected
    assert (positive.reciprocal().lo, positive.reciprocal().hi) == (F(1, 3), 2)
    assert reversed_.rejected and reversed_.add(positive).rejected and reversed_.sign() is None
    assert not reversed_.contains_zero() and not reversed_.excludes_zero()
    assert IQ.singleton(F(5, 7)).lo == IQ.singleton(F(5, 7)).hi
    assert ComplexIQ.singleton(1, 0).quadrance().lo == 1


def test_bigq_interval_conformance_smoke():
    reversed_, crossing, positive = IQ.of(2, 1), IQ.of(-1, 2), IQ.of(2, 4)
    assert crossing.sign() == 0 and crossing.reciprocal().rejected
    reciprocal = positive.reciprocal()
    assert reciprocal.accepted() and (reciprocal.lo, reciprocal.hi) == (F(1, 4), F(1, 2))
    assert not reversed_.subset_of(positive)
    assert reversed_.mul(positive).rejected


# --- rejection is sticky and never evidence ---------------------------------------------


def test_a_reversed_interval_is_rejected_by_every_constructor():
    assert IQ(F(2), F(1)).rejected and IQ.of(2, 1).rejected
    assert ComplexIQ.of(0, 1, 1, 0).accepted() is False


def test_a_rejected_operand_poisons_every_operation():
    bad, good = IQ.refused(), IQ.of(-1, 2)
    for result in (bad.add(good), good.sub(bad), bad.mul(good), bad.neg(), bad.square(), bad.reciprocal()):
        assert result.rejected
    box, poisoned = ComplexIQ.of(0, 1, 0, 1), ComplexIQ(IQ.refused(), IQ.of(0, 1))
    for result in (box.add(poisoned), poisoned.square(), poisoned.conjugate(), poisoned.reciprocal(), box.mul(poisoned)):
        assert not result.accepted()
    assert poisoned.quarters() == ()
    assert not poisoned.contains_zero() and not poisoned.subset_of(box) and not box.subset_of(poisoned)


def test_width_and_midpoint_of_a_rejected_interval_raise():
    """The Julia copy answered 0 and 1/2, so a refused box looked converged."""
    with pytest.raises(ValueError):
        IQ.refused().width()
    with pytest.raises(ValueError):
        IQ.refused().midpoint()
    with pytest.raises(ValueError):
        ComplexIQ.refused().width()
    with pytest.raises(ValueError):
        ComplexIQ.refused().midpoint()


@pytest.mark.parametrize("bad", [0.5, "1/2", True, None])
def test_inexact_endpoints_are_refused(bad):
    with pytest.raises(TypeError):
        IQ.of(bad, 1)
    with pytest.raises(TypeError):
        round_down(bad)


# --- complex boxes -----------------------------------------------------------------------


def test_complex_box_is_the_julia_name_for_the_same_class():
    assert ComplexBox is ComplexIQ
    assert ComplexBox.singleton(F(1, 3)).im == IQ.singleton(0)


def test_conjugate_and_reciprocal():
    z = ComplexIQ.singleton(3, 4)
    assert z.conjugate() == ComplexIQ.singleton(3, -4)
    w = z.reciprocal()
    assert w == ComplexIQ.singleton(F(3, 25), F(-4, 25))
    assert z.mul(w) == ComplexIQ.singleton(1, 0)
    assert ComplexIQ.of(-1, 1, 2, 3).reciprocal().accepted()
    assert not ComplexIQ.of(-1, 1, -1, 1).reciprocal().accepted()
    assert ComplexIQ.of(-1, 1, -1, 1).contains_zero() and not ComplexIQ.of(-1, 1, 2, 3).contains_zero()


def test_the_box_reciprocal_encloses_every_point_reciprocal():
    rng = random.Random(0xC10)
    for _ in range(200):
        a, b = sorted(F(rng.randint(-20, 20), rng.randint(1, 9)) for _ in range(2))
        c, d = sorted(F(rng.randint(-20, 20), rng.randint(1, 9)) for _ in range(2))
        box = ComplexIQ.of(a, b, c, d)
        inverse = box.reciprocal()
        if not inverse.accepted():
            assert box.quadrance().contains_zero()
            continue
        for x in (a, b, (a + b) / 2):
            for y in (c, d, (c + d) / 2):
                q = x * x + y * y
                assert ComplexIQ.singleton(x / q, -y / q).subset_of(inverse)


def test_quarters_cover_the_box_and_halve_its_width():
    box = ComplexIQ.of(-1, 3, F(1, 2), 2)
    quarters = box.quarters()
    assert len(quarters) == 4 and all(q.subset_of(box) for q in quarters)
    assert {(q.re.lo, q.re.hi, q.im.lo, q.im.hi) for q in quarters} == {
        (-1, 1, F(1, 2), F(5, 4)), (-1, 1, F(5, 4), 2), (1, 3, F(1, 2), F(5, 4)), (1, 3, F(5, 4), 2),
    }
    assert all(q.width() == 2 for q in quarters) and box.width() == 4
    assert box.midpoint() == ComplexIQ.singleton(1, F(5, 4))


def test_the_parabolic_petal_is_invariant_not_strictly():
    """Julia test_box_classifier: z^2 + 1/4 maps the petal into itself, touching its edge."""
    petal = ComplexBox.of(F(1, 4), F(1, 2), F(-1, 4), F(1, 4))
    image = petal.square().add(ComplexBox.singleton(F(1, 4)))
    assert image.subset_of(petal) and not image.strict_subset_of(petal)
    assert not petal.mul(petal).add(ComplexBox.singleton(F(1, 4))).subset_of(petal)


# --- directed dyadic rounding ------------------------------------------------------------


def test_directed_rounding_brackets_and_bounds_the_bits():
    rng = random.Random(0xD1AD1C)
    for _ in range(500):
        x = F(rng.randint(-10**12, 10**12), rng.randint(1, 10**9))
        for precision in (1, 2, 8, 24, DEFAULT_PRECISION):
            down, up = round_down(x, precision), round_up(x, precision)
            assert down <= x <= up
            scale = scale_for(x, precision)
            for r in (down, up):
                assert r.denominator & (r.denominator - 1) == 0
                m = r * F(2) ** scale
                assert m.denominator == 1 and abs(m.numerator) <= 2**precision
            if down != x:
                assert up - down == F(2) ** -scale


def test_significant_bits():
    assert significant_bits(0) == 0 and significant_bits(F(5, 16)) == 3 and significant_bits(-256) == 9


def test_round_down_is_the_largest_dyadic_below():
    assert round_down(F(1, 3), 4) == F(5, 16)
    assert round_up(F(1, 3), 4) == F(3, 8)
    assert round_down(F(-1, 3), 4) == F(-3, 8)
    assert round_down(F(5, 16), 4) == F(5, 16)
    assert round_down(0) == 0 and round_up(0, 3) == 0


def test_a_precision_below_one_means_do_not_round():
    """The Julia convention, kept: the identity is exact and so still sound."""
    assert round_down(F(1, 3), 0) == F(1, 3) and round_up(F(1, 3), -5) == F(1, 3)


def test_rounding_only_ever_widens():
    """Julia test_scaled.test_rounding_only_ever_widens, at precision 8."""
    lo, hi = round_outward(F(1, 3), F(2, 3), 8)
    assert lo <= F(1, 3) and F(2, 3) <= hi
    rounded = round_interval(IQ.of(F(-1, 7), F(1, 7)), 8)
    assert IQ.of(F(-1, 7), F(1, 7)).subset_of(rounded)
    assert round_interval(IQ.refused(), 8).rejected
    with pytest.raises(ValueError):
        round_outward(1, 0)
