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
    # Conservative at one edge: Int.MIN * 1 fits, but the operands go through
    # checked_abs, so the product is refused. A refusal is inconclusive, never
    # a wrong number, which is the whole contract.
    assert_true(raises_mul(Int.MIN, 1))
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
    print("4 machine-integer tests passed.")
