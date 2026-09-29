"""Laws for projective_limits.rotor: rotations as points of P^1(K).

In the half-angle chart t = tan(theta/2) the rotation group of the circle
x^2 + y^2 = 1 over a field K is P^1(K) minus the isotropic points 1 + t^2 = 0,
with identity 0, half-turn infinity, and law a (+) b = R_a(b). No angle is
ever measured: a turn a/n is sent to a rotor through a chosen generator.

Run with `pixi run test-projective-limits`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.field import QField
from finite_exact.fp import Fp, FpField
from finite_exact.rat_q import Q
from projective_limits.line import (
    P1Over,
    chordal_distance_squared,
    mobius_apply,
    mobius_compose,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_is_infinity,
)
from projective_limits.rotor import (
    circle_point,
    circle_rotor,
    half_turn,
    is_rotor,
    rotor,
    rotor_add,
    rotor_generator_fp,
    rotor_group_order_fp,
    rotor_identity,
    rotor_neg,
    rotor_order,
    rotor_power,
    rotor_spread,
    spread_polynomial,
    turn,
)


def at[p: Int64](t: Int64) -> P1Over[FpField[p]]:
    return p1_affine[FpField[p]](Fp[p](t))


def infinity[p: Int64]() -> P1Over[FpField[p]]:
    return p1_infinity[FpField[p]]()


def points[p: Int64]() -> List[P1Over[FpField[p]]]:
    var out = List[P1Over[FpField[p]]]()
    for t in range(Int(p)):
        out.append(at[p](Int64(t)))
    out.append(infinity[p]())
    return out^


def rotors[p: Int64]() -> List[P1Over[FpField[p]]]:
    """T(F_p): the non-isotropic points of P^1(F_p)."""
    var out = List[P1Over[FpField[p]]]()
    for pt in points[p]():
        if is_rotor(pt):
            out.append(pt.copy())
    return out^


# Section 1: the rotor of a point, identity, half-turn, isotropic points.


def test_identity_and_half_turn() raises:
    assert_true(p1_equal(rotor_identity[FpField[7]](), at[7](0)))
    assert_true(p1_is_infinity(half_turn[FpField[7]]()))
    var j = rotor(infinity[13]())
    var id = rotor(at[13](0))
    for pt in points[13]():
        assert_true(p1_equal(mobius_apply(j, mobius_apply(j, pt)), pt))
        assert_true(p1_equal(mobius_apply(id, pt), pt))
    # R_inf is t -> -1/t.
    assert_true(p1_equal(mobius_apply(j, at[13](2)), at[13](6)))  # -1/2 = 6 mod 13


def test_isotropic_points_are_not_rotors() raises:
    # 5^2 = 25 = -1 mod 13; F_7 has no square root of -1.
    assert_false(is_rotor(at[13](5)))
    assert_false(is_rotor(at[13](8)))
    assert_false(rotor(at[13](5)).accepted())
    assert_false(rotor_add(at[13](5), at[13](1)).accepted())
    assert_equal(len(rotors[7]()), 8)
    assert_equal(len(rotors[13]()), 12)
    assert_true(is_rotor(p1_infinity()))


# Section 2: the group law.


def check_group_law_is_composition[p: Int64]() raises:
    var ts = rotors[p]()
    var pts = points[p]()
    for a in ts:
        for b in ts:
            var ab = rotor_add(a, b)
            assert_true(is_rotor(ab))
            var composed = mobius_compose(rotor(a), rotor(b))
            for pt in pts:
                assert_true(p1_equal(mobius_apply(rotor(ab), pt), mobius_apply(composed, pt)))


def test_group_law_is_composition_of_rotations() raises:
    check_group_law_is_composition[7]()
    check_group_law_is_composition[13]()


def check_group_axioms[p: Int64]() raises:
    var ts = rotors[p]()
    var zero = rotor_identity[FpField[p]]()
    for a in ts:
        assert_true(p1_equal(rotor_add(a, zero), a))
        assert_true(p1_equal(rotor_add(a, rotor_neg(a)), zero))
        for b in ts:
            assert_true(p1_equal(rotor_add(a, b), rotor_add(b, a)))
            for c in ts:
                assert_true(
                    p1_equal(rotor_add(rotor_add(a, b), c), rotor_add(a, rotor_add(b, c)))
                )


def test_group_axioms() raises:
    check_group_axioms[7]()
    check_group_axioms[13]()


def check_group_law_is_circle_multiplication[p: Int64]() raises:
    # Independent method: on x^2 + y^2 = 1, rotation composes as
    # (x1, y1)(x2, y2) = (x1 x2 - y1 y2, x1 y2 + x2 y1).
    var ts = rotors[p]()
    for a in ts:
        var u = circle_point(a)
        assert_true(u.accepted())
        assert_true(u.x * u.x + u.y * u.y == Fp[p].one())
        assert_true(p1_equal(circle_rotor[FpField[p]](u.x, u.y), a))
        for b in ts:
            var v = circle_point(b)
            var x = u.x * v.x - u.y * v.y
            var y = u.x * v.y + v.x * u.y
            assert_true(p1_equal(circle_rotor[FpField[p]](x, y), rotor_add(a, b)))


def test_group_law_is_circle_multiplication() raises:
    check_group_law_is_circle_multiplication[7]()
    check_group_law_is_circle_multiplication[13]()


def check_circle_bijection[p: Int64]() raises:
    # Every point of x^2 + y^2 = 1 over F_p has exactly one rotor.
    var count = 0
    for x in range(Int(p)):
        for y in range(Int(p)):
            var fx = Fp[p](Int64(x))
            var fy = Fp[p](Int64(y))
            if fx * fx + fy * fy != Fp[p].one():
                continue
            count += 1
            var t = circle_rotor[FpField[p]](fx, fy)
            assert_true(is_rotor(t))
            var back = circle_point(t)
            assert_true(back.accepted())
            assert_true(back.x == fx)
            assert_true(back.y == fy)
    assert_equal(count, len(rotors[p]()))
    assert_equal(Int64(count), rotor_group_order_fp(p))


def test_circle_is_the_rotor_group() raises:
    # Characteristic 2 is excluded: there 2 t / (1 + t^2) = 0 and the
    # half-angle chart does not cover the circle, so the order is undefined.
    assert_equal(rotor_group_order_fp(2), 0)
    check_circle_bijection[3]()
    check_circle_bijection[5]()
    check_circle_bijection[7]()
    check_circle_bijection[13]()


def test_rational_rotors() raises:
    # arctan(1/2) + arctan(1/3) = pi/4 in half-angles: a quarter turn, exactly.
    var sum = rotor_add(p1_affine(Q(1, 2)), p1_affine(Q(1, 3)))
    assert_true(p1_equal(sum, p1_affine(Q(1, 1))))
    var quarter = circle_point(sum)
    assert_true(quarter.x.eq(Q.zero()) and quarter.y.eq(Q.one()))
    # The half-turn is (-1, 0), and a (+) inf = -1/a.
    var half = circle_point(p1_infinity())
    assert_true(half.x.eq(Q(-1, 1)) and half.y.eq(Q.zero()))
    assert_true(p1_equal(rotor_add(p1_affine(Q(2, 3)), p1_infinity()), p1_affine(Q(-3, 2))))
    # (3/5, 4/5) is the rotor 1/2, of infinite order.
    assert_true(p1_equal(circle_rotor(Q(3, 5), Q(4, 5)), p1_affine(Q(1, 2))))


# Section 3: powers and orders.


def test_powers() raises:
    var a = p1_affine(Q(1, 2))
    assert_true(p1_equal(rotor_power(a, 0), rotor_identity()))
    assert_true(p1_equal(rotor_power(a, 1), a))
    assert_true(p1_equal(rotor_power(a, 2), p1_affine(Q(4, 3))))  # 1/2 (+) 1/2
    assert_true(p1_equal(rotor_power(a, -1), p1_affine(Q(-1, 2))))
    var five = rotor_add(rotor_add(rotor_power(a, 2), rotor_power(a, 2)), a)
    assert_true(p1_equal(rotor_power(a, 5), five))
    assert_true(p1_equal(rotor_power(p1_affine(Q(1, 1)), 4), rotor_identity()))
    assert_false(rotor_power(at[13](5), 3).accepted())


def check_lagrange[p: Int64]() raises:
    var n = Int(rotor_group_order_fp(p))
    var generators = 0
    for a in rotors[p]():
        var k = rotor_order(a, n)
        assert_true(k >= 1 and n % k == 0)
        assert_true(p1_equal(rotor_power(a, k), rotor_identity[FpField[p]]()))
        if k == n:
            generators += 1
    # T(F_p) is cyclic: phi(N) generators.
    var phi = 0
    for k in range(1, n + 1):
        var a = k
        var b = n
        while b != 0:
            (a, b) = (b, a % b)
        if a == 1:
            phi += 1
    assert_equal(generators, phi)
    assert_equal(rotor_order(rotor_generator_fp[p](), n), n)


def test_orders_divide_the_group_order() raises:
    check_lagrange[5]()
    check_lagrange[7]()
    check_lagrange[13]()
    check_lagrange[31]()


def test_half_turn_is_the_unique_involution() raises:
    for a in rotors[13]():
        assert_equal(rotor_order(a, 12) == 2, p1_is_infinity(a))


def test_rational_torsion_is_niven() raises:
    # Over Q the only rotors of finite order are 0, inf, 1, -1 (orders 1, 2,
    # 4, 4). A bounded search is evidence here, not a proof; Niven's theorem
    # is the proof.
    assert_equal(rotor_order(p1_affine(Q(0, 1)), 24), 1)
    assert_equal(rotor_order(p1_infinity(), 24), 2)
    assert_equal(rotor_order(p1_affine(Q(1, 1)), 24), 4)
    assert_equal(rotor_order(p1_affine(Q(-1, 1)), 24), 4)
    for n in range(-6, 7):
        for d in range(1, 7):
            var a = p1_affine(Q(Int64(n), Int64(d)))
            var k = rotor_order(a, 24)
            var niven = p1_equal(a, p1_affine(Q(0, 1))) or p1_equal(a, p1_affine(Q(1, 1))) or p1_equal(a, p1_affine(Q(-1, 1)))
            assert_equal(k != 0, niven)


# Section 4: turns a/n as rotors, through a generator.


def check_turn_homomorphism[p: Int64]() raises:
    var n = Int(rotor_group_order_fp(p))
    var g = rotor_generator_fp[p]()
    var dens = List[Int]()
    for d in range(1, n + 1):
        if n % d == 0:
            dens.append(d)
    for d1 in dens:
        for a1 in range(d1):
            for d2 in dens:
                for a2 in range(d2):
                    # d1 and d2 divide n: a1/d1 + a2/d2 = (a1 n/d1 + a2 n/d2)/n.
                    var sum = rotor_add(turn(g, n, a1, d1), turn(g, n, a2, d2))
                    var direct = turn(g, n, a1 * (n // d1) + a2 * (n // d2), n)
                    assert_true(p1_equal(sum, direct))
    # a/n and (a + n)/n are the same turn; a turn of exact order d.
    assert_true(p1_equal(turn(g, n, 1, n), g))
    assert_true(p1_equal(turn(g, n, n + 1, n), g))
    assert_true(p1_equal(turn(g, n, -1, n), rotor_neg(g)))
    assert_equal(rotor_order(turn(g, n, 1, n // 2), n), n // 2)
    # The half-turn is canonical: every generator sends 1/2 to infinity.
    for a in rotors[p]():
        if rotor_order(a, n) == n:
            assert_true(p1_is_infinity(turn(a, n, 1, 2)))
    # A denominator not dividing N has no turn in T(F_p).
    assert_false(turn(g, n, 1, n + 1).accepted())
    assert_false(turn(g, n, 1, 0).accepted())


def test_turns_are_a_homomorphism() raises:
    check_turn_homomorphism[7]()
    check_turn_homomorphism[13]()


def test_quarter_turn_is_plus_or_minus_one() raises:
    # 4 divides N_13 = 12; every generator sends 1/4 to +1 or -1.
    for a in rotors[13]():
        if rotor_order(a, 12) == 12:
            var q = turn(a, 12, 1, 4)
            assert_true(p1_equal(q, at[13](1)) or p1_equal(q, at[13](-1)))


# Section 5: spread and the spread polynomials.


def test_spread_polynomials() raises:
    # S_0 = 0, S_1 = s, S_2 = 4 s (1 - s), S_3 = s (3 - 4 s)^2.
    for k in range(-5, 6):
        var s = Q(Int64(k), 7)
        assert_true(spread_polynomial[QField](0, s).eq(Q.zero()))
        assert_true(spread_polynomial[QField](1, s).eq(s))
        assert_true(spread_polynomial[QField](2, s).eq(Q(4, 1).mul(s).mul(Q.one().sub(s))))
        var f = Q(3, 1).sub(Q(4, 1).mul(s))
        assert_true(spread_polynomial[QField](3, s).eq(s.mul(f).mul(f)))
    # Composition S_n o S_m = S_{nm}.
    var s = Q(2, 9)
    for n in range(4):
        for m in range(4):
            var lhs = spread_polynomial[QField](n, spread_polynomial[QField](m, s))
            assert_true(lhs.eq(spread_polynomial[QField](n * m, s)))


def test_rotor_spread_is_s2_of_the_half_angle_spread() raises:
    # sin^2(theta) = S_2(sin^2(theta/2)), and the half-angle spread from 0 is
    # the chordal quadrance / 4.
    for n in range(-5, 6):
        for d in range(1, 5):
            var a = p1_affine(Q(Int64(n), Int64(d)))
            var half = chordal_distance_squared(p1_affine(Q.zero()), a).div(Q(4, 1))
            assert_true(rotor_spread(a).eq(spread_polynomial[QField](2, half)))
    assert_true(rotor_spread(p1_infinity()).eq(Q.zero()))
    assert_true(rotor_spread(p1_affine(Q(1, 1))).eq(Q.one()))


def check_spread_of_powers[p: Int64]() raises:
    # s(n theta) = S_n(s(theta)) for every rotor of F_p.
    for a in rotors[p]():
        for n in range(8):
            var lhs = rotor_spread(rotor_power(a, n))
            var rhs = spread_polynomial[FpField[p]](n, rotor_spread(a))
            assert_true(lhs == rhs)


def test_spread_of_a_power_is_a_spread_polynomial() raises:
    check_spread_of_powers[7]()
    check_spread_of_powers[13]()
    var a = p1_affine(Q(2, 3))
    for n in range(8):
        var lhs = rotor_spread(rotor_power(a, n))
        assert_true(lhs.eq(spread_polynomial[QField](n, rotor_spread(a))))


def main() raises:
    test_identity_and_half_turn()
    print("[PASS] test_identity_and_half_turn")
    test_isotropic_points_are_not_rotors()
    print("[PASS] test_isotropic_points_are_not_rotors")
    test_group_law_is_composition_of_rotations()
    print("[PASS] test_group_law_is_composition_of_rotations")
    test_group_axioms()
    print("[PASS] test_group_axioms")
    test_group_law_is_circle_multiplication()
    print("[PASS] test_group_law_is_circle_multiplication")
    test_circle_is_the_rotor_group()
    print("[PASS] test_circle_is_the_rotor_group")
    test_rational_rotors()
    print("[PASS] test_rational_rotors")
    test_powers()
    print("[PASS] test_powers")
    test_orders_divide_the_group_order()
    print("[PASS] test_orders_divide_the_group_order")
    test_half_turn_is_the_unique_involution()
    print("[PASS] test_half_turn_is_the_unique_involution")
    test_rational_torsion_is_niven()
    print("[PASS] test_rational_torsion_is_niven")
    test_turns_are_a_homomorphism()
    print("[PASS] test_turns_are_a_homomorphism")
    test_quarter_turn_is_plus_or_minus_one()
    print("[PASS] test_quarter_turn_is_plus_or_minus_one")
    test_spread_polynomials()
    print("[PASS] test_spread_polynomials")
    test_rotor_spread_is_s2_of_the_half_angle_spread()
    print("[PASS] test_rotor_spread_is_s2_of_the_half_angle_spread")
    test_spread_of_a_power_is_a_spread_polynomial()
    print("[PASS] test_spread_of_a_power_is_a_spread_polynomial")
    print("16 projective_limits rotor Mojo tests passed.")
