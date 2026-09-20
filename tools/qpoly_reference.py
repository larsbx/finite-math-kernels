#!/usr/bin/env python3
"""Reference model of exact polynomials over Q, the Sturm chain, and isolation.

Specification: docs/exact-polynomial-root-isolation-spec.md. This module is the
executable form of that document, written before the Mojo kernels in
``finite_linear_algebra/qpoly.mojo`` and the general-size ``charpoly`` of
``finite_linear_algebra/qlinalg.mojo``, and kept as their independent oracle:
``tests/finite_linear_algebra/test_qpoly_reference.py`` asserts the constants
that ``tests/finite_linear_algebra/test_qpoly.mojo`` asserts, so the two agree
on every pinned value. Pure functions over tuples; no repository policy, no
theorem.

A polynomial is a tuple of ``Fraction`` coefficients in ascending degree,
normalized so that the last one is nonzero; the empty tuple is zero.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Iterable

Poly = tuple[Fraction, ...]

ZERO: Poly = ()


# --- section 1: objects, evaluation, and the ring operations -------------------


def normalize(p: Iterable[Fraction]) -> Poly:
    out = [Fraction(c) for c in p]
    while out and out[-1] == 0:
        out.pop()
    return tuple(out)


def of(*coefficients: int | Fraction) -> Poly:
    """A polynomial from ascending coefficients, for readable test data."""
    return normalize(Fraction(c) for c in coefficients)


def degree(p: Poly) -> int:
    return len(normalize(p)) - 1


def evaluate(p: Poly, x: int | Fraction) -> Fraction:
    x, total = Fraction(x), Fraction(0)
    for coefficient in reversed(normalize(p)):
        total = total * x + coefficient
    return total


def derivative(p: Poly) -> Poly:
    p = normalize(p)
    return normalize(k * p[k] for k in range(1, len(p)))


def neg(p: Poly) -> Poly:
    return normalize(-c for c in p)


def scale(p: Poly, factor: int | Fraction) -> Poly:
    return normalize(Fraction(factor) * c for c in p)


def add(a: Poly, b: Poly) -> Poly:
    width = max(len(a), len(b))
    return normalize(
        (a[k] if k < len(a) else Fraction(0)) + (b[k] if k < len(b) else Fraction(0))
        for k in range(width)
    )


def sub(a: Poly, b: Poly) -> Poly:
    return add(a, neg(b))


def mul(a: Poly, b: Poly) -> Poly:
    a, b = normalize(a), normalize(b)
    if not a or not b:
        return ZERO
    out = [Fraction(0)] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] += x * y
    return normalize(out)


# --- section 2: division, gcd, and the squarefree part -------------------------


def divide(a: Poly, b: Poly) -> tuple[Poly, Poly]:
    """`(quotient, remainder)` with `a = q b + r` and `degree(r) < degree(b)`."""
    a, b = normalize(a), normalize(b)
    if not b:
        raise ZeroDivisionError("division by the zero polynomial")
    quotient = [Fraction(0)] * max(len(a) - len(b) + 1, 0)
    remainder = list(a)
    while len(remainder) >= len(b):
        shift = len(remainder) - len(b)
        factor = remainder[-1] / b[-1]
        quotient[shift] = factor
        for k, coefficient in enumerate(b):
            remainder[shift + k] -= factor * coefficient
        remainder = list(normalize(remainder))
    return normalize(quotient), normalize(remainder)


def remainder(a: Poly, b: Poly) -> Poly:
    return divide(a, b)[1]


def monic(p: Poly) -> Poly:
    p = normalize(p)
    return p if not p else scale(p, 1 / p[-1])


def gcd(a: Poly, b: Poly) -> Poly:
    a, b = normalize(a), normalize(b)
    while b:
        a, b = b, remainder(a, b)
    return monic(a)


def squarefree_part(p: Poly) -> Poly:
    """`p / gcd(p, p')`: the same roots, each of them simple."""
    p = normalize(p)
    if degree(p) < 1:
        return p
    quotient, rest = divide(p, gcd(p, derivative(p)))
    if rest:
        raise ArithmeticError("the gcd did not divide; an impossible state")
    return quotient


# --- section 3: the Cauchy root bound ------------------------------------------


def root_bound(p: Poly) -> Fraction:
    """A rational above every real root in magnitude. Section 3, proved there."""
    p = normalize(p)
    if degree(p) < 1:
        raise ValueError("a root bound needs degree at least one")
    return 1 + max(abs(c) for c in p[:-1]) / abs(p[-1])


# --- sections 4 and 5: the chain, its variations, and what they count -----------


def sturm_chain(p: Poly) -> tuple[Poly, ...]:
    """The chain of the squarefree part: `s, s'`, then negated remainders."""
    current = squarefree_part(p)
    if degree(current) < 1:
        return (current,) if current else ()
    chain = [current, derivative(current)]
    while chain[-1]:
        chain.append(neg(remainder(chain[-2], chain[-1])))
    return tuple(chain[:-1])


def sign_variations(chain: tuple[Poly, ...], x: int | Fraction) -> int:
    """Sign changes among the nonzero values of the chain at `x`."""
    signs = [value for value in (evaluate(p, x) for p in chain) if value != 0]
    return sum(1 for a, b in zip(signs, signs[1:]) if a * b < 0)


def variation_difference(chain: tuple[Poly, ...], a: int | Fraction, b: int | Fraction) -> int:
    """`V(a) - V(b)`. A finite fact; Sturm's theorem is what counts with it."""
    return sign_variations(chain, a) - sign_variations(chain, b)


# --- section 6: the largest root, as a bracket ---------------------------------


DEFAULT_WIDTH = Fraction(1, 1 << 20)
DEFAULT_MAX_STEPS = 256


@dataclass(frozen=True, slots=True)
class RootBracket:
    """Two rationals, or a refusal. Never a root."""

    found: bool
    exact: bool = False
    lo: Fraction = Fraction(0)
    hi: Fraction = Fraction(0)

    def width(self) -> Fraction:
        return self.hi - self.lo


REFUSED = RootBracket(found=False)


def largest_root_bracket(
    p: Poly,
    width: int | Fraction = DEFAULT_WIDTH,
    max_steps: int = DEFAULT_MAX_STEPS,
) -> RootBracket:
    """An isolating bracket of the largest real root, or a refusal.

    The invariant is that `s` vanishes at neither endpoint and the largest real
    root lies strictly between them, so the returned bracket carries a sign
    change of the squarefree part whatever a reader thinks of Sturm.
    """
    p = normalize(p)
    if degree(p) < 1:
        return REFUSED
    s = squarefree_part(p)
    chain = sturm_chain(p)
    bound = root_bound(p)
    lo, hi = -bound, bound
    if variation_difference(chain, lo, hi) == 0:
        return REFUSED
    width = Fraction(width)
    for _ in range(max_steps):
        middle = (lo + hi) / 2
        if evaluate(s, middle) == 0:
            if variation_difference(chain, middle, hi) == 0:
                return RootBracket(found=True, exact=True, lo=middle, hi=middle)
            lo = middle
        elif variation_difference(chain, middle, hi) >= 1:
            lo = middle
        else:
            hi = middle
        if hi - lo <= width and variation_difference(chain, lo, hi) == 1:
            return RootBracket(found=True, lo=lo, hi=hi)
    return REFUSED


# --- section 7: the characteristic polynomial ----------------------------------


def charpoly(matrix: tuple[tuple[Fraction, ...], ...]) -> Poly:
    """`det(x I - matrix)`, ascending, by Faddeev-LeVerrier. Monic, any size."""
    size = len(matrix)
    if size == 0:
        return of(1)
    current = [[Fraction(0)] * size for _ in range(size)]
    coefficients = [Fraction(1)]
    for step in range(1, size + 1):
        tail = coefficients[-1]
        current = [
            [
                sum(Fraction(matrix[i][k]) * current[k][j] for k in range(size))
                + tail * Fraction(matrix[i][j])
                for j in range(size)
            ]
            for i in range(size)
        ]
        coefficients.append(-sum(current[i][i] for i in range(size)) / step)
    return tuple(reversed(coefficients))
