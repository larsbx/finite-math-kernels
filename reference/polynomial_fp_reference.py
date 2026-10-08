#!/usr/bin/env python3
"""Reference model of polynomials over F_p, independent of the Mojo kernel.

Non-authoritative oracle for ``kernel/finite_polynomial/polynomial_fp.mojo``.
Python's integers are unbounded, so nothing here needs the kernel's 2^31
modulus bound; the algorithms are chosen to differ from the kernel's where a
different route exists:

- factor degrees come from trial division by every monic polynomial of
  degree at most half (``brute_factor_degrees``) as well as from
  distinct-degree factorization, whose x^(p^i) is one power with an exact
  Python exponent rather than the kernel's Frobenius matrix;
- irreducibility is also decided by that trial division;
- the Hensel lift is found by searching the p lifts of the root.

Pure functions over tuples of ints, ascending degree, normalized so that the
last coefficient is nonzero; the empty tuple is zero. Standard library only.
"""

from __future__ import annotations

from itertools import product
from math import isqrt

Poly = tuple[int, ...]


def is_prime(n: int) -> bool:
    return n >= 2 and all(n % d for d in range(2, isqrt(n) + 1))


def poly(p: int, coeffs) -> Poly:
    out = [c % p for c in coeffs]
    while out and out[-1] == 0:
        out.pop()
    return tuple(out)


def add(p: int, a: Poly, b: Poly) -> Poly:
    n = max(len(a), len(b))
    return poly(p, [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)])


def sub(p: int, a: Poly, b: Poly) -> Poly:
    return add(p, a, tuple(-c for c in b))


def mul(p: int, a: Poly, b: Poly) -> Poly:
    if not a or not b:
        return ()
    out = [0] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] += x * y
    return poly(p, out)


def divmod_(p: int, a: Poly, b: Poly) -> tuple[Poly, Poly]:
    if not b:
        raise ZeroDivisionError("polynomial division by zero")
    inv = pow(b[-1], -1, p)
    r, q = list(a), [0] * max(len(a) - len(b) + 1, 0)
    for i in range(len(a) - len(b), -1, -1):
        c = r[i + len(b) - 1] * inv % p
        q[i] = c
        for j, y in enumerate(b):
            r[i + j] -= c * y
    return poly(p, q), poly(p, r[: len(b) - 1])


def rem(p: int, a: Poly, b: Poly) -> Poly:
    return divmod_(p, a, b)[1]


def monic(p: int, a: Poly) -> Poly:
    inv = pow(a[-1], -1, p)
    return poly(p, [c * inv for c in a])


def gcd(p: int, a: Poly, b: Poly) -> Poly:
    while b:
        a, b = b, rem(p, a, b)
    return monic(p, a) if a else ()


def derivative(p: int, a: Poly) -> Poly:
    return poly(p, [i * a[i] for i in range(1, len(a))])


def evaluate(m: int, a: Poly, x: int) -> int:
    return sum(c * pow(x, i, m) for i, c in enumerate(a)) % m


def powmod(p: int, base: Poly, e: int, f: Poly) -> Poly:
    result, base = rem(p, (1,), f), rem(p, base, f)
    while e:
        if e & 1:
            result = rem(p, mul(p, result, base), f)
        base = rem(p, mul(p, base, base), f)
        e >>= 1
    return result


def frobenius_power(p: int, f: Poly, k: int) -> Poly:
    """x^(p^k) mod f, as one power: the exponent is an exact Python int."""
    return powmod(p, (0, 1), p**k, f)


def squarefree(p: int, f: Poly) -> bool:
    return bool(f) and len(gcd(p, f, derivative(p, f))) == 1


def factor_degrees(p: int, f: Poly) -> list[int]:
    """Distinct-degree factorization of square-free nonconstant f."""
    assert len(f) > 1 and squarefree(p, f)
    degrees, g, i = [], monic(p, f), 0
    while len(g) - 1 >= 2 * (i + 1):
        i += 1
        common = gcd(p, g, sub(p, frobenius_power(p, f, i), (0, 1)))
        if len(common) > 1:
            degrees += [i] * ((len(common) - 1) // i)
            g = divmod_(p, g, common)[0]
    if len(g) > 1:
        degrees.append(len(g) - 1)
    return sorted(degrees)


def monic_polys(p: int, d: int):
    for tail in product(range(p), repeat=d):
        yield tuple(tail) + (1,)


def brute_factor_degrees(p: int, f: Poly) -> list[int]:
    """Factor degrees with multiplicity by trial division, smallest degree first."""
    g, degrees = monic(p, f), []
    d = 1
    while len(g) - 1 >= 2 * d:
        for h in monic_polys(p, d):
            while True:
                q, r = divmod_(p, g, h)
                if r:
                    break
                g = q
                degrees.append(d)
        d += 1
    if len(g) > 1:
        degrees.append(len(g) - 1)
    return sorted(degrees)


def prime_divisors(n: int) -> list[int]:
    return [q for q in range(2, n + 1) if n % q == 0 and is_prime(q)]


def rabin_irreducible(p: int, f: Poly) -> bool:
    n, x = len(f) - 1, rem(p, (0, 1), f)
    return frobenius_power(p, f, n) == x and all(
        len(gcd(p, f, sub(p, frobenius_power(p, f, n // q), (0, 1)))) == 1 for q in prime_divisors(n)
    )


def hensel_lift(p: int, f: tuple[int, ...], root: int) -> tuple[int, int]:
    """(digit, lifted): the unique t in [0, p) with f(root + p t) = 0 mod p^2."""
    base = root % p
    lifts = [t for t in range(p) if evaluate(p * p, f, base + p * t) == 0]
    assert len(lifts) == 1
    return lifts[0], base + p * lifts[0]
