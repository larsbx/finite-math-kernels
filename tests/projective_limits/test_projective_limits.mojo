"""Executable laws for projective_limits.

Run with `pixi run test-projective-limits`.
"""

from std.testing import assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_from_i64
from finite_exact.rat_q import Q, q_from_bigz
from projective_limits.line import (
    P1,
    chordal_distance_squared,
    mobius,
    mobius_apply,
    mobius_compose,
    p1,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_is_infinity,
)
from projective_limits.limits import (
    Poly,
    Poly2,
    RationalMap,
    asymptote,
    curve_limit,
    directional_limit,
    landing,
    path_dependence_witness,
    poly_i64,
    poly2_monomial,
    poly2_sum,
    rational_limit,
    tangent_slope,
)
from rational_dynamics.rational import continued_fraction, convergents, fraction_from_i64


def q(n: Int64, d: Int64 = 1) -> Q:
    return Q(n, d)


def integer(n: BigZ) -> Q:
    return q_from_bigz(n, bigz_from_i64(1))


def at(n: Int64, d: Int64 = 1) -> P1:
    return p1_affine(q(n, d))


def ratmap(num: Poly, den: Poly) -> RationalMap:
    return RationalMap(num, den)


# Section 1: P^1 and its charts.


def test_homogeneous_normal_form() raises:
    assert_true(p1_equal(p1(q(2), q(4)), at(1, 2)))
    assert_true(p1_equal(p1(q(-3), q(0)), p1_infinity()))
    assert_true(p1_is_infinity(p1(q(5), q(0))))
    assert_false(p1(q(0), q(0)).accepted())
    # One unsigned infinity: [1:0] = [-1:0].
    assert_true(p1_equal(p1(q(1), q(0)), p1(q(-1), q(0))))


# Section 2: rational functions are continuous maps P^1 -> P^1.


def test_continuity_at_regular_points() raises:
    # (x^2 + 1)/(x - 2) at x = 3 is 10.
    var f = ratmap(poly_i64([1, 0, 1]), poly_i64([-2, 1]))
    assert_true(p1_equal(rational_limit(f, at(3)), at(10)))


def test_pole_is_continuity_into_infinity() raises:
    var f = ratmap(poly_i64([1]), poly_i64([0, 1]))  # 1/x
    assert_true(p1_is_infinity(rational_limit(f, at(0))))
    assert_true(p1_equal(rational_limit(f, p1_infinity()), at(0)))


def test_degree_rule_at_infinity() raises:
    # m < n, m = n, m > n.
    var below = ratmap(poly_i64([1, 1]), poly_i64([0, 0, 1]))
    var equal = ratmap(poly_i64([7, 0, 3]), poly_i64([1, 5, 2]))
    var above = ratmap(poly_i64([0, 0, 0, 1]), poly_i64([1, 1]))
    assert_true(p1_equal(rational_limit(below, p1_infinity()), at(0)))
    assert_true(p1_equal(rational_limit(equal, p1_infinity()), at(3, 2)))
    assert_true(p1_is_infinity(rational_limit(above, p1_infinity())))


def test_infinity_maps_through_finite_image() raises:
    # (2x + 1)/(x - 1) sends 1 -> infinity and infinity -> 2.
    var f = ratmap(poly_i64([1, 2]), poly_i64([-1, 1]))
    assert_true(p1_is_infinity(rational_limit(f, at(1))))
    assert_true(p1_equal(rational_limit(f, p1_infinity()), at(2)))


# Section 3: the chordal metric, exactly squared.


def test_chordal_distance_squared() raises:
    # chi(0, inf) = 2, chi(0, 1) = sqrt 2, chi(z, inf) = 2/sqrt(1 + z^2).
    assert_true(chordal_distance_squared(at(0), p1_infinity()).eq(q(4)))
    assert_true(chordal_distance_squared(at(0), at(1)).eq(q(2)))
    assert_true(chordal_distance_squared(at(3), p1_infinity()).eq(q(4, 10)))
    assert_true(chordal_distance_squared(at(5, 7), at(5, 7)).eq(q(0)))
    # Symmetric and invariant under the rotation z -> -1/z.
    var flip = mobius(q(0), q(-1), q(1), q(0))
    var a = at(2, 3)
    var b = at(-5)
    assert_true(chordal_distance_squared(a, b).eq(chordal_distance_squared(b, a)))
    assert_true(
        chordal_distance_squared(a, b).eq(
            chordal_distance_squared(mobius_apply(flip, a), mobius_apply(flip, b))
        )
    )


# Section 4: derivatives in the pencil of lines.


def test_tangent_slope_smooth_vertical_and_cusp() raises:
    # Graph of x^3 at t = 2: slope 12.
    assert_true(p1_equal(tangent_slope(poly_i64([0, 1]), poly_i64([0, 0, 0, 1]), q(2)), at(12)))
    # Graph of x^2 at t = 0: slope 0 (a vanishing derivative is a finite slope).
    assert_true(p1_equal(tangent_slope(poly_i64([0, 1]), poly_i64([0, 0, 1]), q(0)), at(0)))
    # (t^3, t): the curve x = y^3 has a vertical tangent at the origin.
    assert_true(p1_is_infinity(tangent_slope(poly_i64([0, 0, 0, 1]), poly_i64([0, 1]), q(0))))
    # Cusp (t^2, t^3): the secants still converge in the pencil, to slope 0.
    assert_true(p1_equal(tangent_slope(poly_i64([0, 0, 1]), poly_i64([0, 0, 0, 1]), q(0)), at(0)))
    # Semicubical cusp turned on its side (t^3, t^2): vertical tangent.
    assert_true(p1_is_infinity(tangent_slope(poly_i64([0, 0, 0, 1]), poly_i64([0, 0, 1]), q(0))))


# Section 5: asymptotes as tangents at points at infinity.


def test_oblique_and_horizontal_asymptotes() raises:
    # (x^2 + 1)/(x - 1) = x + 1 + 2/(x - 1): asymptote y = x + 1.
    var oblique = asymptote(ratmap(poly_i64([1, 0, 1]), poly_i64([-1, 1])))
    assert_true(p1_equal(oblique.slope, at(1)))
    assert_true(p1_equal(oblique.intercept, at(1)))
    # (3x + 2)/(x + 5): asymptote y = 3.
    var horizontal = asymptote(ratmap(poly_i64([2, 3]), poly_i64([5, 1])))
    assert_true(p1_equal(horizontal.slope, at(0)))
    assert_true(p1_equal(horizontal.intercept, at(3)))
    # x^3/(x + 1): the branch at infinity is vertical in the pencil; no line.
    var none = asymptote(ratmap(poly_i64([0, 0, 0, 1]), poly_i64([1, 1])))
    assert_true(p1_is_infinity(none.slope))
    assert_false(none.intercept.accepted())


# Section 6: indeterminate forms resolved on the exceptional divisor.


def test_landing_is_lhopital() raises:
    # (x^2 - 1)/(x - 1) at 1 lands at 2.
    var f = ratmap(poly_i64([-1, 0, 1]), poly_i64([-1, 1]))
    assert_true(p1_equal(rational_limit(f, at(1)), at(2)))
    # (x^3 - 3x + 2)/(x^2 - 2x + 1) = (x + 2)(x - 1)^2/(x - 1)^2 -> 3 at 1.
    var g = ratmap(poly_i64([2, -3, 0, 1]), poly_i64([1, -2, 1]))
    assert_true(p1_equal(rational_limit(g, at(1)), at(3)))
    # landing reads the lowest nonvanishing order: s^2/s^3 -> infinity.
    assert_true(p1_is_infinity(landing(poly_i64([0, 0, 1]), poly_i64([0, 0, 0, 1]))))
    assert_false(landing(poly_i64([0]), poly_i64([0])).accepted())


def test_cancellation_law() raises:
    # For every common factor r with r(a) = 0: lim (p r)/(q r) at a = p(a)/q(a).
    var p = poly_i64([3, -1, 2])
    var qq = poly_i64([1, 4])
    var r = poly_i64([-6, 5, -1])  # (x - 2)(3 - x)
    var f = ratmap(p.mul(r), qq.mul(r))
    var plain = ratmap(p, qq)
    assert_true(p1_equal(rational_limit(f, at(2)), rational_limit(plain, at(2))))
    assert_true(p1_equal(rational_limit(f, at(3)), rational_limit(plain, at(3))))


def test_cancellation_sweep_against_evaluation() raises:
    # Oracle: plain evaluation [p(a) : q(a)], valid whenever (p(a), q(a)) != (0, 0).
    var family = List[Poly]()
    family.append(poly_i64([1]))
    family.append(poly_i64([0, 1]))
    family.append(poly_i64([2, -1, 1]))
    family.append(poly_i64([-3, 0, 0, 2]))
    var checked = 0
    for root in range(-3, 4):
        var a = q(Int64(root))
        var factor = poly_i64([-root, 1])
        for multiplicity in range(1, 3):
            var r = factor.pow(multiplicity)
            for i in range(len(family)):
                for j in range(len(family)):
                    var pa = family[i].eval(a)
                    var qa = family[j].eval(a)
                    if pa.num.is_zero() and qa.num.is_zero():
                        continue
                    var lifted = ratmap(family[i].mul(r), family[j].mul(r))
                    assert_true(p1_equal(rational_limit(lifted, p1_affine(a)), p1(pa, qa)))
                    checked += 1
    assert_true(checked > 200)


def xy_over_x2_plus_y2() -> Poly2:
    return poly2_monomial(1, 1, q(1))


def x2_plus_y2() -> Poly2:
    return poly2_sum(poly2_monomial(2, 0, q(1)), poly2_monomial(0, 2, q(1)))


def test_directional_limits_on_the_divisor() raises:
    # g = xy/(x^2 + y^2) restricts to ab/(a^2 + b^2) on E.
    var num = xy_over_x2_plus_y2()
    var den = x2_plus_y2()
    assert_true(p1_equal(directional_limit(num, den, p1_infinity()), at(0)))  # x-axis [1:0]
    assert_true(p1_equal(directional_limit(num, den, at(1)), at(1, 2)))  # diagonal
    assert_true(p1_equal(directional_limit(num, den, at(-1)), at(-1, 2)))
    # Direction is a point of P^1: rescaling [a:b] changes nothing.
    assert_true(p1_equal(directional_limit(num, den, p1(q(3), q(3))), at(1, 2)))


def test_path_dependence_witness_certifies_nonexistence() raises:
    var witness = path_dependence_witness(xy_over_x2_plus_y2(), x2_plus_y2(), 4)
    assert_true(witness.found)
    assert_false(p1_equal(witness.first_limit, witness.second_limit))
    # x^2 y/(x^2 + y^2) -> 0 on every line: no witness among lines.
    var tame = path_dependence_witness(poly2_monomial(2, 1, q(1)), x2_plus_y2(), 6)
    assert_false(tame.found)


def test_second_blow_up_along_a_parabola() raises:
    # x^2 y/(x^4 + y^2): 0 along every line, 1/2 along y = x^2.
    var num = poly2_monomial(2, 1, q(1))
    var den = poly2_sum(poly2_monomial(4, 0, q(1)), poly2_monomial(0, 2, q(1)))
    assert_false(path_dependence_witness(num, den, 6).found)
    assert_true(p1_equal(directional_limit(num, den, at(1)), at(0)))
    var along_parabola = curve_limit(num, den, poly_i64([0, 1]), poly_i64([0, 0, 1]))
    assert_true(p1_equal(along_parabola, at(1, 2)))


# Section 7: Moebius maps and continued fractions.


def test_mobius_is_continuous_at_infinity() raises:
    var m = mobius(q(2), q(1), q(3), q(4))  # (2z + 1)/(3z + 4)
    assert_true(p1_equal(mobius_apply(m, p1_infinity()), at(2, 3)))
    assert_true(p1_is_infinity(mobius_apply(m, at(-4, 3))))
    assert_false(mobius(q(1), q(2), q(2), q(4)).accepted())
    # Composition is the matrix product.
    var n = mobius(q(0), q(1), q(1), q(-5))  # 1/(z - 5)
    var z = at(7, 2)
    assert_true(p1_equal(mobius_apply(mobius_compose(m, n), z), mobius_apply(m, mobius_apply(n, z))))


def test_convergents_are_the_orbit_of_infinity() raises:
    var x = fraction_from_i64(415, 93)
    var terms = continued_fraction(x).terms.copy()
    var expected = convergents(x)
    var acc = mobius(q(1), q(0), q(0), q(1))
    for k in range(len(terms)):
        acc = mobius_compose(acc, mobius(integer(terms[k]), q(1), q(1), q(0)))
        var image = mobius_apply(acc, p1_infinity())
        var p_k = integer(expected.numerators[k])
        var q_k = integer(expected.denominators[k])
        assert_true(p1_equal(image, p1(p_k, q_k)))
        if k > 0:
            # Farey neighbours: chi^2 = 4/((p^2 + q^2)(p'^2 + q'^2)).
            var p_prev = integer(expected.numerators[k - 1])
            var q_prev = integer(expected.denominators[k - 1])
            var norms = p_k.square().add(q_k.square()).mul(p_prev.square().add(q_prev.square()))
            assert_true(chordal_distance_squared(image, p1(p_prev, q_prev)).eq(q(4).div(norms)))
    assert_true(p1_equal(mobius_apply(acc, p1_infinity()), at(415, 93)))


def main() raises:
    test_homogeneous_normal_form()
    print("[PASS] test_homogeneous_normal_form")
    test_continuity_at_regular_points()
    print("[PASS] test_continuity_at_regular_points")
    test_pole_is_continuity_into_infinity()
    print("[PASS] test_pole_is_continuity_into_infinity")
    test_degree_rule_at_infinity()
    print("[PASS] test_degree_rule_at_infinity")
    test_infinity_maps_through_finite_image()
    print("[PASS] test_infinity_maps_through_finite_image")
    test_chordal_distance_squared()
    print("[PASS] test_chordal_distance_squared")
    test_tangent_slope_smooth_vertical_and_cusp()
    print("[PASS] test_tangent_slope_smooth_vertical_and_cusp")
    test_oblique_and_horizontal_asymptotes()
    print("[PASS] test_oblique_and_horizontal_asymptotes")
    test_landing_is_lhopital()
    print("[PASS] test_landing_is_lhopital")
    test_cancellation_law()
    print("[PASS] test_cancellation_law")
    test_cancellation_sweep_against_evaluation()
    print("[PASS] test_cancellation_sweep_against_evaluation")
    test_directional_limits_on_the_divisor()
    print("[PASS] test_directional_limits_on_the_divisor")
    test_path_dependence_witness_certifies_nonexistence()
    print("[PASS] test_path_dependence_witness_certifies_nonexistence")
    test_second_blow_up_along_a_parabola()
    print("[PASS] test_second_blow_up_along_a_parabola")
    test_mobius_is_continuous_at_infinity()
    print("[PASS] test_mobius_is_continuous_at_infinity")
    test_convergents_are_the_orbit_of_infinity()
    print("[PASS] test_convergents_are_the_orbit_of_infinity")
    print("16 projective_limits Mojo tests passed.")
