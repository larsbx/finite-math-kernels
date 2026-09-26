"""Executable laws for finite_polynomial and the cyclotomic foundation.

Run with:
    mojo run -I . tests/finite_polynomial/test_polynomial_z.mojo
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import (
    BigZ,
    bigz_add,
    bigz_eq,
    bigz_from_i64,
    bigz_mul,
)
from finite_polynomial.polynomial_z import (
    cyclotomic_degree,
    cyclotomic_polynomial,
    cyclotomic_product_identity,
    poly_div_exact_monic,
    poly_equal,
    poly_from_coeffs,
    poly_from_i64,
    poly_mul,
    poly_xn_minus_one,
)


def coefficient_is(poly, index: Int, expected: Int64) -> Bool:
    if poly.rejected or index < 0 or index >= len(poly.coeffs):
        return False
    return bigz_eq(poly.coeffs[index], bigz_from_i64(expected))


def test_exact_monic_division() raises:
    # (x^4 - 1) / (x^2 - 1) = x^2 + 1.
    var dividend = poly_xn_minus_one(4)
    var divisor = poly_xn_minus_one(2)
    var division = poly_div_exact_monic(dividend, divisor)
    assert_true(division.accepted())
    assert_true(poly_equal(division.quotient, poly_from_i64([1, 0, 1])))

    # x^2 + 1 is not divisible by x + 1 over Z[x].
    var bad = poly_div_exact_monic(
        poly_from_i64([1, 0, 1]),
        poly_from_i64([1, 1]),
    )
    assert_false(bad.accepted())


def test_known_cyclotomic_polynomials() raises:
    var phi1 = cyclotomic_polynomial(1)
    assert_true(poly_equal(phi1, poly_from_i64([-1, 1])))

    var phi2 = cyclotomic_polynomial(2)
    assert_true(poly_equal(phi2, poly_from_i64([1, 1])))

    var phi3 = cyclotomic_polynomial(3)
    assert_true(poly_equal(phi3, poly_from_i64([1, 1, 1])))

    var phi4 = cyclotomic_polynomial(4)
    assert_true(poly_equal(phi4, poly_from_i64([1, 0, 1])))

    var phi6 = cyclotomic_polynomial(6)
    assert_true(poly_equal(phi6, poly_from_i64([1, -1, 1])))

    var phi8 = cyclotomic_polynomial(8)
    assert_true(poly_equal(phi8, poly_from_i64([1, 0, 0, 0, 1])))

    var phi9 = cyclotomic_polynomial(9)
    assert_true(poly_equal(phi9, poly_from_i64([1, 0, 0, 1, 0, 0, 1])))

    var phi10 = cyclotomic_polynomial(10)
    assert_true(poly_equal(phi10, poly_from_i64([1, -1, 1, -1, 1])))

    var phi12 = cyclotomic_polynomial(12)
    assert_true(poly_equal(phi12, poly_from_i64([1, 0, -1, 0, 1])))


def test_cyclotomic_product_identity() raises:
    for conductor in range(1, 17):
        assert_true(cyclotomic_product_identity(conductor))
    assert_false(cyclotomic_product_identity(0))


def test_cyclotomic_degrees() raises:
    assert_equal(cyclotomic_degree(1), 1)
    assert_equal(cyclotomic_degree(2), 1)
    assert_equal(cyclotomic_degree(3), 2)
    assert_equal(cyclotomic_degree(4), 2)
    assert_equal(cyclotomic_degree(5), 4)
    assert_equal(cyclotomic_degree(8), 4)
    assert_equal(cyclotomic_degree(9), 6)
    assert_equal(cyclotomic_degree(12), 4)


def test_polynomial_coefficients_are_unbounded() raises:
    var beyond_i64 = bigz_add(
        bigz_from_i64(9223372036854775807),
        bigz_from_i64(1),
    )
    var coeffs = List[BigZ]()
    coeffs.append(beyond_i64.copy())
    coeffs.append(bigz_from_i64(1))
    var p = poly_from_coeffs(coeffs)
    assert_true(p.accepted())

    var square = poly_mul(p, p)
    assert_true(square.accepted())
    assert_true(
        bigz_eq(
            square.coeffs[0],
            bigz_mul(beyond_i64, beyond_i64),
        )
    )


def main() raises:
    test_exact_monic_division()
    print("[PASS] test_exact_monic_division")
    test_known_cyclotomic_polynomials()
    print("[PASS] test_known_cyclotomic_polynomials")
    test_cyclotomic_product_identity()
    print("[PASS] test_cyclotomic_product_identity")
    test_cyclotomic_degrees()
    print("[PASS] test_cyclotomic_degrees")
    test_polynomial_coefficients_are_unbounded()
    print("[PASS] test_polynomial_coefficients_are_unbounded")
    print("5 finite_polynomial Mojo tests passed.")
