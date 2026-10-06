"""Dedekind sums by the reciprocity law, exactly.

``s(h, k) = sum_{r=1}^{k-1} ((r/k)) ((h r/k))`` with the sawtooth ``((x))``.
References: R. Dedekind, "Erlaeuterungen zu zwei Fragmenten von Riemann", in
B. Riemann, *Gesammelte mathematische Werke* (2nd ed., 1892), 466-478, where
the sums and their reciprocity law first appear; H. Rademacher and E. Grosswald,
*Dedekind Sums*, Carus Mathematical Monographs 16 (MAA, 1972), chapter 2.

Ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
experiments/scripts/bridges_spike.py (``dedekind``, the reciprocity
algorithm). Previously in ``arithmetic``, which still re-exports it.

What is claimed: each value is the exact rational of the definition. What is
not: any spectral or asymptotic statement a consumer builds on it.
"""

from __future__ import annotations

from fractions import Fraction
from math import gcd

from .addresses import require_int


def dedekind_sum(h: int, k: int) -> Fraction:
    """``s(h, k) = sum_{r=1}^{k-1} ((r/k)) ((h r/k))`` for ``k >= 1``, exactly.

    ``((x))`` is the sawtooth ``x - floor(x) - 1/2`` off the integers and ``0``
    on them. Computed by reciprocity,
    ``s(h, k) + s(k, h) = (h^2 + k^2 + 1) / (12 h k) - 1/4`` for coprime
    ``h, k > 0``, after reducing ``h`` modulo ``k`` and dividing out
    ``gcd(h, k)`` (``s(dh, dk) = s(h, k)``), so it costs a Euclidean
    algorithm, not ``k`` terms. ``k < 1`` is refused.
    """
    require_int(h, k)
    if k < 1:
        raise ValueError("the modulus of a Dedekind sum must be positive")
    common = gcd(h, k)
    h, k = (h // common) % (k // common), k // common
    s, sign = Fraction(0), 1
    while k > 1 and h:
        s += sign * (Fraction(h * h + k * k + 1, 12 * h * k) - Fraction(1, 4))
        h, k, sign = k % h, h, -sign
    return s
