"""Executable laws for the projective package.

Run with `pixi run test-projective`
(`mojo run -I . tests/projective/test_projective.mojo`).

The laws are the three facts the lift is worth having for: infinity is fixed
by the algebra, the lift agrees with the affine map where both are defined,
and the chart at infinity conjugates one to the other. The rest is domains:
a chart is a division and refuses where it must.
"""

from finite_exact.closed_interval import ComplexIQ, IQ
from finite_exact.rat_q import Q
from projective.chart import (
    affine_value,
    chart_at_infinity,
    chart_step,
    complex_reciprocal,
    in_affine_chart,
    in_chart_at_infinity,
)
from projective.homogeneous import (
    Homogeneous,
    at_infinity,
    degenerate,
    embed,
    homogeneous,
    infinity,
    quadratic_lift,
    separated_classes,
    unit_box,
    zero_box,
)
from quadratic_orbit.orbit import quadratic_step


def point(re_num: Int64, re_den: Int64, im_num: Int64, im_den: Int64) -> ComplexIQ:
    return ComplexIQ.singleton(Q(re_num, re_den), Q(im_num, im_den))


def same(a: ComplexIQ, b: ComplexIQ) -> Bool:
    if not (a.accepted() and b.accepted()):
        return False
    return a.re.lo.eq(b.re.lo) and a.re.hi.eq(b.re.hi) and a.im.lo.eq(b.im.lo) and a.im.hi.eq(b.im.hi)


def test_infinity_is_fixed_by_the_algebra() -> Bool:
    """`F([1 : 0]) = [1 : 0]`, with no limit and no special case."""
    var c = point(-1, 1, 0, 1)
    var image = quadratic_lift(infinity(), c)
    var fixed = at_infinity(image)
    return fixed.value and not fixed.rejected and same(image.w, zero_box())


def test_the_lift_agrees_with_the_affine_map() -> Bool:
    """`F([z : 1]) = [z^2 + c : 1]`, so the affine plane sits inside unchanged."""
    var c = point(0, 1, 1, 1)
    var z = point(1, 3, -2, 5)
    var lifted = quadratic_lift(embed(z), c)
    return same(lifted.z, quadratic_step(z, c)) and same(lifted.w, unit_box())


def test_the_lift_has_no_base_point() -> Bool:
    """A class in, a class out: the two forms never vanish together."""
    var c = point(-2, 1, 0, 1)
    var cases = 0
    if not degenerate(quadratic_lift(infinity(), c)).value:
        cases += 1
    if not degenerate(quadratic_lift(embed(zero_box()), c)).value:
        cases += 1
    if not degenerate(quadratic_lift(homogeneous(point(0, 1, 0, 1), point(3, 1, 0, 1)), c)).value:
        cases += 1
    return cases == 3


def test_scaling_a_pair_keeps_the_class() -> Bool:
    """`[z : w]` and `[2z : 2w]` are one class; `[1 : 0]` and `[0 : 1]` are not."""
    var p = homogeneous(point(1, 2, 1, 3), point(1, 1, 0, 1))
    var scaled = homogeneous(point(1, 1, 2, 3), point(2, 1, 0, 1))
    var scaled_result = separated_classes(p, scaled)
    var apart = separated_classes(infinity(), embed(zero_box()))
    return (not scaled_result.value) and (not scaled_result.rejected) and apart.value and not apart.rejected


def test_the_charts_have_domains() -> Bool:
    """Infinity is outside the affine chart; the origin is outside the other."""
    var origin = embed(zero_box())
    var infinite = infinity()
    var origin_in_infinity_chart = in_chart_at_infinity(origin)
    var infinity_in_affine_chart = in_affine_chart(infinite)
    return (
        in_affine_chart(origin).value and
        in_chart_at_infinity(infinite).value and
        not origin_in_infinity_chart.value and
        not infinity_in_affine_chart.value
    )


def test_a_box_straddling_the_origin_leaves_the_chart() -> Bool:
    """A straddling box is refused, not evaluated: the reciprocal rejects."""
    var straddling = ComplexIQ(IQ(Q(-1, 1), Q(1, 1)), IQ(Q(-1, 1), Q(1, 1)))
    var refused = complex_reciprocal(straddling)
    var accepted = complex_reciprocal(point(2, 1, 0, 1))
    return (not refused.accepted()) and accepted.accepted() and same(accepted, point(1, 2, 0, 1))


def test_infinity_is_the_origin_of_its_chart() -> Bool:
    """`[1 : 0]` has value zero in the chart centred on it."""
    return same(chart_at_infinity(infinity()), zero_box())


def test_the_chart_inverts_the_affine_value() -> Bool:
    """`w / z` at `[z : 1]` is `1 / z`."""
    var z = point(2, 1, 0, 1)
    return same(chart_at_infinity(embed(z)), point(1, 2, 0, 1)) and same(affine_value(embed(z)), z)


def test_the_chart_conjugates_the_map() -> Bool:
    """`u -> u^2 / (1 + c u^2)` at `u = 1/z` is `1 / (z^2 + c)`."""
    var c = point(-1, 1, 0, 1)
    var z = point(2, 1, 0, 1)
    var stepped_then_inverted = complex_reciprocal(quadratic_step(z, c))
    var inverted_then_stepped = chart_step(complex_reciprocal(z), c)
    return same(stepped_then_inverted, point(1, 3, 0, 1)) and same(inverted_then_stepped, point(1, 3, 0, 1))


def test_zero_is_fixed_in_the_chart_at_infinity() -> Bool:
    """The image of the origin is the origin, which is the superattraction."""
    var c = point(-1, 1, 0, 1)
    return same(chart_step(zero_box(), c), zero_box())


def main() raises:
    if not test_infinity_is_fixed_by_the_algebra():
        raise Error("the lift does not fix infinity")
    if not test_the_lift_agrees_with_the_affine_map():
        raise Error("the lift disagrees with the affine map")
    if not test_the_lift_has_no_base_point():
        raise Error("the lift produced a degenerate pair")
    if not test_scaling_a_pair_keeps_the_class():
        raise Error("class equality is wrong under scaling")
    if not test_the_charts_have_domains():
        raise Error("a chart accepted a class outside it")
    if not test_a_box_straddling_the_origin_leaves_the_chart():
        raise Error("a straddling box was evaluated instead of refused")
    if not test_infinity_is_the_origin_of_its_chart():
        raise Error("infinity is not the origin of its own chart")
    if not test_the_chart_inverts_the_affine_value():
        raise Error("the chart does not invert")
    if not test_the_chart_conjugates_the_map():
        raise Error("the chart does not conjugate the map")
    if not test_zero_is_fixed_in_the_chart_at_infinity():
        raise Error("zero is not fixed in the chart at infinity")
    print("projective laws passed.")
