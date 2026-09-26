from fractions import Fraction

import pytest

from tools.cyclotomic_quotient_reference import (
    add,
    automorphism,
    div,
    inverse,
    mul,
    one,
    power,
    reduce_coefficients,
    zero,
    zeta,
)


def test_small_exact_relations():
    assert zeta(1) == one(1)
    assert zeta(2) == reduce_coefficients(2, [-1])
    assert add(add(power(zeta(3), 2), zeta(3)), one(3)) == zero(3)
    assert power(zeta(4), 2) == reduce_coefficients(4, [-1])


def test_root_of_unity_identity():
    for conductor in range(1, 17):
        assert power(zeta(conductor), conductor) == one(conductor)


def test_high_degree_relation_reduces_to_zero():
    assert reduce_coefficients(4, [1, 0, 1]) == zero(4)


def test_rational_coefficients():
    value = reduce_coefficients(4, [Fraction(1, 2), Fraction(1, 3)])
    conjugate = reduce_coefficients(4, [Fraction(1, 2), Fraction(-1, 3)])
    assert mul(value, conjugate) == reduce_coefficients(4, [Fraction(13, 36)])


def test_field_inverse():
    value = reduce_coefficients(5, [2, -1, 3, 1])
    assert mul(value, inverse(value)) == one(5)
    assert div(value, value) == one(5)
    with pytest.raises(ZeroDivisionError):
        inverse(zero(5))


def test_galois_composition_and_refusal():
    assert automorphism(zeta(4), 3) == reduce_coefficients(4, [0, -1])
    with pytest.raises(ValueError):
        automorphism(zeta(4), 2)

    value = reduce_coefficients(5, [2, -1, 3, 1])
    assert automorphism(automorphism(value, 2), 3) == value


def test_conductors_do_not_mix():
    with pytest.raises(ValueError):
        add(zero(3), zero(4))
