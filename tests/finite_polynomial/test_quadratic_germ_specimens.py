"""Pinned Q1/Q2 specimens of kernel/finite_polynomial/quadratic_germ.mojo, replayed by the independent reference."""

from fractions import Fraction as F

from cyclotomic_reference import (
    automorphism,
    constant,
    from_polynomial,
    parabolic_factor,
    reciprocal_series_coefficient,
    zeta_power,
)


def index_coefficient(p: int, q: int):
    """[w^q] 1/P(w) with w - g^q(w) = w^(q+1) P(w), g(w) = zeta_q^p w + w^2."""
    return reciprocal_series_coefficient(parabolic_factor(zeta_power(q, p), q), q)


def test_q1_q2():
    assert index_coefficient(1, 1) == constant(1, 0)
    assert index_coefficient(1, 2) == constant(2, F(1, 8))


def test_q3_exact():
    assert index_coefficient(1, 3) == from_polynomial(3, (F(92, 441), F(-16, 441)))


def test_q4_exact_and_conjugate():
    forward = index_coefficient(1, 4)
    assert forward == from_polynomial(4, (F(1447, 4624), F(-365, 4624)))
    assert index_coefficient(3, 4) == automorphism(forward, 3)


def test_q5_exact_and_galois():
    forward = index_coefficient(1, 5)
    assert forward == from_polynomial(5, tuple(F(n, 93775) for n in (33108, -9153, -7113, -312)))
    assert index_coefficient(2, 5) == automorphism(forward, 2)
