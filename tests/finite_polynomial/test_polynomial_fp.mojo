"""Executable laws and pinned values of finite_polynomial.polynomial_fp.

Every pinned value is also asserted by tests/finite_polynomial/test_polynomial_fp_reference.py
against the independent reference/polynomial_fp_reference.py.

Run with:
    mojo run -I kernel tests/finite_polynomial/test_polynomial_fp.mojo
"""

from std.testing import assert_equal, assert_false, assert_raises, assert_true

from finite_exact.bigint_z import BigZ, bigz_from_i64, bigz_mul, bigz_neg
from finite_polynomial.polynomial_z import poly_from_coeffs
from finite_polynomial import (
    HenselStep,
    hensel_step,
    hensel_step_valid,
    is_prime,
    poly_fp_certificate_valid,
    poly_fp_distinct_degree,
    poly_fp_factor_degrees,
    poly_fp_irreducibility_certificate,
    poly_fp_is_irreducible,
    prime_divisors,
)
from finite_polynomial.polynomial_fp import (
    Modulus,
    PolyFp,
    poly_fp_add,
    poly_fp_derivative,
    poly_fp_divmod,
    poly_fp_equal,
    poly_fp_eval,
    poly_fp_frobenius_power,
    poly_fp_gcd,
    poly_fp_is_squarefree,
    poly_fp_mul,
    poly_fp_powmod,
    poly_fp_reduce,
    poly_fp_root_count,
    poly_fp_sub,
    poly_fp_xgcd,
    prime_field,
)


def same(a: PolyFp, coefficients: List[Int]) raises:
    assert_true(poly_fp_equal(a, PolyFp(a.modulus, coefficients.copy())), String(a))


def test_moduli_and_residues() raises:
    assert_true(is_prime(2) and is_prime(7) and is_prime(2147483647) and is_prime(1000003))
    assert_false(is_prime(1) or is_prime(9) or is_prime(-7) or is_prime(2147483646))
    # Strong pseudoprimes to base 2 (2047 = 23 * 89) and to bases 2, 3, 5
    # (25326001 = 2251 * 11251) are refused by the full witness set.
    assert_false(is_prime(2047) or is_prime(25326001))
    with assert_raises(contains="2^31"):
        _ = is_prime(2147483648)
    with assert_raises():
        _ = Modulus(2147483648)
    with assert_raises():
        _ = Modulus(1)
    with assert_raises():
        _ = prime_field(9)
    var top = prime_field(2147483647)
    # (p - 1)^2 is the largest product a canonical residue pair forms.
    assert_equal(top.mul(-1, -1), 1)
    assert_equal(top.mul(Int.MIN, Int.MAX), top.mul(top.reduce(Int.MIN), top.reduce(Int.MAX)))
    var f7 = prime_field(7)
    assert_equal(f7.inverse(3), 5)
    assert_equal(f7.reduce(-1), 6)
    assert_equal(f7.pow(3, 6), 1)
    with assert_raises():
        _ = f7.inverse(14)
    with assert_raises():
        _ = Modulus(9).inverse(6)
    assert_equal(Modulus(9).inverse(7), 4)
    var big = prime_field(1000003)
    var e20 = bigz_mul(bigz_from_i64(10000000000), bigz_from_i64(10000000000))
    assert_equal(big.reduce_bigz(e20), 997303)
    assert_equal(big.reduce_bigz(bigz_neg(e20)), 2700)
    assert_equal(len(prime_divisors(360)), 3)
    assert_equal(prime_divisors(360)[2], 5)


def test_ring_operations() raises:
    var f7 = prime_field(7)
    var a = PolyFp(f7, [1, 2, 3, 4, 5])
    var b = PolyFp(f7, [3, 0, 2])
    var qr = poly_fp_divmod(a, b)
    same(qr.quotient, [3, 2, 6])
    same(qr.remainder, [6, 3])
    assert_true(poly_fp_equal(poly_fp_add(poly_fp_mul(qr.quotient, b), qr.remainder), a))
    same(poly_fp_sub(a, a), [])
    assert_equal(PolyFp(f7, [0, 7, 14]).degree(), -1)
    same(
        poly_fp_gcd(poly_fp_mul(PolyFp(f7, [1, 1]), PolyFp(f7, [2, 0, 1])),
                    poly_fp_mul(PolyFp(f7, [1, 1]), PolyFp(f7, [3, 1]))),
        [1, 1],
    )
    same(poly_fp_powmod(PolyFp(f7, [2, 1]), 100, PolyFp(f7, [1, 0, 0, 1])), [1, 3, 3])
    same(poly_fp_derivative(PolyFp(f7, [5, 1, 1, 1, 1, 1, 1, 1])), [1, 2, 3, 4, 5, 6])
    assert_equal(poly_fp_eval(PolyFp(f7, [1, 0, 1]), -3), 3)
    with assert_raises():
        _ = poly_fp_divmod(a, PolyFp(f7, []))
    with assert_raises():
        _ = poly_fp_add(a, PolyFp(prime_field(5), [1]))
    var bezout = poly_fp_xgcd(PolyFp(f7, [1, 0, 1]), PolyFp(f7, [1, 1]))
    same(bezout.gcd, [1])
    assert_true(
        poly_fp_equal(
            poly_fp_add(poly_fp_mul(bezout.s, PolyFp(f7, [1, 0, 1])), poly_fp_mul(bezout.t, PolyFp(f7, [1, 1]))),
            bezout.gcd,
        )
    )
    # Coefficients past Int reduce limb by limb.
    var wide = List[BigZ]()
    wide.append(bigz_mul(bigz_from_i64(10000000000), bigz_from_i64(10000000000)))
    wide.append(bigz_from_i64(-1))
    same(poly_fp_reduce(poly_from_coeffs(wide), prime_field(1000003)), [997303, 1000002])


def check_degrees(p: Int, coefficients: List[Int], expected: List[Int], irreducible: Bool) raises:
    var f = PolyFp(prime_field(p), coefficients.copy())
    assert_true(poly_fp_is_squarefree(f))
    var degrees = poly_fp_factor_degrees(f)
    assert_equal(len(degrees), len(expected), String(f))
    for i in range(len(expected)):
        assert_equal(degrees[i], expected[i], String(f))
    assert_equal(poly_fp_is_irreducible(f), irreducible, String(f))


def test_distinct_degree_factorization() raises:
    check_degrees(2, [1, 1, 0, 0, 1], [4], True)
    check_degrees(3, [2, 2, 0, 1], [3], True)  # x^3 - x - 1, Artin-Schreier
    check_degrees(5, [4, 4, 0, 0, 0, 1], [5], True)
    check_degrees(3, [1, 1, 2, 1], [3], True)  # E_{0,3} = C^3 + 2C^2 + C + 1 mod 3
    check_degrees(7, [1, 1, 1, 2, 0, 1], [2, 3], False)  # (x^2 + 1)(x^3 + x + 1)
    check_degrees(3, [1, 2, 0, 1, 0, 0, 1], [6], True)
    check_degrees(5, [1, 0, 0, 0, 0, 0, 0, 0, 1], [4, 4], False)  # x^8 + 1
    check_degrees(7, [3, 1, 4, 1, 5, 2, 2, 6, 1], [8], True)
    check_degrees(5, [0, 2, 4, 3, 4, 3, 1, 1], [1, 1, 2, 3], False)
    var mixed = PolyFp(prime_field(5), [0, 2, 4, 3, 4, 3, 1, 1])
    assert_equal(poly_fp_root_count(mixed), 2)
    var parts = poly_fp_distinct_degree(mixed)
    assert_equal(len(parts), 3)
    same(parts[0].product, [0, 1, 1])  # x (x + 1)
    var square = PolyFp(prime_field(3), [1, 2, 1])
    assert_false(poly_fp_is_squarefree(square))
    with assert_raises(contains="not squarefree"):
        _ = poly_fp_factor_degrees(square)
    # f = g(x^p) has f' = 0.
    assert_false(poly_fp_is_squarefree(PolyFp(prime_field(3), [1, 0, 0, 1])))
    with assert_raises(contains="composite"):
        _ = poly_fp_factor_degrees(PolyFp(Modulus(9), [1, 1, 0, 1]))
    same(poly_fp_frobenius_power(PolyFp(prime_field(3), [1, 2, 0, 1, 0, 0, 1]), 2), [1, 2, 0, 0, 1])


def test_irreducibility_certificate() raises:
    var f = PolyFp(prime_field(3), [1, 2, 0, 1, 0, 0, 1])
    var c = poly_fp_irreducibility_certificate(f)
    assert_equal(len(c.divisors), 2)
    assert_equal(c.divisors[0], 2)
    assert_equal(c.divisors[1], 3)
    assert_true(poly_fp_certificate_valid(c))
    var forged = c.copy()
    forged.s[0] = poly_fp_add(forged.s[0], PolyFp(f.modulus, [1]))
    assert_false(poly_fp_certificate_valid(forged))
    var dropped = c.copy()
    _ = dropped.divisors.pop()
    assert_false(poly_fp_certificate_valid(dropped))
    var reducible = PolyFp(prime_field(5), [1, 0, 0, 0, 0, 0, 0, 0, 1])
    with assert_raises(contains="reducible"):
        _ = poly_fp_irreducibility_certificate(reducible)
    # A certificate carried over to a reducible polynomial fails replay.
    var moved = c.copy()
    moved.f = PolyFp(f.modulus, [2, 0, 0, 0, 0, 0, 1])  # x^6 + 2 = (x - 1)^3 (x + 1)^3 mod 3
    assert_false(poly_fp_certificate_valid(moved))
    assert_true(poly_fp_certificate_valid(poly_fp_irreducibility_certificate(PolyFp(prime_field(7), [3, 1]))))


def test_hensel_step() raises:
    # A_{2,1}(C) = C^4 + 2 C^3 = C^3 (C + 2): the root -2 = 3 mod 5 is simple.
    var f = PolyFp(Modulus(25), [0, 0, 0, 2, 1])
    var step = hensel_step(f, -2, 5)
    assert_equal(step.base, 3)
    assert_equal(step.digit, 4)
    assert_equal(step.lifted, 23)
    assert_equal(step.modulus, 25)
    assert_true(hensel_step_valid(f, step))
    assert_false(hensel_step_valid(f, HenselStep(5, 3, 3, 18, 25)))
    with assert_raises(contains="not a simple root"):
        _ = hensel_step(f, 0, 5)
    with assert_raises(contains="not a root"):
        _ = hensel_step(f, 1, 5)
    with assert_raises():
        _ = hensel_step(PolyFp(Modulus(5), [0, 0, 0, 2, 1]), -2, 5)
    with assert_raises():
        _ = hensel_step(PolyFp(Modulus(81), [0, 0, 0, 2, 1]), -2, 9)


def main() raises:
    test_moduli_and_residues()
    print("[PASS] test_moduli_and_residues")
    test_ring_operations()
    print("[PASS] test_ring_operations")
    test_distinct_degree_factorization()
    print("[PASS] test_distinct_degree_factorization")
    test_irreducibility_certificate()
    print("[PASS] test_irreducibility_certificate")
    test_hensel_step()
    print("[PASS] test_hensel_step")
    print("5 polynomial_fp Mojo tests passed.")
