from fractions import Fraction

import pytest

from tools.cyclotomic_quotient_reference import automorphism, reduce_coefficients, zero
from tools.quadratic_germ_reference import index_coefficient


def test_q1_q2():
    assert index_coefficient(1, 1) == zero(1)
    assert index_coefficient(1, 2) == reduce_coefficients(2, [Fraction(1, 8)])


def test_q3_exact():
    assert index_coefficient(1, 3) == reduce_coefficients(
        3, [Fraction(92, 441), Fraction(-16, 441)]
    )


def test_q4_exact_and_conjugate():
    forward = index_coefficient(1, 4)
    assert forward == reduce_coefficients(
        4, [Fraction(1447, 4624), Fraction(-365, 4624)]
    )
    assert index_coefficient(3, 4) == automorphism(forward, 3)


def test_q5_exact_and_galois():
    forward = index_coefficient(1, 5)
    assert forward == reduce_coefficients(
        5,
        [
            Fraction(33108, 93775),
            Fraction(-9153, 93775),
            Fraction(-7113, 93775),
            Fraction(-312, 93775),
        ],
    )
    assert index_coefficient(2, 5) == automorphism(forward, 2)


@pytest.mark.parametrize("p,q", [(0, 5), (2, 4), (1, 0)])
def test_bad_fraction_refuses(p, q):
    with pytest.raises(ValueError):
        index_coefficient(p, q)
