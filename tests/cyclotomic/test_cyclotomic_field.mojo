"""Laws for the cyclotomic field Q(zeta_q) = Q[X]/(Phi_q) and its germ stages.

Run with `pixi run test-cyclotomic`.
"""

from std.testing import assert_equal, assert_false, assert_true

from cyclotomic.field import Cyc, CyclotomicField, cyclotomic_polynomial, euler_phi, mobius_mu, units
from cyclotomic.germ import parabolic_factor, reciprocal_series, truncated_iterate
from finite_exact.rat_q import Q
from projective_limits.limits import PolyOver, RationalMapOver, rational_limit
from projective_limits.line import P1Over, p1_affine, p1_equal
from projective_limits.rotor import (
    circle_point,
    circle_rotor,
    rotor_order,
    rotor_power,
    rotor_spread,
    spread_polynomial,
)


def zeta[q: Int](k: Int = 1) -> Cyc[q]:
    return Cyc[q].zeta(k)


def const[q: Int](n: Int64, d: Int64 = 1) -> Cyc[q]:
    return Cyc[q].rational(Q(n, d))


def sample[q: Int](seed: Int) -> Cyc[q]:
    """A deterministic element with small rational coordinates."""
    var state = seed * 2654435761 + 12345
    var c = List[Q]()
    for _ in range(euler_phi(q)):
        state = (state * 1103515245 + 12345) % 2147483648
        var n = Int64(state % 19) - 9
        state = (state * 1103515245 + 12345) % 2147483648
        c.append(Q(n, Int64(state % 5) + 1))
    return Cyc[q].from_poly(c)


def power[q: Int](a: Cyc[q], n: Int) -> Cyc[q]:
    var out = const[q](1)
    for _ in range(n):
        out = out * a
    return out^


# Section 1: Phi_q, the totient and the Moebius function.


def test_cyclotomic_polynomials() raises:
    assert_true(cyclotomic_polynomial(1) == [-1, 1])
    assert_true(cyclotomic_polynomial(4) == [1, 0, 1])
    assert_true(cyclotomic_polynomial(6) == [1, -1, 1])
    assert_true(cyclotomic_polynomial(12) == [1, 0, -1, 0, 1])
    assert_true(cyclotomic_polynomial(8) == [1, 0, 0, 0, 1])
    # Phi_105 is the first with a coefficient outside {-1, 0, 1}: -2 at X^7.
    assert_equal(cyclotomic_polynomial(105)[7], -2)
    var totients: List[Int] = [1, 1, 2, 2, 4, 2, 6, 4, 6, 4, 10, 4]
    for q in range(1, 13):
        assert_equal(len(cyclotomic_polynomial(q)) - 1, totients[q - 1])
        assert_equal(euler_phi(q), totients[q - 1])
    var mus: List[Int] = [1, -1, -1, 0, -1, 1, -1, 0, 0, 1, -1, 0]
    for q in range(1, 13):
        assert_equal(mobius_mu(q), mus[q - 1])


def check_product_is_x_q_minus_one[q: Int]() raises:
    # prod_{d | q} Phi_d = X^q - 1, over the integers.
    var prod: List[Int] = [1]
    for d in range(1, q + 1):
        if q % d != 0:
            continue
        var f = cyclotomic_polynomial(d)
        var out = List[Int]()
        for _ in range(len(prod) + len(f) - 1):
            out.append(0)
        for i in range(len(prod)):
            for j in range(len(f)):
                out[i + j] += prod[i] * f[j]
        prod = out^
    assert_equal(len(prod), q + 1)
    assert_equal(prod[0], -1)
    assert_equal(prod[q], 1)
    for k in range(1, q):
        assert_equal(prod[k], 0)


def test_product_of_cyclotomic_polynomials() raises:
    check_product_is_x_q_minus_one[12]()
    check_product_is_x_q_minus_one[30]()
    check_product_is_x_q_minus_one[36]()


# Section 2: C1, field arithmetic.


def check_zeta_is_primitive[q: Int]() raises:
    var one = const[q](1)
    for k in range(1, q):
        assert_true(power(zeta[q](), k) != one)
    assert_true(power(zeta[q](), q) == one)
    for k in range(-q, 2 * q):
        assert_true(zeta[q](k) == zeta[q](k + q))
        assert_true(zeta[q](k) == power(zeta[q](), k % q))


def test_zeta_has_exact_order_q() raises:
    check_zeta_is_primitive[1]()
    check_zeta_is_primitive[2]()
    check_zeta_is_primitive[5]()
    check_zeta_is_primitive[8]()
    check_zeta_is_primitive[12]()


def check_field_axioms[q: Int]() raises:
    for s in range(6):
        var a = sample[q](s)
        var b = sample[q](s + 17)
        var c = sample[q](s + 41)
        assert_true(a * (b + c) == a * b + a * c)
        assert_true((a * b) * c == a * (b * c))
        assert_true(a * b == b * a)
        assert_true((a + (-a)).is_zero())
        assert_true(a - b == a + (-b))
        if not a.is_zero():
            assert_true(a * a.inverse() == const[q](1))
            assert_true((b / a) * a == b)


def test_field_axioms() raises:
    check_field_axioms[3]()
    check_field_axioms[5]()
    check_field_axioms[8]()
    check_field_axioms[12]()


def test_rejection_is_sticky() raises:
    var bad = const[5](1) / const[5](0)
    assert_false(bad.accepted())
    assert_false(bad.is_zero())
    assert_false(bad == bad)
    assert_false((bad + const[5](1)).accepted())
    assert_false((const[5](0) * bad).accepted())
    assert_false(bad.galois(2).accepted())
    assert_false(bad.inverse().accepted())
    # The field adaptor forwards the same contract.
    comptime K = CyclotomicField[5]
    assert_false(K.accepted(K.div(K.one(), K.zero())))
    assert_false(K.is_zero(K.rejected()))


def test_reduction_modulo_phi() raises:
    # 1 + zeta + zeta^2 + zeta^3 + zeta^4 = 0 in Q(zeta_5).
    assert_true(Cyc[5].from_poly([Q.one(), Q.one(), Q.one(), Q.one(), Q.one()]).is_zero())
    # zeta_4 = i: i^2 = -1.
    assert_true(zeta[4]() * zeta[4]() == const[4](-1))
    # Coordinates are canonical: zeta_8^4 = -1 is stored as (-1, 0, 0, 0).
    assert_true(zeta[8](4) == const[8](-1))


# Section 3: C2, the Galois action.


def check_galois[q: Int]() raises:
    var group = units(q)
    assert_equal(len(group), euler_phi(q))
    var a = sample[q](3)
    var b = sample[q](5)
    for s in group:
        assert_true(zeta[q]().galois(s) == zeta[q](s))
        assert_true((a * b).galois(s) == a.galois(s) * b.galois(s))
        assert_true((a + b).galois(s) == a.galois(s) + b.galois(s))
        for t in group:
            assert_true(a.galois(t).galois(s) == a.galois(s * t))
    assert_true(a.galois(1) == a)
    assert_true(a.galois(q + 1) == a and a.galois(1 - q) == a)
    if q > 2:
        assert_false(a.galois(q).accepted())


def test_galois_action() raises:
    check_galois[5]()
    check_galois[8]()
    check_galois[12]()


def test_trace_of_zeta_is_mobius() raises:
    # The primitive q-th roots of unity sum to mu(q) (Ramanujan's sum c_q(1)).
    comptime for q in [1, 6, 7, 8, 9, 10, 30]:
        assert_true(zeta[q]().trace().eq(Q.from_int(Int64(mobius_mu(q)))))
    assert_true(zeta[7]().trace().eq(Q(-1, 1)))
    assert_true(zeta[9]().trace().eq(Q.zero()))
    assert_false(zeta[5]().rational_part().accepted())


def test_norm_of_one_minus_zeta() raises:
    # N(1 - zeta_q) = Phi_q(1): p for q = p^k, 1 for q with two prime factors.
    assert_true((const[5](1) - zeta[5]()).norm().eq(Q(5, 1)))
    assert_true((const[8](1) - zeta[8]()).norm().eq(Q(2, 1)))
    assert_true((const[9](1) - zeta[9]()).norm().eq(Q(3, 1)))
    assert_true((const[12](1) - zeta[12]()).norm().eq(Q(1, 1)))
    assert_true((const[30](1) - zeta[30]()).norm().eq(Q(1, 1)))
    # The norm is multiplicative.
    var a = sample[7](1)
    var b = sample[7](2)
    assert_true((a * b).norm().eq(a.norm().mul(b.norm())))


# Section 4: Q1 and Q2, the quadratic germ at zeta.


def test_germ_multiplier_and_parabolic_factor() raises:
    var lam = zeta[3]()
    # g(w) = lam w + w^2: first iterate is exactly that.
    var g = truncated_iterate(lam, 1, 4)
    assert_true(g.accepted())
    assert_true(g.terms[0].is_zero())
    assert_true(g.terms[1] == lam)
    assert_true(g.terms[2] == const[3](1))
    assert_true(g.terms[3].is_zero())
    # w - g^3(w) vanishes to order 4 at lam = zeta_3; the factor's constant
    # is -5 - zeta_3 (pinned in conformance/cyclotomic_germ_v1.json).
    var factor = parabolic_factor(lam, 3)
    assert_true(factor.accepted())
    assert_true(factor.terms[0] == const[3](-5) - lam)
    # A non-root of unity multiplier is refused: the residual has a linear term.
    assert_false(parabolic_factor(const[3](2), 3).accepted())


def test_reciprocal_series() raises:
    var factor = parabolic_factor(zeta[5](), 5)
    var inv = reciprocal_series(factor)
    assert_true(inv.accepted())
    # P * (1/P) = 1 to the truncation order.
    var unit = factor * inv
    for k in range(len(unit.terms)):
        assert_true(unit.terms[k] == const[5](Int64(1 if k == 0 else 0)))
    var bad = factor.copy()
    bad.terms[0] = const[5](0)
    assert_false(reciprocal_series(bad).accepted())


# Section 5: Q(zeta) as a field for the kernels above.


def test_landing_over_q_zeta() raises:
    # (x^q - 1)/(x - zeta) at zeta lands on q zeta^(q-1) = q / zeta.
    comptime K = CyclotomicField[5]
    var num = PolyOver[K]([const[5](-1), const[5](0), const[5](0), const[5](0), const[5](0), const[5](1)])
    var den = PolyOver[K]([-zeta[5](), const[5](1)])
    var lim = rational_limit(RationalMapOver(num, den), p1_affine[K](zeta[5]()))
    assert_true(p1_equal(lim, p1_affine[K](const[5](5) / zeta[5]())))


def turn_rotor[q: Int]() -> P1Over[CyclotomicField[q]]:
    """The rotor of the turn 1/q from zeta_q = x + i y, with i = zeta_q^(q/4)."""
    comptime assert q % 4 == 0, "i = zeta_q^(q/4) lies in Q(zeta_q) only when 4 | q"
    var z = zeta[q]()
    var i = zeta[q](q // 4)
    var x = (z + z.inverse()) / const[q](2)
    var y = (z - z.inverse()) / (const[q](2) * i)
    return circle_rotor[CyclotomicField[q]](x, y)


def check_turn_has_exact_order[q: Int]() raises:
    comptime K = CyclotomicField[q]
    var t = turn_rotor[q]()
    assert_equal(rotor_order(t, 3 * q), q)
    # The circle point is (Re zeta, Im zeta): x^2 + y^2 = 1 holds by construction.
    var u = circle_point(t)
    assert_true(u.accepted())
    assert_true(u.x * u.x + u.y * u.y == const[q](1))
    assert_true(u.x == (zeta[q]() + zeta[q](-1)) / const[q](2))
    # The spread of the turn 1/q is a root of S_q.
    var s = rotor_spread(t)
    assert_true(spread_polynomial[K](q, s).is_zero())
    assert_true(rotor_spread(rotor_power(t, q)).is_zero())


def test_turns_beyond_niven_have_exact_order() raises:
    # Over Q only orders 1, 2, 4 occur; over Q(zeta_q) the turn 1/q has order q.
    check_turn_has_exact_order[8]()
    check_turn_has_exact_order[12]()
    check_turn_has_exact_order[20]()


def test_spread_of_an_eighth_turn_is_one_half() raises:
    comptime K = CyclotomicField[8]
    var t = turn_rotor[8]()
    assert_true(rotor_spread(t) == const[8](1, 2))
    # A quarter turn: zeta_8^2 = i, spread 1, rotor 1.
    assert_true(p1_equal(rotor_power(t, 2), p1_affine[K](const[8](1))))


def main() raises:
    test_cyclotomic_polynomials()
    print("[PASS] test_cyclotomic_polynomials")
    test_product_of_cyclotomic_polynomials()
    print("[PASS] test_product_of_cyclotomic_polynomials")
    test_zeta_has_exact_order_q()
    print("[PASS] test_zeta_has_exact_order_q")
    test_field_axioms()
    print("[PASS] test_field_axioms")
    test_rejection_is_sticky()
    print("[PASS] test_rejection_is_sticky")
    test_reduction_modulo_phi()
    print("[PASS] test_reduction_modulo_phi")
    test_galois_action()
    print("[PASS] test_galois_action")
    test_trace_of_zeta_is_mobius()
    print("[PASS] test_trace_of_zeta_is_mobius")
    test_norm_of_one_minus_zeta()
    print("[PASS] test_norm_of_one_minus_zeta")
    test_germ_multiplier_and_parabolic_factor()
    print("[PASS] test_germ_multiplier_and_parabolic_factor")
    test_reciprocal_series()
    print("[PASS] test_reciprocal_series")
    test_landing_over_q_zeta()
    print("[PASS] test_landing_over_q_zeta")
    test_turns_beyond_niven_have_exact_order()
    print("[PASS] test_turns_beyond_niven_have_exact_order")
    test_spread_of_an_eighth_turn_is_one_half()
    print("[PASS] test_spread_of_an_eighth_turn_is_one_half")
    print("14 cyclotomic Mojo tests passed.")
