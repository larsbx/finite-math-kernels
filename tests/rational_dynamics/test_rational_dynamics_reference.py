from fractions import Fraction

import pytest

from tools.rational_dynamics_reference import (
    address,
    continued_fraction,
    convergents,
    double_mod_one,
    farey_adjacent,
    farey_determinant,
    mod_inverse,
    signed_mod_inverse,
)


def test_reference_vectors():
    assert address(7, 21) == address(1, 3)
    assert address(-1, 3) == address(2, 3)
    assert double_mod_one(address(2, 3)) == address(1, 3)
    assert mod_inverse(address(2, 5)) == 3
    assert signed_mod_inverse(address(2, 5)) == -2
    assert signed_mod_inverse(address(1, 2)) == 1
    assert mod_inverse(address(0, 1)) == 0
    assert continued_fraction(address(2, 5)) == (0, 2, 2)
    assert convergents(address(2, 5)) == (
        Fraction(0, 1),
        Fraction(1, 2),
        Fraction(2, 5),
    )
    assert farey_determinant(address(1, 3), address(2, 5)) == -1
    assert farey_adjacent(address(1, 3), address(2, 5))
    assert not farey_adjacent(address(1, 3), address(3, 7))


def test_reference_rejects_bad_denominator():
    with pytest.raises(ValueError):
        address(1, 0)
    with pytest.raises(ValueError):
        address(1, -3)


def test_beyond_int64_reference_path():
    n = 2**63 + 1
    d = 2 * n + 1
    a = address(n, d)
    inv = mod_inverse(a)
    assert (a.numerator * inv) % a.denominator == 1
