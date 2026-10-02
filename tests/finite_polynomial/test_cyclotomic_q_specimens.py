"""Pinned C1/C2 specimens of kernel/finite_polynomial/cyclotomic_q.mojo, replayed by the independent reference."""

from fractions import Fraction as F
from functools import reduce

import pytest

from cyclotomic_reference import add, automorphism, constant, from_polynomial, mul, zeta


def power(value, n: int):
    return reduce(mul, [value] * n, constant(value.conductor, 1))


def test_small_exact_relations():
    assert zeta(1) == constant(1, 1)
    assert zeta(2) == constant(2, -1)
    assert add(add(power(zeta(3), 2), zeta(3)), constant(3, 1)) == constant(3, 0)
    assert power(zeta(4), 2) == constant(4, -1)


@pytest.mark.parametrize("q", range(1, 17))
def test_root_of_unity_identity(q):
    assert power(zeta(q), q) == constant(q, 1)


def test_high_degree_relation_reduces_to_zero():
    assert from_polynomial(4, (1, 0, 1)) == constant(4, 0)


def test_rational_coefficients():
    value, conjugate = from_polynomial(4, (F(1, 2), F(1, 3))), from_polynomial(4, (F(1, 2), F(-1, 3)))
    assert mul(value, conjugate) == constant(4, F(13, 36))


def test_galois_composition_and_refusal():
    assert automorphism(zeta(4), 3) == from_polynomial(4, (0, -1))
    with pytest.raises(ValueError):
        automorphism(zeta(4), 2)
    value = from_polynomial(5, (2, -1, 3, 1))
    assert automorphism(automorphism(value, 2), 3) == value


def test_conductors_do_not_mix():
    with pytest.raises(ValueError):
        add(constant(3, 0), constant(4, 0))
