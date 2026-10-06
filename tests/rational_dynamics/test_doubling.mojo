"""Executable laws for the doubling-map number theory of rational_dynamics:
the modules doubling, multiplicative_order, carmichael, moebius and integers.

Run with `pixi run test-rational-dynamics`. The Python twin
`oracles/rational_dynamics_py` recomputes a transcript of the same functions
(`tests/rational_dynamics/test_doubling_twin.py`).
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_eq, bigz_from_i64, bigz_mul, bigz_sub
from rational_dynamics.carmichael import carmichael_lambda
from rational_dynamics.doubling import (
    binary_block,
    binary_digits,
    exact_type,
    exact_type_count,
    period,
    preperiod,
)
from rational_dynamics.integers import bigz_to_int
from rational_dynamics.moebius import moebius
from rational_dynamics.multiplicative_order import order_of_two
from rational_dynamics.rational import (
    ReducedFraction,
    double_mod_one,
    fraction_equal,
    fraction_from_i64,
    rejected_fraction,
)


def is_int(value: BigZ, expected: Int64) -> Bool:
    return bigz_eq(value, bigz_from_i64(expected))


def power(base: Int64, exponent: Int) -> BigZ:
    var out = bigz_from_i64(1)
    for _ in range(exponent):
        out = bigz_mul(out, bigz_from_i64(base))
    return out^


def orbit_term(t: ReducedFraction, steps: Int) -> ReducedFraction:
    var current = t.copy()
    for _ in range(steps):
        current = double_mod_one(current)
    return current^


def test_closed_forms_agree_with_the_orbit() raises:
    """Every angle with denominator below 48, reduced or not: the orbit first
    repeats at exactly the stated preperiod, with exactly the stated period."""
    for den in range(1, 48):
        for num in range(den):
            var t = fraction_from_i64(Int64(num), Int64(den))
            var found = exact_type(t)
            assert_true(found.accepted())
            var l = found.preperiod
            var k = bigz_to_int(found.period)
            assert_equal(l, preperiod(t))
            assert_true(bigz_eq(found.period, period(t).value))
            assert_true(fraction_equal(orbit_term(t, l + k), orbit_term(t, l)))
            if l > 0:
                assert_false(fraction_equal(orbit_term(t, l + k - 1), orbit_term(t, l - 1)))
            for shorter in range(1, k):
                if k % shorter == 0:
                    assert_false(fraction_equal(orbit_term(t, l + shorter), orbit_term(t, l)))


def test_order_of_two_is_exact_and_uncapped() raises:
    assert_true(is_int(order_of_two(bigz_from_i64(1)).value, 1))
    assert_true(is_int(order_of_two(bigz_from_i64(3)).value, 2))
    assert_true(is_int(order_of_two(bigz_from_i64(7)).value, 3))
    # Past the direct-powering threshold: the Carmichael route.
    assert_true(is_int(order_of_two(bigz_from_i64(10007)).value, 5003))
    assert_true(is_int(order_of_two(bigz_from_i64(59049)).value, 39366))
    # Mersenne denominators past the old cap of 64, and past Int64.
    var m127 = bigz_sub(power(2, 127), bigz_from_i64(1))
    assert_true(is_int(order_of_two(m127).value, 127))
    # 2 is a primitive root modulo every power of 3: ord = 2 * 3^49 > 2^63.
    var big = order_of_two(power(3, 50))
    assert_true(big.accepted())
    assert_true(bigz_eq(big.value, bigz_mul(bigz_from_i64(2), power(3, 49))))
    # Two is not a unit modulo an even or non-positive modulus.
    assert_false(order_of_two(bigz_from_i64(0)).accepted())
    assert_false(order_of_two(bigz_from_i64(2)).accepted())
    assert_false(order_of_two(bigz_from_i64(12)).accepted())
    assert_false(order_of_two(bigz_from_i64(-3)).accepted())


def test_carmichael_lambda() raises:
    # lambda(1) = 1, lambda(15) = lcm(2, 4) = 4, lambda(3^10) = 2 * 3^9, lambda(105) = 12.
    assert_true(is_int(carmichael_lambda(bigz_from_i64(1)).value, 1))
    assert_true(is_int(carmichael_lambda(bigz_from_i64(15)).value, 4))
    assert_true(is_int(carmichael_lambda(bigz_from_i64(59049)).value, 39366))
    assert_true(is_int(carmichael_lambda(bigz_from_i64(105)).value, 12))
    # The order divides lambda: 2^lambda(m) = 1 for every odd m below 400.
    for m in range(1, 400, 2):
        var lam = carmichael_lambda(bigz_from_i64(Int64(m))).value.copy()
        var order = order_of_two(bigz_from_i64(Int64(m))).value.copy()
        assert_equal(bigz_to_int(lam) % bigz_to_int(order), 0)
    assert_false(carmichael_lambda(bigz_from_i64(12)).accepted())
    assert_false(carmichael_lambda(bigz_from_i64(0)).accepted())


def test_types_past_the_fixed_width_cap() raises:
    # 1/(2^7 * 10007): preperiod 7 and period 5003, far past angle_doubling's 64.
    var t = fraction_from_i64(5, 128 * 10007)
    assert_equal(preperiod(t), 7)
    assert_true(is_int(period(t).value, 5003))
    # The Mandelbrot catalogue's examples: 1/58 is (1, 28), 1/50 is (1, 20).
    var a = exact_type(fraction_from_i64(1, 58))
    var b = exact_type(fraction_from_i64(1, 50))
    assert_true(a.preperiod == 1 and is_int(a.period, 28))
    assert_true(b.preperiod == 1 and is_int(b.period, 20))
    # Q/Z semantics at the boundary: 9/7 is the angle 2/7.
    var nine_sevenths = exact_type(fraction_from_i64(9, 7))
    assert_true(nine_sevenths.preperiod == 0 and is_int(nine_sevenths.period, 3))
    # A rejected fraction has no type.
    assert_false(exact_type(rejected_fraction()).accepted())
    assert_equal(preperiod(rejected_fraction()), -1)
    assert_false(period(rejected_fraction()).accepted())


def test_binary_digits_and_blocks() raises:
    var one_third: List[Int] = [0, 1]
    var sixth_digits: List[Int] = [0, 0, 1, 0, 1]
    var seven_fifteenths: List[Int] = [0, 1, 1, 1]
    var zero_block: List[Int] = [0]
    assert_equal(binary_digits(fraction_from_i64(1, 3), 2).digits, one_third)
    assert_equal(binary_digits(fraction_from_i64(1, 6), 5).digits, sixth_digits)
    assert_equal(binary_block(fraction_from_i64(1, 6)).digits, one_third)
    assert_equal(binary_block(fraction_from_i64(7, 15)).digits, seven_fifteenths)
    # Dyadic: the terminating expansion, so 1/2 = 0.1(0) and 5/4 is 1/4 = 0.01(0).
    assert_equal(binary_block(fraction_from_i64(1, 2)).digits, zero_block)
    assert_equal(binary_block(fraction_from_i64(0, 1)).digits, zero_block)
    var five_quarters: List[Int] = [0, 1, 0]
    assert_equal(binary_digits(fraction_from_i64(5, 4), 3).digits, five_quarters)
    # A periodic angle j / (2^k - 1) has block j in k bits.
    for k in range(1, 8):
        var den = (1 << k) - 1
        for j in range(den):
            var block = binary_block(fraction_from_i64(Int64(j), Int64(den)))
            var value = 0
            for i in range(len(block.digits)):
                value = 2 * value + block.digits[i]
            var period_k = bigz_to_int(period(fraction_from_i64(Int64(j), Int64(den))).value)
            assert_equal(len(block.digits), period_k)
            # Read in k bits the block repeats k / period times.
            var repeated = 0
            for _ in range(k // period_k):
                repeated = (repeated << period_k) + value
            assert_equal(repeated, j)
    assert_equal(len(binary_digits(fraction_from_i64(1, 3), 0).digits), 0)
    assert_false(binary_digits(fraction_from_i64(1, 3), -1).accepted())
    assert_false(binary_digits(rejected_fraction(), 2).accepted())
    assert_false(binary_block(rejected_fraction()).accepted())


def test_exact_type_count_is_the_enumeration() raises:
    for l in range(0, 4):
        for k in range(1, 6):
            var den = (1 << l) * ((1 << k) - 1)
            var enumerated = 0
            for num in range(den):
                var found = exact_type(fraction_from_i64(Int64(num), Int64(den)))
                if found.preperiod == l and is_int(found.period, Int64(k)):
                    enumerated += 1
            assert_equal(bigz_to_int(exact_type_count(l, k).value), enumerated)
    assert_true(is_int(exact_type_count(2, 3).value, 12))
    assert_true(is_int(exact_type_count(3, 3).value, 24))
    # (2^64 - 1) - (2^32 - 1), past Int64.
    assert_true(bigz_eq(exact_type_count(0, 64).value, bigz_sub(power(2, 64), power(2, 32))))
    assert_false(exact_type_count(-1, 1).accepted())
    assert_false(exact_type_count(0, 0).accepted())


def test_moebius_values_and_refusal() raises:
    var expected: List[Int] = [1, -1, -1, 0, -1, 1, -1, 0, 0, 1, -1, 0]
    for n in range(1, 13):
        assert_equal(moebius(n), expected[n - 1])
    assert_equal(moebius(30), -1)
    assert_equal(moebius(210), 1)
    var caught = False
    try:
        _ = moebius(0)
    except:
        caught = True
    assert_true(caught)


def test_bigz_to_int_refuses_rather_than_truncates() raises:
    assert_equal(bigz_to_int(bigz_from_i64(9223372036854775807)), 9223372036854775807)
    assert_equal(bigz_to_int(bigz_from_i64(-123456789012)), -123456789012)
    assert_equal(bigz_to_int(bigz_from_i64(0)), 0)
    var caught = False
    try:
        _ = bigz_to_int(power(2, 63))
    except:
        caught = True
    assert_true(caught)


def main() raises:
    test_closed_forms_agree_with_the_orbit()
    print("[PASS] test_closed_forms_agree_with_the_orbit")
    test_order_of_two_is_exact_and_uncapped()
    print("[PASS] test_order_of_two_is_exact_and_uncapped")
    test_carmichael_lambda()
    print("[PASS] test_carmichael_lambda")
    test_types_past_the_fixed_width_cap()
    print("[PASS] test_types_past_the_fixed_width_cap")
    test_binary_digits_and_blocks()
    print("[PASS] test_binary_digits_and_blocks")
    test_exact_type_count_is_the_enumeration()
    print("[PASS] test_exact_type_count_is_the_enumeration")
    test_moebius_values_and_refusal()
    print("[PASS] test_moebius_values_and_refusal")
    test_bigz_to_int_refuses_rather_than_truncates()
    print("[PASS] test_bigz_to_int_refuses_rather_than_truncates")
    print("8 doubling Mojo tests passed.")
