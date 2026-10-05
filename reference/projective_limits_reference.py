"""Independent Python reference for projective_limits.

The Mojo package reads every limit off one kernel, the lowest-order point on
the exceptional divisor of a blow-up. This reference deliberately uses the
classical methods instead, so agreement is evidence rather than a copy:

  rational_limit   cancel gcd(p, q) by Euclid over Q, then evaluate the
                   coprime pair: [p(a) : q(a)] at a finite point, leading
                   coefficients by degree at infinity
  tangent_slope    rational_limit of the secant quotient
  asymptote        polynomial division p = s q + r (r/q -> 0 at infinity)
  curve_limit      substitute the arc, then rational_limit at t = 0

Points of P^1(Q) are normal forms (t, 1) or (1, 0); None is a rejection.
Polynomials are tuples of Fractions, lowest degree first. A bivariate
polynomial is a tuple of (i, j, c) monomials c x^i y^j.
"""

from __future__ import annotations

from fractions import Fraction
from functools import reduce
from itertools import zip_longest

Poly = tuple[Fraction, ...]
Poly2 = tuple[tuple[int, int, Fraction], ...]
P1 = tuple[Fraction, Fraction]

INFINITY: P1 = (Fraction(1), Fraction(0))


def p1(x: Fraction, y: Fraction) -> P1 | None:
    if y:
        return (Fraction(x) / y, Fraction(1))
    return INFINITY if x else None


def affine(t: Fraction | int) -> P1:
    return (Fraction(t), Fraction(1))


# Polynomials over Q.


def trim(p: Poly) -> Poly:
    end = len(p)
    while end and not p[end - 1]:
        end -= 1
    return tuple(p[:end])


def poly(*coeffs: Fraction | int) -> Poly:
    return trim(tuple(Fraction(c) for c in coeffs))


def degree(p: Poly) -> int:
    return len(trim(p)) - 1


def add(p: Poly, q: Poly) -> Poly:
    return trim(tuple(a + b for a, b in zip_longest(p, q, fillvalue=Fraction(0))))


def scale(p: Poly, c: Fraction) -> Poly:
    return trim(tuple(a * c for a in p))


def sub(p: Poly, q: Poly) -> Poly:
    return add(p, scale(q, Fraction(-1)))


def mul(p: Poly, q: Poly) -> Poly:
    if not p or not q:
        return ()
    out = [Fraction(0)] * (len(p) + len(q) - 1)
    for i, a in enumerate(p):
        for j, b in enumerate(q):
            out[i + j] += a * b
    return trim(tuple(out))


def power(p: Poly, n: int) -> Poly:
    return reduce(mul, (p,) * n, poly(1))


def evaluate(p: Poly, t: Fraction) -> Fraction:
    return reduce(lambda acc, c: acc * t + c, reversed(p), Fraction(0))


def divmod_poly(p: Poly, q: Poly) -> tuple[Poly, Poly]:
    """Euclidean division p = s q + r with deg r < deg q; q must be nonzero."""
    q = trim(q)
    if not q:
        raise ZeroDivisionError("polynomial division by zero")
    quotient = [Fraction(0)] * max(len(p) - len(q) + 1, 0)
    rem = trim(p)
    while len(rem) >= len(q):
        shift = len(rem) - len(q)
        c = rem[-1] / q[-1]
        quotient[shift] = c
        rem = sub(rem, (Fraction(0),) * shift + scale(q, c))
    return trim(tuple(quotient)), rem


def gcd_poly(p: Poly, q: Poly) -> Poly:
    p, q = trim(p), trim(q)
    while q:
        p, q = q, divmod_poly(p, q)[1]
    return p


def rational_limit(num: Poly, den: Poly, point: P1 | None) -> P1 | None:
    """lim num/den at a point of P^1, by cancellation then evaluation."""
    num, den = trim(num), trim(den)
    if point is None or (not num and not den):
        return None
    if not num:
        return affine(0)
    if not den:
        return INFINITY
    g = gcd_poly(num, den)
    p, q = divmod_poly(num, g)[0], divmod_poly(den, g)[0]
    if point == INFINITY:
        d = max(degree(p), degree(q))
        return p1(p[d] if degree(p) == d else Fraction(0), q[d] if degree(q) == d else Fraction(0))
    return p1(evaluate(p, point[0]), evaluate(q, point[0]))


def tangent_slope(x: Poly, y: Poly, t0: Fraction) -> P1 | None:
    dy = sub(y, poly(evaluate(y, t0)))
    dx = sub(x, poly(evaluate(x, t0)))
    return rational_limit(dy, dx, affine(t0))


def asymptote(num: Poly, den: Poly) -> tuple[P1 | None, P1 | None]:
    """(slope, intercept) of y = m x + c at infinity, from p = s q + r."""
    s, _ = divmod_poly(num, den)
    if degree(s) >= 2:
        return INFINITY, None
    s = s + (Fraction(0),) * (2 - len(s))
    return affine(s[1]), affine(s[0])


# Bivariate quotients at the origin.


def along(p: Poly2, x: Poly, y: Poly) -> Poly:
    return reduce(add, (scale(mul(power(x, i), power(y, j)), c) for i, j, c in p), ())


def curve_limit(num: Poly2, den: Poly2, x: Poly, y: Poly) -> P1 | None:
    if evaluate(x, Fraction(0)) or evaluate(y, Fraction(0)):
        return None
    return rational_limit(along(num, x, y), along(den, x, y), affine(0))


def directional_limit(num: Poly2, den: Poly2, direction: P1 | None) -> P1 | None:
    if direction is None:
        return None
    a, b = direction
    return curve_limit(num, den, poly(0, a), poly(0, b))


def witness_directions(search: int) -> list[P1]:
    """The scan order of the contract: [1:0], then [t:1] for t = -search..search."""
    return [INFINITY, *(affine(t) for t in range(-search, search + 1))]


def path_dependence_witness(num: Poly2, den: Poly2, search: int) -> tuple[P1, P1, P1, P1] | None:
    """(first, first_limit, second, second_limit), or None when not found."""
    first = None
    for direction in witness_directions(search):
        value = directional_limit(num, den, direction)
        if value is None:
            continue
        if first is None:
            first = (direction, value)
        elif value != first[1]:
            return (*first, direction, value)
    return None


# Moebius maps and the chordal metric.


def mobius_apply(m: tuple[Fraction, Fraction, Fraction, Fraction], point: P1 | None) -> P1 | None:
    a, b, c, d = m
    if point is None or a * d == b * c:
        return None
    x, y = point
    return p1(a * x + b * y, c * x + d * y)


def chordal_distance_squared(p: P1 | None, q: P1 | None) -> Fraction | None:
    if p is None or q is None:
        return None
    (x0, x1), (y0, y1) = p, q
    return 4 * (x0 * y1 - x1 * y0) ** 2 / ((x0**2 + x1**2) * (y0**2 + y1**2))
