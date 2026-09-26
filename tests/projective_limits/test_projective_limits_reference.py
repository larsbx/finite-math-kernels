"""Laws of the projective_limits Python reference and drift of its golden vectors."""

from __future__ import annotations

import random
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from projective_limits_reference import (  # noqa: E402
    INFINITY, add, affine, asymptote, chordal_distance_squared, curve_limit, directional_limit, divmod_poly,
    evaluate, gcd_poly, mobius_apply, mul, p1, path_dependence_witness, poly, power, rational_limit, sub, tangent_slope,
)


def random_poly(rng: random.Random, max_degree: int = 3) -> tuple[Fraction, ...]:
    return poly(*(rng.randint(-4, 4) for _ in range(rng.randint(1, max_degree + 1))))


def test_normal_form_has_one_unsigned_infinity():
    assert p1(Fraction(2), Fraction(4)) == affine(Fraction(1, 2))
    assert p1(Fraction(-3), Fraction(0)) == INFINITY == p1(Fraction(1), Fraction(0))
    assert p1(Fraction(0), Fraction(0)) is None


def test_euclidean_division_identity():
    rng = random.Random(1)
    for _ in range(300):
        p, q = random_poly(rng, 5), random_poly(rng)
        if not q:
            continue
        s, r = divmod_poly(p, q)
        assert add(mul(s, q), r) == p
        assert len(r) < len(q)


def test_gcd_divides_both():
    rng = random.Random(2)
    for _ in range(200):
        common = random_poly(rng, 2)
        p, q = mul(random_poly(rng), common), mul(random_poly(rng), common)
        if not common or not p or not q:
            continue
        g = gcd_poly(p, q)
        assert not divmod_poly(p, g)[1] and not divmod_poly(q, g)[1]
        assert not divmod_poly(g, common)[1]


def test_regular_points_are_evaluation():
    rng = random.Random(3)
    for _ in range(300):
        p, q = random_poly(rng), random_poly(rng)
        a = Fraction(rng.randint(-5, 5), rng.randint(1, 4))
        pa, qa = evaluate(p, a), evaluate(q, a)
        if pa or qa:
            assert rational_limit(p, q, affine(a)) == p1(pa, qa)


def test_cancellation_law():
    rng = random.Random(4)
    for _ in range(300):
        p, q = random_poly(rng), random_poly(rng)
        root = Fraction(rng.randint(-5, 5), rng.randint(1, 3))
        r = power(poly(-root, 1), rng.randint(1, 2))
        if not p and not q:
            continue
        for at in (affine(root), INFINITY):
            assert rational_limit(mul(p, r), mul(q, r), at) == rational_limit(p, q, at)


@pytest.mark.parametrize(
    ("p", "q", "expected"),
    [
        (poly(1, 1), poly(0, 0, 1), affine(0)),
        (poly(7, 0, 3), poly(1, 5, 2), affine(Fraction(3, 2))),
        (poly(0, 0, 0, 1), poly(1, 1), INFINITY),
    ],
)
def test_degree_rule(p, q, expected):
    assert rational_limit(p, q, INFINITY) == expected


def test_infinity_is_the_chart_s_equals_one_over_x():
    rng = random.Random(5)
    for _ in range(200):
        p, q = random_poly(rng), random_poly(rng)
        if not p or not q:
            continue
        d = max(len(p), len(q)) - 1
        flipped = lambda f: poly(*reversed(f + (Fraction(0),) * (d + 1 - len(f))))  # noqa: E731
        assert rational_limit(p, q, INFINITY) == rational_limit(flipped(p), flipped(q), affine(0))


def test_tangent_slopes():
    assert tangent_slope(poly(0, 1), poly(0, 0, 0, 1), Fraction(2)) == affine(12)
    assert tangent_slope(poly(0, 0, 0, 1), poly(0, 1), Fraction(0)) == INFINITY
    assert tangent_slope(poly(0, 0, 1), poly(0, 0, 0, 1), Fraction(0)) == affine(0)
    # A graph t -> (t, f(t)) has slope f'(t0).
    rng = random.Random(6)
    for _ in range(100):
        f = random_poly(rng, 4)
        t0 = Fraction(rng.randint(-3, 3))
        derivative = poly(*(k * c for k, c in enumerate(f)))[1:]
        assert tangent_slope(poly(0, 1), f, t0) == affine(evaluate(derivative, t0))


def test_asymptote_is_the_limit_of_the_residual():
    assert asymptote(poly(1, 0, 1), poly(-1, 1)) == (affine(1), affine(1))
    assert asymptote(poly(2, 3), poly(5, 1)) == (affine(0), affine(3))
    assert asymptote(poly(0, 0, 0, 1), poly(1, 1)) == (INFINITY, None)
    rng = random.Random(7)
    for _ in range(200):
        q = poly(*(rng.randint(-3, 3) for _ in range(2)), rng.choice([-1, 1, 2]))
        p = random_poly(rng, 3)
        slope, intercept = asymptote(p, q)
        if slope == INFINITY:
            continue
        m, c = slope[0], intercept[0]
        assert rational_limit(sub(p, mul(q, poly(c, m))), q, INFINITY) == affine(0)


XY = ((1, 1, Fraction(1)),)
X2_PLUS_Y2 = ((2, 0, Fraction(1)), (0, 2, Fraction(1)))
X2Y = ((2, 1, Fraction(1)),)
X4_PLUS_Y2 = ((4, 0, Fraction(1)), (0, 2, Fraction(1)))


def test_directional_limits_are_the_divisor_restriction():
    for a in range(-4, 5):
        for b in (1, 2, 3):
            expected = affine(Fraction(a * b, a * a + b * b))
            assert directional_limit(XY, X2_PLUS_Y2, p1(Fraction(a), Fraction(b))) == expected
    assert directional_limit(XY, X2_PLUS_Y2, INFINITY) == affine(0)


def test_witness_certifies_and_absence_is_inconclusive():
    first, first_limit, second, second_limit = path_dependence_witness(XY, X2_PLUS_Y2, 4)
    assert first_limit != second_limit
    assert directional_limit(XY, X2_PLUS_Y2, first) == first_limit
    assert directional_limit(XY, X2_PLUS_Y2, second) == second_limit
    # x^2 y/(x^4 + y^2): no line separates, the parabola does.
    assert path_dependence_witness(X2Y, X4_PLUS_Y2, 6) is None
    assert curve_limit(X2Y, X4_PLUS_Y2, poly(0, 1), poly(0, 0, 1)) == affine(Fraction(1, 2))
    assert curve_limit(X2Y, X4_PLUS_Y2, poly(1, 1), poly(0, 1)) is None


def test_mobius_is_a_group_action_and_chordal_rotations_are_isometries():
    rng = random.Random(8)
    flip = (Fraction(0), Fraction(-1), Fraction(1), Fraction(0))
    for _ in range(200):
        m = tuple(Fraction(rng.randint(-4, 4)) for _ in range(4))
        n = tuple(Fraction(rng.randint(-4, 4)) for _ in range(4))
        z = rng.choice([INFINITY, affine(Fraction(rng.randint(-5, 5), rng.randint(1, 3)))])
        w = affine(Fraction(rng.randint(-5, 5), rng.randint(1, 3)))
        mn = (m[0] * n[0] + m[1] * n[2], m[0] * n[1] + m[1] * n[3], m[2] * n[0] + m[3] * n[2], m[2] * n[1] + m[3] * n[3])
        if mobius_apply(m, z) is not None and mobius_apply(n, z) is not None:
            assert mobius_apply(mn, z) == mobius_apply(m, mobius_apply(n, z))
        d = chordal_distance_squared(z, w)
        assert 0 <= d <= 4
        assert d == chordal_distance_squared(w, z)
        assert d == chordal_distance_squared(mobius_apply(flip, z), mobius_apply(flip, w))


def test_vectors_have_not_drifted():
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "make_projective_limits_vectors.py"), "--check"],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
