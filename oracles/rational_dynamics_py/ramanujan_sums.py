"""Ramanujan sums as divisor sums, exactly.

``c_q(m)`` is the sum of ``exp(2 pi i a m / q)`` over the units ``a`` modulo
``q``; it is an integer, ``sum_{d | gcd(q, m)} mu(q/d) d``. References:
S. Ramanujan, "On certain trigonometrical sums and their applications in the
theory of numbers", Trans. Cambridge Philos. Soc. 22 (1918) 259-276;
G. H. Hardy and E. M. Wright, *An Introduction to the Theory of Numbers*
(1938; 6th ed., Oxford, 2008), section 16.6.

Ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
experiments/scripts/spectral.py (``ramanujan``, which summed cosines in
floating point; here it is the exact divisor sum). The truncated Brjuno sum
of spectral.py stays in that repository: it is a sum of logarithms, not an
exact quantity. Previously in ``arithmetic``, which still re-exports it.

What is claimed: each value is the exact integer of the definition. What is
not: any spectral or asymptotic statement a consumer builds on it.
"""

from __future__ import annotations

from math import gcd

from .addresses import require_int
from .moebius_function import moebius


def ramanujan_sum(q: int, m: int) -> int:
    """``c_q(m) = sum over units a mod q of exp(2 pi i a m / q)``, exactly.

    Evaluated as the divisor sum ``sum_{d | gcd(q, m)} mu(q/d) d``, an integer,
    so ``c_q(1) = mu(q)`` and ``c_q(0) = c_q(q) = phi(q)``. ``q < 1`` is
    refused; ``m`` is any integer.
    """
    require_int(q, m)
    if q < 1:
        raise ValueError("the modulus of a Ramanujan sum must be positive")
    g = gcd(q, m)
    return sum(moebius(q // d) * d for d in range(1, g + 1) if g % d == 0)
