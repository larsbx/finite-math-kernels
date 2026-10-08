"""Regular continued fractions and their convergents, exactly.

The simple (regular) continued fraction ``[a0; a1, ..., an]`` of a rational is
read off the Euclidean algorithm, and its convergents ``p_k / q_k`` satisfy
the recurrences ``p_k = a_k p_{k-1} + p_{k-2}``, ``q_k = a_k q_{k-1} + q_{k-2}``.
Standard references: A. Ya. Khinchin, *Continued Fractions* (1935; English
translation, University of Chicago Press, 1964), sections 1-2; G. H. Hardy and
E. M. Wright, *An Introduction to the Theory of Numbers* (1938; 6th ed.,
Oxford, 2008), chapter X.

``continued_fraction`` and ``convergents`` are part of the R1 reference for
the Mojo ``rational_dynamics`` package (whose ``continued_fractions.mojo`` is
the canonical twin); ``from_continued_fraction`` is ported from
larsbx/mandelbrot-bulbs-and-ford-circles-research (kernel/bulbford/cf.py,
``from_cf``). Previously in ``farey``, which still re-exports all three.

What is claimed: each function computes the stated finite object exactly.
What is not: any approximation-theoretic statement a consumer builds on them.
"""

from __future__ import annotations

from collections.abc import Sequence
from fractions import Fraction

from .addresses import Address


def continued_fraction(value: Address) -> tuple[int, ...]:
    """The canonical expansion ``(a0, a1, ..., an)``: last term at least two
    unless the value is an integer."""
    n, d = value.numerator, value.denominator
    out = []
    while d:
        a, r = divmod(n, d)
        out.append(a)
        n, d = d, r
    return tuple(out)


def convergents(value: Address) -> tuple[Fraction, ...]:
    """The convergents of ``continued_fraction(value)``, in order."""
    p2, p1 = 0, 1
    q2, q1 = 1, 0
    out = []
    for a in continued_fraction(value):
        p = a * p1 + p2
        q = a * q1 + q2
        out.append(Fraction(p, q))
        p2, p1 = p1, p
        q2, q1 = q1, q
    return tuple(out)


def from_continued_fraction(terms: Sequence[int]) -> Fraction:
    """``[a0; a1, ..., an]`` as a fraction.

    ``a0`` is any integer and every later term must be positive; the expansion
    need not be canonical (``[0; 1, 1] == 1/2``). An empty sequence or a
    non-positive later term is refused, since either leaves the value
    undefined or not a continued fraction. The result is in lowest terms, so
    ``(result.numerator, result.denominator)`` is the ``(p, q)`` pair the
    bulbs ``from_cf`` returns.
    """
    if not terms:
        raise ValueError("a continued fraction needs at least one term")
    if any(not isinstance(a, int) or isinstance(a, bool) for a in terms):
        raise TypeError("continued-fraction terms must be integers")
    if any(a < 1 for a in terms[1:]):
        raise ValueError("every term after the first must be positive")
    p1, p2 = 1, 0
    q1, q2 = 0, 1
    for a in terms:
        p1, p2 = a * p1 + p2, p1
        q1, q2 = a * q1 + q2, q1
    return Fraction(p1, q1)
