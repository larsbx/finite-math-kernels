"""Executable laws for rational_dynamics.

Run with `pixi run test-rational-dynamics`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import (
    BigZ,
    bigz_add,
    bigz_eq,
    bigz_from_i64,
    bigz_mul,
)
from rational_dynamics.rational import (
    continued_fraction,
    convergents,
    double_mod_one,
    farey_adjacent,
    farey_determinant,
    fraction_equal,
    fraction_from_i64,
    mod_inverse,
    reduce_fraction,
    signed_mod_inverse,
)


def is_int(value: BigZ, expected: Int64) -> Bool:
    return bigz_eq(value, bigz_from_i64(expected))


def test_reduction_is_exact_and_unbounded() raises:
    assert_true(fraction_equal(fraction_from_i64(2, 4), fraction_from_i64(1, 2)))
    assert_true(fraction_equal(fraction_from_i64(0, 7), fraction_from_i64(0, 1)))
    assert_false(fraction_from_i64(-1, 3).accepted())
    assert_false(fraction_from_i64(1, 0).accepted())
    assert_false(fraction_from_i64(1, -3).accepted())

    # 2^63 cannot be represented by Int64, but BigZ reduction remains exact.
    var beyond_i64 = bigz_add(bigz_from_i64(9223372036854775807), bigz_from_i64(1))
    var wide = reduce_fraction(
        bigz_mul(beyond_i64, bigz_from_i64(3)),
        bigz_mul(beyond_i64, bigz_from_i64(7)),
    )
    assert_true(wide.accepted())
    assert_true(is_int(wide.num, 3))
    assert_true(is_int(wide.den, 7))


def test_doubling_is_explicitly_mod_one() raises:
    var one_third = fraction_from_i64(1, 3)
    var two_thirds = double_mod_one(one_third)
    assert_true(fraction_equal(two_thirds, fraction_from_i64(2, 3)))
    assert_true(fraction_equal(double_mod_one(two_thirds), one_third))
    assert_true(fraction_equal(double_mod_one(fraction_from_i64(3, 2)), fraction_from_i64(1, 2)))


def test_modular_inverse_and_centered_representative() raises:
    var inv_2_5 = mod_inverse(fraction_from_i64(2, 5))
    assert_true(fraction_equal(inv_2_5, fraction_from_i64(3, 5)))
    var signed_2_5 = signed_mod_inverse(fraction_from_i64(2, 5))
    assert_true(signed_2_5.accepted())
    assert_true(is_int(signed_2_5.num, -2))
    assert_true(is_int(signed_2_5.den, 5))

    var signed_3_7 = signed_mod_inverse(fraction_from_i64(3, 7))
    assert_true(signed_3_7.accepted())
    assert_true(is_int(signed_3_7.num, -2))
    assert_true(is_int(signed_3_7.den, 7))

    # The half-denominator tie stays positive: interval (-q/2, q/2].
    var signed_1_2 = signed_mod_inverse(fraction_from_i64(1, 2))
    assert_true(is_int(signed_1_2.num, 1))
    assert_true(is_int(signed_1_2.den, 2))

    assert_false(mod_inverse(fraction_from_i64(0, 1)).accepted())
    assert_false(mod_inverse(fraction_from_i64(2, 1)).accepted())


def test_continued_fraction_and_convergents() raises:
    var value = fraction_from_i64(3, 7)
    var expansion = continued_fraction(value)
    assert_true(expansion.accepted())
    assert_equal(len(expansion.terms), 3)
    assert_true(is_int(expansion.terms[0], 0))
    assert_true(is_int(expansion.terms[1], 2))
    assert_true(is_int(expansion.terms[2], 3))

    var conv = convergents(value)
    assert_true(conv.accepted())
    assert_equal(len(conv.numerators), 3)
    assert_equal(len(conv.denominators), 3)
    assert_true(is_int(conv.numerators[0], 0))
    assert_true(is_int(conv.denominators[0], 1))
    assert_true(is_int(conv.numerators[1], 1))
    assert_true(is_int(conv.denominators[1], 2))
    assert_true(is_int(conv.numerators[2], 3))
    assert_true(is_int(conv.denominators[2], 7))

    # Ford-side arithmetic identity for this specimen:
    # |centered inverse numerator| = previous convergent denominator = 2.
    var centered = signed_mod_inverse(value)
    assert_true(is_int(centered.num, -2))
    assert_true(bigz_eq(conv.denominators[1], bigz_from_i64(2)))


def test_farey_determinant_is_exact() raises:
    var left = fraction_from_i64(1, 3)
    var right = fraction_from_i64(2, 5)
    var determinant = farey_determinant(left, right)
    assert_true(determinant.accepted())
    assert_true(is_int(determinant.value, -1))
    assert_true(farey_adjacent(left, right))

    var apart = fraction_from_i64(3, 8)
    assert_false(farey_adjacent(left, apart))


def main() raises:
    test_reduction_is_exact_and_unbounded()
    print("[PASS] test_reduction_is_exact_and_unbounded")
    test_doubling_is_explicitly_mod_one()
    print("[PASS] test_doubling_is_explicitly_mod_one")
    test_modular_inverse_and_centered_representative()
    print("[PASS] test_modular_inverse_and_centered_representative")
    test_continued_fraction_and_convergents()
    print("[PASS] test_continued_fraction_and_convergents")
    test_farey_determinant_is_exact()
    print("[PASS] test_farey_determinant_is_exact")
    print("5 rational_dynamics Mojo tests passed.")
