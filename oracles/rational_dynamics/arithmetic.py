"""Arithmetic functions the doubling-map number theory reads: Moebius, Dedekind
sums and Ramanujan sums, exactly.

Ported from larsbx/finite-mandelbrot-research
reference/python/c1/misiurewicz_catalogue_reference.py (``moebius``) and
larsbx/mandelbrot-bulbs-and-ford-circles-research experiments/scripts/bridges_spike.py
(``dedekind``, the reciprocity algorithm) and experiments/scripts/spectral.py
(``ramanujan``, which summed cosines in floating point; here it is the exact
divisor sum). The truncated Brjuno sum of spectral.py stays in that
repository: it is a sum of logarithms, not an exact quantity.

What is claimed: each value is the exact integer or rational of its
definition. What is not: any spectral or asymptotic statement a consumer
builds on them.
"""

from __future__ import annotations

from fractions import Fraction
from math import gcd


def moebius(n: int) -> int:
    """``mu(n)`` for ``n >= 1``: ``0`` if a square divides ``n``, else ``(-1)^(number of primes)``.

    ``n < 1`` is refused; the Mandelbrot reference returned ``0`` there.
    """
    if n < 1:
        raise ValueError("the Moebius function is defined on positive integers")
    rest, sign, factor = n, 1, 2
    while factor * factor <= rest:
        if rest % factor == 0:
            rest //= factor
            if rest % factor == 0:
                return 0
            sign = -sign
        factor += 1
    return -sign if rest > 1 else sign


def dedekind_sum(h: int, k: int) -> Fraction:
    """``s(h, k) = sum_{r=1}^{k-1} ((r/k)) ((h r/k))`` for ``k >= 1``, exactly.

    ``((x))`` is the sawtooth ``x - floor(x) - 1/2`` off the integers and ``0``
    on them. Computed by reciprocity,
    ``s(h, k) + s(k, h) = (h^2 + k^2 + 1) / (12 h k) - 1/4`` for coprime
    ``h, k > 0``, after reducing ``h`` modulo ``k`` and dividing out
    ``gcd(h, k)`` (``s(dh, dk) = s(h, k)``), so it costs a Euclidean
    algorithm, not ``k`` terms. ``k < 1`` is refused.
    """
    if k < 1:
        raise ValueError("the modulus of a Dedekind sum must be positive")
    common = gcd(h, k)
    h, k = (h // common) % (k // common), k // common
    s, sign = Fraction(0), 1
    while k > 1 and h:
        s += sign * (Fraction(h * h + k * k + 1, 12 * h * k) - Fraction(1, 4))
        h, k, sign = k % h, h, -sign
    return s


def ramanujan_sum(q: int, m: int) -> int:
    """``c_q(m) = sum over units a mod q of exp(2 pi i a m / q)``, exactly.

    Evaluated as the divisor sum ``sum_{d | gcd(q, m)} mu(q/d) d``, an integer,
    so ``c_q(1) = mu(q)`` and ``c_q(0) = c_q(q) = phi(q)``. ``q < 1`` is
    refused; ``m`` is any integer.
    """
    if q < 1:
        raise ValueError("the modulus of a Ramanujan sum must be positive")
    g = gcd(q, m)
    return sum(moebius(q // d) * d for d in range(1, g + 1) if g % d == 0)
