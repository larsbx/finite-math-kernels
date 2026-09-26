"""Executable laws for exact Q[zeta_n] quotient arithmetic.

This is finite algebra only.  No numerical embedding of zeta_n is used.
"""

from std.testing import assert_false, assert_true

from finite_exact.rat_q import Q
from finite_polynomial.cyclotomic_q import (
    cyclotomic_add,
    cyclotomic_automorphism,
    cyclotomic_bytes_equal,
    cyclotomic_canonical_bytes,
    cyclotomic_equal,
    cyclotomic_from_coeffs,
    cyclotomic_mul,
    cyclotomic_one,
    cyclotomic_pow,
    cyclotomic_zero,
    zeta,
)


def from_i64s(conductor: Int, values: List[Int64]):
    var coefficients = List[Q]()
    for value in values:
        coefficients.append(Q(value, 1))
    return cyclotomic_from_coeffs(conductor, coefficients)


def test_small_conductors_reduce_exactly() raises:
    var z1 = zeta(1)
    assert_true(cyclotomic_equal(z1, cyclotomic_one(1)))

    var z2 = zeta(2)
    assert_true(cyclotomic_equal(z2, from_i64s(2, [-1])))

    var z3 = zeta(3)
    var phi3_at_zeta = cyclotomic_add(
        cyclotomic_add(cyclotomic_pow(z3, 2), z3),
        cyclotomic_one(3),
    )
    assert_true(cyclotomic_equal(phi3_at_zeta, cyclotomic_zero(3)))

    var z4 = zeta(4)
    assert_true(
        cyclotomic_equal(
            cyclotomic_pow(z4, 2),
            from_i64s(4, [-1]),
        )
    )


def test_root_of_unity_identity() raises:
    for conductor in range(1, 13):
        var generator = zeta(conductor)
        assert_true(generator.accepted())
        assert_true(
            cyclotomic_equal(
                cyclotomic_pow(generator, conductor),
                cyclotomic_one(conductor),
            )
        )


def test_high_degree_input_reduces_canonically() raises:
    # In Q[X]/(X^2+1), 1 + X^2 is zero.
    var relation = from_i64s(4, [1, 0, 1])
    var zero = cyclotomic_zero(4)
    assert_true(cyclotomic_equal(relation, zero))
    assert_true(
        cyclotomic_bytes_equal(
            cyclotomic_canonical_bytes(relation),
            cyclotomic_canonical_bytes(zero),
        )
    )


def test_rational_coefficients_remain_exact() raises:
    var coefficients = List[Q]()
    coefficients.append(Q(1, 2))
    coefficients.append(Q(1, 3))
    var value = cyclotomic_from_coeffs(4, coefficients)

    # (1/2 + zeta/3)(1/2 - zeta/3) = 1/4 + 1/9 = 13/36.
    var conjugate_coefficients = List[Q]()
    conjugate_coefficients.append(Q(1, 2))
    conjugate_coefficients.append(Q(-1, 3))
    var conjugate = cyclotomic_from_coeffs(4, conjugate_coefficients)
    var product = cyclotomic_mul(value, conjugate)

    var expected_coefficients = List[Q]()
    expected_coefficients.append(Q(13, 36))
    assert_true(
        cyclotomic_equal(
            product,
            cyclotomic_from_coeffs(4, expected_coefficients),
        )
    )


def test_galois_action_is_exact() raises:
    var z4 = zeta(4)
    var conjugated = cyclotomic_automorphism(z4, 3)
    assert_true(cyclotomic_equal(conjugated, from_i64s(4, [0, -1])))
    assert_false(cyclotomic_automorphism(z4, 2).accepted())

    var value = from_i64s(5, [2, -1, 3, 1])
    var sigma2 = cyclotomic_automorphism(value, 2)
    var sigma3_sigma2 = cyclotomic_automorphism(sigma2, 3)
    # 3*2 = 6 = 1 mod 5.
    assert_true(cyclotomic_equal(sigma3_sigma2, value))


def test_conductor_is_part_of_identity_and_encoding() raises:
    var zero3 = cyclotomic_zero(3)
    var zero4 = cyclotomic_zero(4)
    assert_false(cyclotomic_equal(zero3, zero4))
    assert_false(
        cyclotomic_bytes_equal(
            cyclotomic_canonical_bytes(zero3),
            cyclotomic_canonical_bytes(zero4),
        )
    )
    assert_false(cyclotomic_add(zero3, zero4).accepted())


def test_invalid_conductor_and_rejected_coefficient_fail_closed() raises:
    assert_false(zeta(0).accepted())
    var coefficients = List[Q]()
    coefficients.append(Q(1, 0))
    assert_false(cyclotomic_from_coeffs(5, coefficients).accepted())


def main() raises:
    test_small_conductors_reduce_exactly()
    print("[PASS] test_small_conductors_reduce_exactly")
    test_root_of_unity_identity()
    print("[PASS] test_root_of_unity_identity")
    test_high_degree_input_reduces_canonically()
    print("[PASS] test_high_degree_input_reduces_canonically")
    test_rational_coefficients_remain_exact()
    print("[PASS] test_rational_coefficients_remain_exact")
    test_galois_action_is_exact()
    print("[PASS] test_galois_action_is_exact")
    test_conductor_is_part_of_identity_and_encoding()
    print("[PASS] test_conductor_is_part_of_identity_and_encoding")
    test_invalid_conductor_and_rejected_coefficient_fail_closed()
    print("[PASS] test_invalid_conductor_and_rejected_coefficient_fail_closed")
    print("7 cyclotomic quotient Mojo tests passed.")
