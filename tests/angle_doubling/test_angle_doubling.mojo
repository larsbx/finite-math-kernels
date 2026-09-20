"""Executable laws for the angle_doubling package.

Run with `pixi run test-angle-doubling`.

The closed forms for preperiod and period are checked against the orbit they
describe, over every angle with a small denominator, which is the check that
would catch a wrong formula rather than a wrong example.
"""

from angle_doubling.angle import (
    Angle,
    angle_smoke,
    double,
    has_type,
    orbit_term,
    period,
    preperiod,
    type_count,
)


def test_closed_forms_agree_with_the_orbit() -> Bool:
    """For every angle with denominator up to 40: the orbit first repeats at
    exactly the stated preperiod, with exactly the stated period."""
    for den in range(1, 41):
        for num in range(0, den):
            var t = Angle.of(Int64(num), Int64(den))
            if not t.accepted():
                return False
            var l = preperiod(t)
            var k = period(t)
            if l < 0 or k < 1:
                return False
            # The orbit repeats at (l, k) ...
            if not orbit_term(t, l + k).eq(orbit_term(t, l)):
                return False
            # ... and at no smaller preperiod, unless the angle is periodic.
            if l > 0 and orbit_term(t, l + k - 1).eq(orbit_term(t, l - 1)):
                return False
            # ... and at no proper divisor of the period.
            for shorter in range(1, k):
                if k % shorter == 0 and orbit_term(t, l + shorter).eq(orbit_term(t, l)):
                    return False
    return True


def test_the_count_is_the_number_of_angles_of_that_type() -> Bool:
    """`2^l (2^k - 1)` counted by enumeration, for small `(l, k)`."""
    for l in range(0, 4):
        for k in range(1, 4):
            var total = type_count(l, k)
            if total < 0:
                return False
            var den = Int64(1) << Int64(l)
            var modulus = den * ((Int64(1) << Int64(k)) - 1)
            var counted: Int64 = 0
            for num in range(0, Int(modulus)):
                if has_type(Angle.of(Int64(num), modulus), l, k):
                    counted += 1
            if counted != total:
                return False
    return True


def main() raises:
    if not angle_smoke():
        raise Error("angle smoke failed")
    if not test_closed_forms_agree_with_the_orbit():
        raise Error("the closed forms disagree with the orbit")
    if not test_the_count_is_the_number_of_angles_of_that_type():
        raise Error("the type count is wrong")
    print("angle_doubling laws passed.")
