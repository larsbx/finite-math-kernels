"""Machine-integer helpers of finite_exact: gcd, checked arithmetic, base ten.

Run with `pixi run test-machine-int`.

The checked operations are pinned at the edges of the 64-bit range, where a
wrapping implementation would return a wrong number instead of raising; the
gcd at signs and zeros; and the renderer at the limb boundaries.
"""

from std.testing import assert_equal, assert_true

from finite_exact.checked_int import checked_abs, checked_add, checked_mul, checked_neg, checked_sub
from finite_exact.exact_decimal import exact_decimal_smoke
from finite_exact.integer_gcd import gcd_i64, gcd_i64_or_one, gcd_int
from finite_linear_algebra.integer_vector import matvec


def raises_add(a: Int, b: Int) -> Bool:
    try:
        _ = checked_add(a, b)
        return False
    except:
        return True


def raises_sub(a: Int, b: Int) -> Bool:
    try:
        _ = checked_sub(a, b)
        return False
    except:
        return True


def raises_mul(a: Int, b: Int) -> Bool:
    try:
        _ = checked_mul(a, b)
        return False
    except:
        return True


def raises_neg(a: Int) -> Bool:
    try:
        _ = checked_neg(a)
        return False
    except:
        return True


def raises_abs(a: Int) -> Bool:
    try:
        _ = checked_abs(a)
        return False
    except:
        return True


def raises_gcd(a: Int, b: Int) -> Bool:
    try:
        _ = gcd_int(a, b)
        return False
    except:
        return True


def raises_gcd_i64(a: Int64, b: Int64) -> Bool:
    try:
        _ = gcd_i64(a, b)
        return False
    except:
        return True


def test_checked_arithmetic_is_exact_in_range() raises:
    assert_equal(checked_add(Int.MAX - 1, 1), Int.MAX)
    assert_equal(checked_sub(Int.MIN + 1, 1), Int.MIN)
    assert_equal(checked_mul(-3037000499, 3037000499), -9223372030926249001)
    assert_equal(checked_neg(Int.MAX), -Int.MAX)
    assert_equal(checked_abs(-7), 7)


def test_checked_arithmetic_refuses_past_the_range() raises:
    assert_true(raises_add(Int.MAX, 1))
    assert_true(raises_add(Int.MIN, -1))
    assert_true(raises_sub(Int.MIN, 1))
    assert_true(raises_sub(Int.MAX, -1))
    assert_true(raises_mul(Int.MAX, 2))
    assert_true(raises_mul(Int.MIN, -1))
    assert_true(raises_mul(Int.MIN, 2))
    assert_true(raises_mul(-1, Int.MIN))
    assert_true(raises_mul(3037000500, 3037000500))
    assert_true(raises_neg(Int.MIN))
    assert_true(raises_abs(Int.MIN))


def test_gcd_ignores_signs_and_fixes_zero() raises:
    assert_equal(gcd_int(12, 18), 6)
    assert_equal(gcd_int(-12, 18), 6)
    assert_equal(gcd_int(0, -5), 5)
    assert_equal(gcd_int(0, 0), 0)
    assert_equal(gcd_i64(Int64(-21), Int64(-14)), Int64(7))
    assert_equal(gcd_i64_or_one(Int64(0), Int64(0)), Int64(1))
    assert_equal(gcd_i64_or_one(Int64(4), Int64(6)), Int64(2))


def test_products_at_the_negative_boundary() raises:
    assert_equal(checked_mul(Int.MIN, 1), Int.MIN)
    assert_equal(checked_mul(1, Int.MIN), Int.MIN)
    assert_equal(checked_mul(Int.MIN, 0), 0)
    assert_equal(checked_mul(0, Int.MIN), 0)
    # The result may equal MIN even when neither operand does.
    assert_equal(checked_mul(-4611686018427387904, 2), Int.MIN)
    assert_equal(checked_mul(2, -4611686018427387904), Int.MIN)
    var m: List[List[Int]] = [[1]]
    var v: List[Int] = [Int.MIN]
    assert_equal(matvec(m, v)[0], Int.MIN)


def test_gcd_signed_minima() raises:
    assert_equal(gcd_int(Int.MIN, 1), 1)
    assert_equal(gcd_int(2, Int.MIN), 2)
    assert_equal(gcd_int(Int.MIN, -3), 1)
    assert_equal(gcd_i64(Int64.MIN, Int64(2)), Int64(2))
    assert_equal(gcd_i64(Int64(-3), Int64.MIN), Int64(1))
    assert_equal(gcd_i64_or_one(Int64.MIN, Int64(1)), Int64(1))
    assert_true(raises_gcd(Int.MIN, 0))
    assert_true(raises_gcd(0, Int.MIN))
    assert_true(raises_gcd(Int.MIN, Int.MIN))
    assert_true(raises_gcd_i64(Int64.MIN, Int64(0)))
    assert_true(raises_gcd_i64(Int64(0), Int64.MIN))
    assert_true(raises_gcd_i64(Int64.MIN, Int64.MIN))
    var refused = False
    try:
        _ = gcd_i64_or_one(Int64.MIN, Int64(0))
    except:
        refused = True
    assert_true(refused)


def test_decimal_rendering_is_exact() raises:
    assert_true(exact_decimal_smoke())


def main() raises:
    test_checked_arithmetic_is_exact_in_range()
    print("[PASS] test_checked_arithmetic_is_exact_in_range")
    test_checked_arithmetic_refuses_past_the_range()
    print("[PASS] test_checked_arithmetic_refuses_past_the_range")
    test_gcd_ignores_signs_and_fixes_zero()
    print("[PASS] test_gcd_ignores_signs_and_fixes_zero")
    test_decimal_rendering_is_exact()
    print("[PASS] test_decimal_rendering_is_exact")
    test_products_at_the_negative_boundary()
    print("[PASS] test_products_at_the_negative_boundary")
    test_gcd_signed_minima()
    print("[PASS] test_gcd_signed_minima")
    print("6 machine-integer tests passed.")
