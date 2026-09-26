"""Laws and refusals of the C1-Q2 cyclotomic/germ reference."""

from __future__ import annotations

import json
import random
from fractions import Fraction as F
from functools import reduce
from math import gcd
from pathlib import Path

import pytest

from tools import make_cyclotomic_vectors
from tools.cyclotomic_reference import (
    add,
    automorphism,
    canonical_bytes,
    constant,
    cyclotomic,
    cyclotomic_polynomial,
    exact_equal,
    from_polynomial,
    inverse,
    mul,
    neg,
    parabolic_factor,
    phi,
    reciprocal_series,
    reciprocal_series_coefficient,
    sub,
    truncated_iterate,
    zeta,
    zeta_power,
)

CONDUCTORS = range(1, 13)


def element(q: int, rng: random.Random):
    return cyclotomic(q, [F(rng.randint(-9, 9), rng.randint(1, 5)) for _ in range(phi(q))])


def power(a, n: int):
    return reduce(mul, [a] * n, constant(a.conductor, 1))


# --- C1 ---------------------------------------------------------------------


def test_cyclotomic_polynomials_and_totient():
    assert cyclotomic_polynomial(1) == (-1, 1)
    assert cyclotomic_polynomial(4) == (1, 0, 1)
    assert cyclotomic_polynomial(6) == (1, -1, 1)
    assert cyclotomic_polynomial(12) == (1, 0, -1, 0, 1)
    assert [phi(q) for q in CONDUCTORS] == [1, 1, 2, 2, 4, 2, 6, 4, 6, 4, 10, 4]


@pytest.mark.parametrize("q", CONDUCTORS)
def test_zeta_has_exact_order_q(q):
    z = zeta(q)
    assert exact_equal(power(z, q), constant(q, 1))
    assert all(not exact_equal(power(z, d), constant(q, 1)) for d in range(1, q))


@pytest.mark.parametrize("q", CONDUCTORS)
def test_field_laws(q):
    rng = random.Random(q)
    for _ in range(10):
        a, b, c = (element(q, rng) for _ in range(3))
        assert exact_equal(mul(a, add(b, c)), add(mul(a, b), mul(a, c)))
        assert exact_equal(mul(mul(a, b), c), mul(a, mul(b, c)))
        assert exact_equal(sub(a, a), constant(q, 0))
        if any(a.coefficients):
            assert exact_equal(mul(a, inverse(a)), constant(q, 1))


def test_reduction_is_canonical_and_bytes_are_injective():
    assert exact_equal(from_polynomial(4, (0, 0, 1)), constant(4, -1))  # i^2 = -1
    assert canonical_bytes(constant(4, -1)) != canonical_bytes(constant(3, -1))
    assert canonical_bytes(constant(4, F(1, 2))) != canonical_bytes(constant(4, F(2, 4) + 1))
    assert canonical_bytes(constant(2, 0)).hex() == "010000000000000001" "02" "00" "0000000000000000" "010000000000000001" "01"


@pytest.mark.parametrize(
    "q,coefficients",
    [(4, [1]), (4, [1, 2, 3]), (3, [0.5, 1]), (3, [True, 1]), (3, ["1", 1])],
)
def test_constructor_refuses_noncanonical_or_inexact_vectors(q, coefficients):
    with pytest.raises(ValueError):
        cyclotomic(q, coefficients)


@pytest.mark.parametrize("q", [0, -3])
def test_nonpositive_conductor_is_refused(q):
    with pytest.raises(ValueError):
        zeta(q)


def test_zero_has_no_inverse_and_fields_do_not_mix():
    with pytest.raises(ValueError):
        inverse(constant(5, 0))
    with pytest.raises(ValueError):
        add(zeta(3), zeta(4))


# --- C2 ---------------------------------------------------------------------


@pytest.mark.parametrize("q", CONDUCTORS)
def test_automorphisms_are_ring_maps_and_compose(q):
    rng = random.Random(100 + q)
    units = [a for a in range(1, q + 1) if gcd(a, q) == 1]
    a, b = element(q, rng), element(q, rng)
    for s in units:
        sigma = lambda x: automorphism(x, s)
        assert exact_equal(sigma(mul(a, b)), mul(sigma(a), sigma(b)))
        assert exact_equal(sigma(add(a, b)), add(sigma(a), sigma(b)))
        assert exact_equal(sigma(zeta(q)), zeta_power(q, s))
        for t in units:
            assert exact_equal(automorphism(sigma(a), t), automorphism(a, s * t))


def test_automorphism_refuses_nonunit_exponent():
    with pytest.raises(ValueError):
        automorphism(zeta(6), 2)
    with pytest.raises(ValueError):
        automorphism(zeta(6), 3)


# --- Q1 / Q2 ----------------------------------------------------------------


def test_truncated_iterate_small_cases():
    one, lam = constant(2, 1), constant(2, -1)  # q=2, lambda = -1
    two_fold = truncated_iterate(lam, 2, 5)  # g(g(w)) = w - 2w^3 + w^4
    assert [c.coefficients[0] for c in two_fold] == [0, 1, 0, -2, 1]
    assert exact_equal(truncated_iterate(lam, 0, 3)[1], one)


@pytest.mark.parametrize("q", range(1, 9))
def test_parabolic_factor_has_invertible_constant(q):
    for p in [p for p in range(1, max(q, 2)) if gcd(p, q) == 1]:
        factor = parabolic_factor(zeta_power(q, p), q)
        assert len(factor) == q + 1
        assert any(factor[0].coefficients)


def test_parabolic_factor_refuses_nonresonant_multiplier():
    with pytest.raises(ValueError):
        parabolic_factor(zeta_power(6, 2), 6)  # order 3 < 6: the w^4 term survives
    with pytest.raises(ValueError):
        parabolic_factor(constant(1, 2), 1)  # not a root of unity: the linear term survives


def test_reciprocal_series_is_a_series_inverse_and_refuses_zero_constant():
    q = 5
    rng = random.Random(7)
    series = (constant(q, 3),) + tuple(element(q, rng) for _ in range(5))
    inv = reciprocal_series(series)
    product = [reduce(add, (mul(series[i], inv[k - i]) for i in range(k + 1)), constant(q, 0)) for k in range(6)]
    assert exact_equal(product[0], constant(q, 1))
    assert all(exact_equal(c, constant(q, 0)) for c in product[1:])
    with pytest.raises(ValueError):
        reciprocal_series((constant(q, 0),) + series[1:])
    with pytest.raises(ValueError):
        reciprocal_series_coefficient(series, 6)


def test_reciprocal_coefficient_low_conductor_values():
    coefficient = lambda p, q: reciprocal_series_coefficient(parabolic_factor(zeta_power(q, p), q), q)
    assert coefficient(1, 1).coefficients == (F(0),)
    assert coefficient(1, 2).coefficients == (F(1, 8),)
    assert coefficient(1, 3).coefficients == (F(92, 441), F(-16, 441))
    assert coefficient(1, 4).coefficients == (F(1447, 4624), F(-365, 4624))
    assert coefficient(3, 4).coefficients == (F(1447, 4624), F(365, 4624))


@pytest.mark.parametrize("q", range(2, 9))
def test_reciprocal_coefficient_is_galois_equivariant(q):
    base = reciprocal_series_coefficient(parabolic_factor(zeta(q), q), q)
    for p in [p for p in range(1, q) if gcd(p, q) == 1]:
        direct = reciprocal_series_coefficient(parabolic_factor(zeta_power(q, p), q), q)
        assert exact_equal(direct, automorphism(base, p))


def test_complex_conjugation_is_the_automorphism_minus_one():
    q = 7
    a = element(q, random.Random(3))
    assert exact_equal(automorphism(automorphism(a, -1), -1), a)
    assert exact_equal(neg(neg(a)), a)


# --- pinned vectors ---------------------------------------------------------


def test_pinned_vectors_are_current():
    path = Path(__file__).resolve().parents[2] / "fixtures" / "cyclotomic_germ_v1.json"
    assert path.read_text() == make_cyclotomic_vectors.render()
    payload = json.loads(path.read_text())
    assert payload["schema"] == "cyclotomic-germ/v1"
    assert payload["authority"] == "none"
    assert {(r["p"], r["q"]) for r in payload["vectors"]} >= {(1, 1), (1, 2), (1, 4), (3, 4), (3, 8)}
