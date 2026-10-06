"""The vendorable Python root_isolation package (oracles/root_isolation_py).

Specification: docs/root-isolation-spec.md. Known roots -- square roots,
roots of unity, periodic points of the quadratic family, a two-variable
system -- are isolated, and the refusals of section 6 are values. The maps
are evaluated here, by the test, because the package never evaluates one.
"""

from __future__ import annotations

from fractions import Fraction as F
from math import floor

import pytest

from closed_interval import ComplexIQ
from root_isolation_py import (
    centre,
    disjoint,
    exact_inverse,
    excludes_zero,
    krawczyk,
    krawczyk_image,
    midpoint_inverse,
    strictly_inside,
)

ONE = ComplexIQ.singleton(1)
REFUSED = ComplexIQ.refused()


def box(re, im, radius) -> ComplexIQ:
    re, im, radius = F(re), F(im), F(radius)
    return ComplexIQ.of(re - radius, re + radius, im - radius, im + radius)


def horner(coefficients, z: ComplexIQ) -> ComplexIQ:
    """Ascending rational coefficients, evaluated on a box by Horner."""
    value = ComplexIQ.singleton(0)
    for a in reversed(coefficients):
        value = value.mul(z).add(ComplexIQ.singleton(a))
    return value


def derivative(coefficients):
    return [k * a for k, a in enumerate(coefficients)][1:]


def polynomial(coefficients):
    """`(at_centre, over_box)` for a one-variable polynomial."""
    slope = derivative(coefficients)
    return (
        lambda m: ((horner(coefficients, m[0]),), ((horner(slope, m[0]),),)),
        lambda x: ((horner(slope, x[0]),),),
    )


def isolates(coefficients, x: ComplexIQ, **policy) -> bool:
    return strictly_inside(krawczyk((x,), *polynomial(coefficients), **policy), (x,))


# --- section 1: centre and preconditioners -----------------------------------------------


def test_the_centre_is_exact_and_a_rejected_box_has_none():
    assert centre((ComplexIQ.of(F(1, 3), F(1, 2), -1, 0),)) == (ComplexIQ.singleton(F(5, 12), F(-1, 2)),)
    assert not centre((REFUSED,))[0].accepted()


def test_the_exact_inverse_of_a_point_is_exact_in_one_and_two_variables():
    w = ComplexIQ.singleton(3, 4)
    assert exact_inverse(((w,),)) == ((ComplexIQ.singleton(F(3, 25), F(-4, 25)),),)
    a, b, c, d = (ComplexIQ.singleton(*p) for p in ((1, 1), (2, 0), (0, 1), (3, -1)))
    inverse = exact_inverse(((a, b), (c, d)))
    product = tuple(
        tuple(inverse[i][0].mul(m[0]).add(inverse[i][1].mul(m[1])) for m in ((a, c), (b, d))) for i in range(2)
    )
    assert product == ((ONE, ComplexIQ.singleton(0)), (ComplexIQ.singleton(0), ONE))


def test_the_exact_inverse_refuses_a_box_a_zero_and_a_rejection():
    for entry in (ComplexIQ.of(1, 2, 0, 0), ComplexIQ.singleton(0), REFUSED):
        assert not exact_inverse(((entry,),))[0][0].accepted()
    singular = ((ONE, ONE), (ONE, ONE))
    assert not any(e.accepted() for row in exact_inverse(singular) for e in row)


def test_the_midpoint_inverse_takes_centres_and_rounds_where_asked():
    w = ComplexIQ.of(2, 4, -1, 1)  # centre 3
    assert midpoint_inverse(((w,),)) == ((ComplexIQ.singleton(F(1, 3)),),)
    floor8 = lambda x: F(floor(x * 256), 256)
    assert midpoint_inverse(((w,),), floor8) == ((ComplexIQ.singleton(F(85, 256)),),)
    assert not midpoint_inverse(((ComplexIQ.of(-1, 1, 0, 0),),))[0][0].accepted()


def test_the_two_variable_midpoint_inverse_is_the_adjugate_over_a_rounded_determinant():
    floor4 = lambda x: F(floor(x * 16), 16)
    m = ((ComplexIQ.singleton(1), ComplexIQ.singleton(2)), (ComplexIQ.singleton(3), ComplexIQ.singleton(7)))
    d = floor4(F(1, 1))  # det = 1
    assert midpoint_inverse(m, floor4) == (
        (ComplexIQ.singleton(7 * d), ComplexIQ.singleton(-2 * d)),
        (ComplexIQ.singleton(-3 * d), ComplexIQ.singleton(d)),
    )
    assert midpoint_inverse(m) == exact_inverse(m)


def test_malformed_shapes_are_programming_errors():
    three = tuple(tuple(ONE for _ in range(3)) for _ in range(3))
    with pytest.raises(ValueError):
        exact_inverse(three)
    with pytest.raises(ValueError):
        exact_inverse(((ONE, ONE),))
    with pytest.raises(ValueError):
        krawczyk_image((ONE,), (ONE,), ((ONE,),), (ONE, ONE), ((ONE,),))


@pytest.mark.parametrize("n", [0, 3])
def test_the_isolation_test_refuses_a_dimension_other_than_one_or_two(n):
    # all() over no coordinates is vacuously true: an empty box must not isolate.
    box = tuple(ComplexIQ.of(0, 1, 0, 1) for _ in range(n))
    with pytest.raises(ValueError):
        strictly_inside(box, box)


# --- sections 2-4: known roots -----------------------------------------------------------


def test_the_square_root_of_two_is_isolated_and_zero_is_excluded():
    p = [-2, 0, 1]
    assert isolates(p, box(F(17, 12), 0, F(1, 16)))
    assert isolates(p, box(F(-17, 12), 0, F(1, 16)))
    assert excludes_zero((horner(p, box(0, 0, F(1, 8))),))
    assert not isolates(p, box(0, 0, F(1, 8)))  # derivative 0 at the centre: refused, not false-positive


def test_a_box_holding_both_roots_is_not_isolating():
    assert not isolates([-2, 0, 1], ComplexIQ.of(-2, 3, -1, 1))


@pytest.mark.parametrize("q, radius, approx", [
    (4, F(1, 64), [(1, 0), (0, 1), (-1, 0), (0, -1)]),
    (3, F(1, 64), [(1, 0), (F(-1, 2), F(433, 500)), (F(-1, 2), F(-433, 500))]),
    (8, F(1, 4096), [(1, 0), (F(7071, 10000), F(7071, 10000)), (0, 1), (F(-7071, 10000), F(7071, 10000)),
         (-1, 0), (F(-7071, 10000), F(-7071, 10000)), (0, -1), (F(7071, 10000), F(-7071, 10000))]),
])
def test_the_roots_of_unity_are_isolated_in_pairwise_disjoint_boxes(q, radius, approx):
    """`q` disjoint isolating boxes for the degree-`q` polynomial `X^q - 1`
    account for all of its roots (spec section 3)."""
    p = [-1] + [0] * (q - 1) + [1]
    boxes = [box(re, im, radius) for re, im in approx]
    assert all(isolates(p, b) for b in boxes)
    assert all(disjoint((a,), (b,)) for i, a in enumerate(boxes) for b in boxes[i + 1:])


def test_the_periodic_points_of_the_quadratic_family_are_isolated():
    """`R(z) = f_c^2(z) - z` at `c = -1`: the fixed points `(1 +- sqrt 5)/2` and
    the 2-cycle `{0, -1}`, all simple, with the iterate evaluated on the box."""

    def f(z, c):
        return z.square().add(c)

    c = ComplexIQ.singleton(-1)

    def at_centre(m):
        z = m[0]
        return (f(f(z, c), c).sub(z),), ((ONE.add(ONE).mul(z).mul(ONE.add(ONE).mul(f(z, c))).sub(ONE),),)

    def over_box(x):
        return at_centre(x)[1]

    for root in (F(161803, 100000), F(-61803, 100000), 0, -1):
        x = box(root, 0, F(1, 32))
        assert strictly_inside(krawczyk((x,), at_centre, over_box), (x,))


def test_the_mandelbrot_witness_at_minus_two_is_reproduced():
    """`P(C) = C^2 + 2C` on the box of half-width `2^-8` at `-2`, with the
    preconditioner `-1/2` that Mandelbrot's krawczyk_witness.mojo hard-codes."""
    x = box(-2, 0, F(1, 256))
    p = [0, 2, 1]
    (m,) = centre((x,))
    (row,) = exact_inverse(((horner(derivative(p), m),),))
    assert row == (ComplexIQ.singleton(F(-1, 2)),)
    image = krawczyk_image((x,), (m,), (row,), (horner(p, m),), ((horner(derivative(p), x),),))
    assert strictly_inside(image, (x,))


def test_a_two_variable_system_is_isolated_at_each_root_and_not_across_them():
    """`(z + w - 3, z w - 2)` has the simple roots `(1, 2)` and `(2, 1)`."""

    def at(v):
        z, w = v
        value = (z.add(w).sub(ComplexIQ.singleton(3)), z.mul(w).sub(ComplexIQ.singleton(2)))
        return value, ((ONE, ONE), (w, z))

    for root in ((1, 2), (2, 1)):
        x = tuple(box(r, 0, F(1, 8)) for r in root)
        assert strictly_inside(krawczyk(x, at, lambda v: at(v)[1]), x)
        assert strictly_inside(krawczyk(x, at, lambda v: at(v)[1], invert=midpoint_inverse), x)
    across = (box(F(3, 2), 0, 1), box(F(3, 2), 0, 1))
    assert not strictly_inside(krawczyk(across, at, lambda v: at(v)[1]), across)


# --- section 5: rounding hooks ------------------------------------------------------------


def test_rounding_the_preconditioner_and_the_image_keeps_the_certificate():
    grid = 2 ** 20
    down = lambda x: F(floor(x * grid), grid)
    outward = lambda z: ComplexIQ.of(down(z.re.lo), -down(-z.re.hi), down(z.im.lo), -down(-z.im.hi))
    invert = lambda j: midpoint_inverse(j, down)
    assert isolates([-2, 0, 1], box(F(17, 12), 0, F(1, 16)), invert=invert, outward=outward)


def test_an_outward_hook_that_widens_too_far_loses_the_certificate_and_nothing_else():
    wide = lambda z: ComplexIQ.of(z.re.lo - 1, z.re.hi + 1, z.im.lo, z.im.hi)
    assert not isolates([-2, 0, 1], box(F(17, 12), 0, F(1, 16)), outward=wide)


# --- section 6: refusals -------------------------------------------------------------------


def test_rejections_poison_the_image_and_every_test_answers_false():
    x = (box(F(17, 12), 0, F(1, 16)),)
    assert not krawczyk_image(x, x, ((REFUSED,),), (ONE,), ((ONE,),))[0].accepted()
    assert not strictly_inside((REFUSED,), x)
    assert not strictly_inside(x, (REFUSED,))
    assert not excludes_zero((REFUSED,))
    assert not excludes_zero((ComplexIQ.singleton(1), REFUSED))
    assert not disjoint((REFUSED,), x)


def test_strictness_is_required_in_every_real_coordinate():
    x = (ComplexIQ.of(0, 1, 0, 1),)
    assert strictly_inside((ComplexIQ.of(F(1, 4), F(3, 4), F(1, 4), F(3, 4)),), x)
    assert not strictly_inside((ComplexIQ.of(0, F(3, 4), F(1, 4), F(3, 4)),), x)
    assert not strictly_inside((ComplexIQ.of(F(1, 4), F(3, 4), F(1, 4), 1),), x)
    assert not strictly_inside(x, x)


def test_a_degenerate_box_never_isolates():
    assert not isolates([-2, 0, 1], ComplexIQ.of(F(1, 2), 2, 0, 0))


def test_exclusion_needs_only_one_coordinate_to_miss_zero():
    assert excludes_zero((ComplexIQ.of(-1, 1, -1, 1), ComplexIQ.of(-1, 1, 1, 2)))
    assert not excludes_zero((ComplexIQ.of(-1, 1, -1, 1), ComplexIQ.of(-1, 1, 0, 2)))
    assert excludes_zero((ComplexIQ.of(1, 2, -1, 1),))


def test_disjointness_is_strict_separation_in_some_real_coordinate():
    a = (ComplexIQ.of(0, 1, 0, 1),)
    assert disjoint(a, (ComplexIQ.of(F(3, 2), 2, 0, 1),))
    assert disjoint(a, (ComplexIQ.of(0, 1, F(3, 2), 2),))
    assert not disjoint(a, (ComplexIQ.of(1, 2, 0, 1),))  # touching closed boxes share a point
    assert disjoint((ONE, ONE), (ONE, ComplexIQ.singleton(2)))
