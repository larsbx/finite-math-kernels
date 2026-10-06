"""The Moebius function, exactly.

``mu(n)`` is ``0`` when a square greater than one divides ``n`` and
``(-1)^r`` when ``n`` is a product of ``r`` distinct primes. References:
A. F. Moebius, "Ueber eine besondere Art von Umkehrung der Reihen", J. reine
angew. Math. 9 (1832) 105-123; G. H. Hardy and E. M. Wright, *An Introduction
to the Theory of Numbers* (1938; 6th ed., Oxford, 2008), section 16.3.

Ported from larsbx/finite-mandelbrot-research
reference/python/c1/misiurewicz_catalogue_reference.py (``moebius``).
Previously in ``arithmetic``, which still re-exports it.

What is claimed: each value is the exact integer of the definition.
"""

from __future__ import annotations

from .addresses import require_int


def moebius(n: int) -> int:
    """``mu(n)`` for ``n >= 1``: ``0`` if a square divides ``n``, else ``(-1)^(number of primes)``.

    ``n < 1`` is refused; the Mandelbrot reference returned ``0`` there.
    """
    require_int(n)
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
