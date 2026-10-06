"""Pinned values of kernel/finite_polynomial/polynomial_fp.mojo, replayed by the independent reference.

The factor-degree rows are read out of tests/finite_polynomial/test_polynomial_fp.mojo, so
every row the Mojo test pins is recomputed here twice: by distinct-degree
factorization with exact Python exponents, and by trial division by every monic
irreducible polynomial. The scalar pins are the Mojo test's literals.
"""

from __future__ import annotations

import random
import re
from pathlib import Path

import polynomial_fp_reference as r

MOJO_TEST = Path(__file__).with_name("test_polynomial_fp.mojo")
ROW = re.compile(r"check_degrees\((\d+), \[([-\d, ]*)\], \[([\d, ]*)\], (True|False)\)")


def ints(text: str) -> tuple[int, ...]:
    return tuple(int(x) for x in text.split(",") if x.strip())


def rows():
    found = [(int(p), ints(f), list(ints(d)), b == "True") for p, f, d, b in ROW.findall(MOJO_TEST.read_text())]
    assert len(found) == 9
    return found


def test_every_pinned_factor_pattern():
    for p, f, degrees, irreducible in rows():
        g = r.poly(p, f)
        assert r.squarefree(p, g)
        assert r.factor_degrees(p, g) == degrees, (p, f)
        assert r.brute_factor_degrees(p, g) == degrees, (p, f)
        assert r.rabin_irreducible(p, g) == irreducible == (len(degrees) == 1)


def test_ring_pins():
    a, b = r.poly(7, (1, 2, 3, 4, 5)), r.poly(7, (3, 0, 2))
    assert r.divmod_(7, a, b) == ((3, 2, 6), (6, 3))
    assert r.gcd(7, r.mul(7, (1, 1), (2, 0, 1)), r.mul(7, (1, 1), (3, 1))) == (1, 1)
    assert r.powmod(7, (2, 1), 100, (1, 0, 0, 1)) == (1, 3, 3)
    assert r.derivative(7, (5, 1, 1, 1, 1, 1, 1, 1)) == (1, 2, 3, 4, 5, 6)
    assert r.evaluate(7, (1, 0, 1), -3) == 3
    assert r.frobenius_power(3, (1, 2, 0, 1, 0, 0, 1), 2) == (1, 2, 0, 0, 1)
    assert r.poly(7, (0, 7, 14)) == ()


def test_scalar_pins():
    assert pow(3, -1, 7) == 5 and pow(7, -1, 9) == 4
    assert 10**20 % 1000003 == 997303 and -(10**20) % 1000003 == 2700
    assert r.is_prime(2147483647) and not r.is_prime(2147483649)
    assert r.prime_divisors(360) == [2, 3, 5]


def strong_probable_prime(n: int, base: int) -> bool:
    d, s = n - 1, 0
    while d % 2 == 0:
        d, s = d // 2, s + 1
    x = pow(base, d, n)
    return x in (1, n - 1) or any(pow(x, 2**r, n) == n - 1 for r in range(1, s))


def test_miller_rabin_witness_set():
    """The Mojo test's composites fool smaller witness sets; the least composite
    fooling {2, 3, 5, 7} (Pomerance-Selfridge-Wagstaff 1980) lies past 2^31."""
    assert strong_probable_prime(2047, 2) and not strong_probable_prime(2047, 3)
    assert all(strong_probable_prime(25326001, b) for b in (2, 3, 5)) and not strong_probable_prime(25326001, 7)
    n = 3215031751
    assert n == 151 * 751 * 28351 and n > 2**31 and all(strong_probable_prime(n, b) for b in (2, 3, 5, 7))
    for m in range(9, 200000, 2):
        assert r.is_prime(m) == all(strong_probable_prime(m, b) for b in (2, 3, 5, 7) if b != m)


def test_mixed_pattern_and_roots():
    f = r.mul(5, r.mul(5, (0, 1), (1, 1)), r.mul(5, (2, 0, 1), (1, 1, 0, 1)))
    assert f == (0, 2, 4, 3, 4, 3, 1, 1)
    assert sum(r.evaluate(5, f, x) == 0 for x in range(5)) == 2
    assert not r.squarefree(3, (1, 2, 1)) and not r.squarefree(3, (1, 0, 0, 1))


def test_hensel_pin():
    # A_{2,1}(C) = C^4 + 2 C^3; the simple root -2 = 3 mod 5 lifts to 23 mod 25.
    assert r.hensel_lift(5, (0, 0, 0, 2, 1), -2) == (4, 23)


def test_distinct_degree_agrees_with_trial_division_at_random():
    rng = random.Random(20261006)
    for _ in range(200):
        p = rng.choice((2, 3, 5, 7))
        f = r.poly(p, [rng.randrange(p) for _ in range(rng.randrange(2, 8))] + [1])
        if r.squarefree(p, f):
            assert r.factor_degrees(p, f) == r.brute_factor_degrees(p, f), (p, f)
            assert r.rabin_irreducible(p, f) == (r.brute_factor_degrees(p, f) == [len(f) - 1])
