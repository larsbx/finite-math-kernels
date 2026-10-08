"""Laws for projective_limits over any exact field: Q and the prime fields F_p.

The landing kernel reads a limit off polynomial coefficients, so for f in K(x)
and a in P^1(K) the limit lies in P^1(K). The same code therefore runs over
every exact field, and these laws check it over F_p where a finite field
admits exhaustive checks and exposes characteristic-p behaviour.

Run with `pixi run test-projective-limits`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.field import QField
from finite_exact.fp import Fp, FpField
from finite_exact.rat_q import Q
from projective_limits.line import (
    P1Over,
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
    PolyOver,
    Poly2Over,
    RationalMapOver,
    asymptote,
    landing,
    path_dependence_witness,
    poly2_monomial,
    poly2_sum,
    poly_i64,
    rational_limit,
    tangent_slope,
)


def at[p: Int64](t: Int64) -> P1Over[FpField[p]]:
    return p1_affine[FpField[p]](Fp[p](t))


def infinity[p: Int64]() -> P1Over[FpField[p]]:
    return p1_infinity[FpField[p]]()


def points[p: Int64]() -> List[P1Over[FpField[p]]]:
    """All of P^1(F_p): the p affine points and infinity."""
    var out = List[P1Over[FpField[p]]]()
    for t in range(Int(p)):
        out.append(at[p](Int64(t)))
    out.append(infinity[p]())
    return out^


def poly_fp[p: Int64](ints: List[Int]) -> PolyOver[FpField[p]]:
    return poly_i64[FpField[p]](ints)


def monomial_power[p: Int64](k: Int, a: Int64) -> PolyOver[FpField[p]]:
    """(x - a)^k over F_p."""
    var linear = poly_fp[p]([Int(-a), 1])
    return linear.pow(k)


# Section 1: the prime field is an exact field.


def check_field_axioms[p: Int64]() raises:
    for a in range(Int(p)):
        var x = Fp[p](Int64(a))
        assert_true((x + (-x)).is_zero())
        if a != 0:
            assert_true(x * (Fp[p].one() / x) == Fp[p].one())
    assert_false((Fp[p].one() / Fp[p].zero()).accepted())
    # Reduction is canonical: -1 and p - 1 are one element.
    assert_true(Fp[p](-1) == Fp[p](p - 1))


def test_prime_field_axioms() raises:
    check_field_axioms[7]()
    check_field_axioms[13]()


def test_rejection_is_sticky() raises:
    var bad = Fp[7].one() / Fp[7].zero()
    assert_false((bad + Fp[7].one()).accepted())
    assert_false((bad * Fp[7].zero()).accepted())
    assert_false(bad == bad)
    # The ExactField contract: a rejected value is never zero.
    assert_false(bad.is_zero())
    assert_false(QField.is_zero(Q.one().div(Q.zero())))
    assert_false(FpField[7].is_zero(bad))
    assert_false(p1[FpField[7]](bad, Fp[7].one()).accepted())


# Section 2: P^1(F_p) in normal form.


def test_normal_form_over_fp() raises:
    # [2:4] = [1/2 : 1] = [4 : 1] in F_7.
    assert_true(p1_equal(p1[FpField[7]](Fp[7](2), Fp[7](4)), at[7](4)))
    assert_true(p1_is_infinity(p1[FpField[7]](Fp[7](3), Fp[7](0))))
    assert_false(p1[FpField[7]](Fp[7](0), Fp[7](7)).accepted())


def check_projective_line_count[p: Int64]() raises:
    var pts = points[p]()
    assert_equal(len(pts), Int(p) + 1)
    for i in range(len(pts)):
        for j in range(len(pts)):
            assert_equal(p1_equal(pts[i], pts[j]), i == j)


def test_projective_line_has_p_plus_one_points() raises:
    check_projective_line_count[7]()
    check_projective_line_count[13]()


# Section 3: the half-turn J : t -> -1/t.
#
# In the half-angle chart t = tan(theta/2) a rotation is a Moebius map, and the
# half-turn is J = [[0, 1], [-1, 0]]. J is an involution of P^1(K) for every
# field K, and its fixed points t^2 = -1 are exactly the isotropic points where
# x^2 + y^2 vanishes: none in F_7 (7 = 3 mod 4), two in F_13 (13 = 1 mod 4).


def check_half_turn[p: Int64](expected_fixed: Int) raises:
    var j = mobius[FpField[p]](Fp[p](0), Fp[p](1), Fp[p](-1), Fp[p](0))
    assert_true(j.accepted())
    var fixed = 0
    for pt in points[p]():
        assert_true(p1_equal(mobius_apply(j, mobius_apply(j, pt)), pt))
        if p1_equal(mobius_apply(j, pt), pt):
            fixed += 1
            assert_false(chordal_distance_squared(pt, pt).accepted())
    assert_equal(fixed, expected_fixed)
    # J swaps 0 and infinity, the two ends of a diameter.
    assert_true(p1_is_infinity(mobius_apply(j, at[p](0))))


def test_half_turn_is_an_involution() raises:
    check_half_turn[7](0)
    check_half_turn[13](2)


def test_half_turn_over_q_has_no_fixed_points() raises:
    var j = mobius(Q(0, 1), Q(1, 1), Q(-1, 1), Q(0, 1))
    var jj = mobius_compose(j, j)
    # J^2 = -1 as a matrix, the identity of PGL_2.
    assert_true(jj.a.eq(Q(-1, 1)) and jj.b.eq(Q.zero()))
    assert_true(jj.c.eq(Q.zero()) and jj.d.eq(Q(-1, 1)))
    assert_true(p1_equal(mobius_apply(j, p1_affine(Q(1, 2))), p1_affine(Q(-2, 1))))


# Section 4: the chordal quadrance is 4 x spread, invariant under rotation.


def check_rotation_invariance[p: Int64]() raises:
    var pts = points[p]()
    for a in range(Int(p)):
        var r = mobius[FpField[p]](Fp[p](1), Fp[p](Int64(a)), Fp[p](-Int64(a)), Fp[p](1))
        if not r.accepted():
            continue  # 1 + a^2 = 0: a is isotropic, not a rotation.
        for i in range(len(pts)):
            for j in range(len(pts)):
                var before = chordal_distance_squared(pts[i], pts[j])
                var after = chordal_distance_squared(
                    mobius_apply(r, pts[i]), mobius_apply(r, pts[j])
                )
                assert_equal(before.accepted(), after.accepted())
                if before.accepted():
                    assert_true(before == after)


def test_chordal_quadrance_is_rotation_invariant() raises:
    check_rotation_invariance[7]()
    check_rotation_invariance[13]()


def test_chordal_quadrance_is_four_spread() raises:
    # t = 0 and t = 1 are a quarter turn apart (half-angles 0 and pi/4), so
    # chi^2 = 4 * spread(0, pi/4) = 4 * 1/2; 0 and infinity are a half-turn,
    # antipodal, with chi^2 = 4 * 1.
    assert_true(chordal_distance_squared(p1_affine(Q(0, 1)), p1_affine(Q(1, 1))).eq(Q(2, 1)))
    assert_true(chordal_distance_squared(p1_affine(Q(0, 1)), p1_infinity()).eq(Q(4, 1)))
    assert_true(
        chordal_distance_squared(at[7](0), infinity[7]()) == Fp[7](4)
    )


# Section 5: limits over F_p.


def check_wilson[p: Int64]() raises:
    # x^p - x = prod_{b in F_p} (x - b), so (x^p - x)/(x - a) lands on
    # prod_{b != a} (a - b) = -1 at every a: Wilson's theorem as a limit.
    var ints = List[Int]()
    for k in range(Int(p) + 1):
        ints.append(1 if k == Int(p) else (-1 if k == 1 else 0))
    var num = poly_fp[p](ints)
    for a in range(Int(p)):
        var den = poly_fp[p]([-a, 1])
        var lim = rational_limit(RationalMapOver(num, den), at[p](Int64(a)))
        assert_true(p1_equal(lim, at[p](-1)))


def test_wilson_theorem_is_a_limit() raises:
    check_wilson[7]()
    check_wilson[13]()


def test_landing_survives_where_lhopital_fails() raises:
    # In characteristic 7, x^7 - 3 = (x - 3)^7, so (x^7 - 3)/(x - 3)^7 -> 1.
    # Every derivative of order < 7 of both vanishes at 3 and the 7th
    # derivative carries 7! = 0, so L'Hopital never decides; landing does.
    var num = poly_fp[7]([-3, 0, 0, 0, 0, 0, 0, 1])
    var den = monomial_power[7](7, 3)
    var lim = rational_limit(RationalMapOver(num, den), at[7](3))
    assert_true(p1_equal(lim, at[7](1)))
    assert_true(p1_equal(landing(num.shift(Fp[7](3)), den.shift(Fp[7](3))), lim))


def test_degree_rule_at_infinity_over_fp() raises:
    # (3x^2 + 1)/(5x^2 + x) -> 3/5 = 3 * 3 = 2 in F_7.
    var f = RationalMapOver(poly_fp[7]([1, 0, 3]), poly_fp[7]([0, 1, 5]))
    assert_true(p1_equal(rational_limit(f, infinity[7]()), at[7](2)))
    # A leading coefficient divisible by p drops the degree: (7x^2 + x)/(x + 1) -> 1.
    var g = RationalMapOver(poly_fp[7]([0, 1, 7]), poly_fp[7]([1, 1]))
    assert_true(p1_equal(rational_limit(g, infinity[7]()), at[7](1)))


def test_tangent_slope_and_asymptote_over_fp() raises:
    # The parabola t -> (t, t^2) has slope 2 a at a.
    var x = poly_fp[13]([0, 1])
    var y = poly_fp[13]([0, 0, 1])
    assert_true(p1_equal(tangent_slope(x, y, Fp[13](5)), at[13](10)))
    # (x^2 + 1)/x = x + 1/x: slope 1, intercept 0.
    var a = asymptote(RationalMapOver(poly_fp[13]([1, 0, 1]), poly_fp[13]([0, 1])))
    assert_true(p1_equal(a.slope, at[13](1)))
    assert_true(p1_equal(a.intercept, at[13](0)))


def test_path_dependence_over_fp() raises:
    # x y / (x^2 + y^2) has direction-dependent values on the divisor.
    var num = poly2_monomial[FpField[7]](1, 1, Fp[7](1))
    var den = poly2_sum(
        poly2_monomial[FpField[7]](2, 0, Fp[7](1)), poly2_monomial[FpField[7]](0, 2, Fp[7](1))
    )
    var w = path_dependence_witness(num, den, 3)
    assert_true(w.found)
    assert_false(p1_equal(w.first_limit, w.second_limit))


def main() raises:
    test_prime_field_axioms()
    print("[PASS] test_prime_field_axioms")
    test_rejection_is_sticky()
    print("[PASS] test_rejection_is_sticky")
    test_normal_form_over_fp()
    print("[PASS] test_normal_form_over_fp")
    test_projective_line_has_p_plus_one_points()
    print("[PASS] test_projective_line_has_p_plus_one_points")
    test_half_turn_is_an_involution()
    print("[PASS] test_half_turn_is_an_involution")
    test_half_turn_over_q_has_no_fixed_points()
    print("[PASS] test_half_turn_over_q_has_no_fixed_points")
    test_chordal_quadrance_is_rotation_invariant()
    print("[PASS] test_chordal_quadrance_is_rotation_invariant")
    test_chordal_quadrance_is_four_spread()
    print("[PASS] test_chordal_quadrance_is_four_spread")
    test_wilson_theorem_is_a_limit()
    print("[PASS] test_wilson_theorem_is_a_limit")
    test_landing_survives_where_lhopital_fails()
    print("[PASS] test_landing_survives_where_lhopital_fails")
    test_degree_rule_at_infinity_over_fp()
    print("[PASS] test_degree_rule_at_infinity_over_fp")
    test_tangent_slope_and_asymptote_over_fp()
    print("[PASS] test_tangent_slope_and_asymptote_over_fp")
    test_path_dependence_over_fp()
    print("[PASS] test_path_dependence_over_fp")
    print("13 projective_limits field-generic Mojo tests passed.")
