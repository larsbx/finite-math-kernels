"""Exact quadratic-germ coefficient vectors.

The pinned q=3,4,5 values are the same algebraic values used by the
Mandelbrot bulb/Ford-circle research register, but this suite reconstructs
them without Arb, FFTs, transcendental roots of unity, or floating point.
"""

from std.testing import assert_false, assert_true

from finite_exact.rat_q import Q
from finite_polynomial.cyclotomic_q import (
    CyclotomicQ,
    cyclotomic_automorphism,
    cyclotomic_equal,
    cyclotomic_from_coeffs,
    cyclotomic_zero,
)
from finite_polynomial.quadratic_germ import quadratic_germ_index_coefficient


def common_denominator_vector(
    conductor: Int,
    numerators: List[Int64],
    denominator: Int64,
) -> CyclotomicQ:
    var coefficients = List[Q]()
    for numerator in numerators:
        coefficients.append(Q(numerator, denominator))
    return cyclotomic_from_coeffs(conductor, coefficients)


def test_q1_q2_exact_values() raises:
    assert_true(
        cyclotomic_equal(
            quadratic_germ_index_coefficient(1, 1),
            cyclotomic_zero(1),
        )
    )
    assert_true(
        cyclotomic_equal(
            quadratic_germ_index_coefficient(1, 2),
            common_denominator_vector(2, [1], 8),
        )
    )


def test_q3_exact_value() raises:
    # (92 - 16 zeta_3) / 441.
    assert_true(
        cyclotomic_equal(
            quadratic_germ_index_coefficient(1, 3),
            common_denominator_vector(3, [92, -16], 441),
        )
    )


def test_q4_exact_value_and_conjugation() raises:
    # (1447 - 365 zeta_4) / 4624, with zeta_4 = i.
    var forward = quadratic_germ_index_coefficient(1, 4)
    var expected = common_denominator_vector(4, [1447, -365], 4624)
    assert_true(cyclotomic_equal(forward, expected))

    var backward = quadratic_germ_index_coefficient(3, 4)
    assert_true(
        cyclotomic_equal(
            backward,
            cyclotomic_automorphism(forward, 3),
        )
    )


def test_q5_exact_value_and_galois_transport() raises:
    # Ford register:
    # (1068*31 - 9153 zeta - 7113 zeta^2 - 312 zeta^3) / 93775.
    var forward = quadratic_germ_index_coefficient(1, 5)
    var expected = common_denominator_vector(
        5,
        [33108, -9153, -7113, -312],
        93775,
    )
    assert_true(cyclotomic_equal(forward, expected))

    var p2 = quadratic_germ_index_coefficient(2, 5)
    assert_true(
        cyclotomic_equal(
            p2,
            cyclotomic_automorphism(forward, 2),
        )
    )


def test_malformed_internal_fraction_refuses() raises:
    assert_false(quadratic_germ_index_coefficient(0, 5).accepted())
    assert_false(quadratic_germ_index_coefficient(2, 4).accepted())
    assert_false(quadratic_germ_index_coefficient(1, 0).accepted())


def main() raises:
    test_q1_q2_exact_values()
    print("[PASS] test_q1_q2_exact_values")
    test_q3_exact_value()
    print("[PASS] test_q3_exact_value")
    test_q4_exact_value_and_conjugation()
    print("[PASS] test_q4_exact_value_and_conjugation")
    test_q5_exact_value_and_galois_transport()
    print("[PASS] test_q5_exact_value_and_galois_transport")
    test_malformed_internal_fraction_refuses()
    print("[PASS] test_malformed_internal_fraction_refuses")
    print("5 exact quadratic-germ coefficient tests passed.")
