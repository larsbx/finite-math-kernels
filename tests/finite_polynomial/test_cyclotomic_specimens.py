"""Pinned Phi_n specimens of the Mojo foundation, replayed by the independent reference."""

from functools import reduce

from cyclotomic_reference import _poly_mul, cyclotomic_polynomial

SPECIMENS = {
    1: (-1, 1),
    2: (1, 1),
    3: (1, 1, 1),
    4: (1, 0, 1),
    6: (1, -1, 1),
    8: (1, 0, 0, 0, 1),
    9: (1, 0, 0, 1, 0, 0, 1),
    10: (1, -1, 1, -1, 1),
    12: (1, 0, -1, 0, 1),
}


def test_known_cyclotomic_polynomials():
    assert {n: cyclotomic_polynomial(n) for n in SPECIMENS} == SPECIMENS


def test_product_identity_through_32():
    """x^n - 1 = prod_{d | n} Phi_d."""
    for n in range(1, 33):
        divisors = (d for d in range(1, n + 1) if n % d == 0)
        assert reduce(_poly_mul, map(cyclotomic_polynomial, divisors)) == (-1,) + (0,) * (n - 1) + (1,)
