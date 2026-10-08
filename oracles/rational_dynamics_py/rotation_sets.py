"""Rotation sets of the doubling map: the ``p/q`` rotation cycle and the
rotation number of a finite invariant set, exactly.

For ``0 < p/q < 1`` in lowest terms, doubling has a cycle
``x_0 < ... < x_{q-1}`` of angles over ``2^q - 1`` on which it acts as the
rotation ``x_i -> x_{i+p mod q}``. References: L. R. Goldberg, "Fixed points
of polynomial maps. I. Rotation subsets of the circles", Ann. Sci. Ecole
Norm. Sup. (4) 25 (1992) 679-685, which proves that this cycle is the unique
one with rotation number ``p/q`` [Gol92]; S. Bullett and P. Sentenac,
"Ordered orbits of the shift, square roots, and the devil's staircase",
Math. Proc. Cambridge Philos. Soc. 115 (1994) 451-481. The cycle's angles
are the ``mechanical_word`` conjugates.

Ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
kernel/bulbford/wake.py (``rotation_cycle``) and kernel/bulbford/cycles.py
(``rotation_number``). Previously in ``doubling``, which still re-exports
both.

What is claimed: each function computes the stated combinatorial object of
the doubling map exactly. What is not: the uniqueness of the rotation cycle
[Gol92], an imported theorem a consumer cites; this module neither proves nor
uses it.
"""

from __future__ import annotations

from collections.abc import Iterable
from fractions import Fraction

from .addresses import require_int
from .mechanical_words import _reduced, mechanical_word


def rotation_cycle(p: int, q: int) -> tuple[Fraction, ...]:
    """The doubling cycle ``x_0 < ... < x_{q-1}`` of rotation number ``p/q``.

    Every ``x_i`` has denominator dividing ``2^q - 1`` and doubling maps ``x_i``
    to ``x_{i+p mod q}``. Refuses anything but ``0 < p < q`` coprime.
    """
    require_int(p, q)
    _reduced(p, q)
    big = 2**q - 1
    return tuple(Fraction(mechanical_word(p, q, r), big) for r in range(q))


def rotation_number(angles: Iterable[int], modulus: int) -> Fraction | None:
    """``s/k`` if doubling shifts the ``k`` sorted angles cyclically by ``s`` places, else ``None``.

    ``angles`` are numerators over ``M``, taken modulo ``M``; they must be
    distinct and closed under doubling (a union of doubling cycles), and a set
    that is not is refused rather than read. ``None`` is the exact answer
    that doubling does not act on the set as a rotation. A single fixed point
    has rotation number ``0``. Bulbs ``rotation_number``, which raised
    ``KeyError`` on a set not closed under doubling.
    """
    angles = tuple(angles)
    require_int(*angles, modulus)
    if modulus < 1:
        raise ValueError("the modulus must be positive")
    ordered = sorted(a % modulus for a in angles)
    if not ordered:
        raise ValueError("an empty set of angles has no rotation number")
    if len(set(ordered)) != len(ordered):
        raise ValueError("angles must be distinct modulo M")
    k = len(ordered)
    position = {a: i for i, a in enumerate(ordered)}
    if any(2 * a % modulus not in position for a in ordered):
        raise ValueError("angles must be closed under doubling")
    shifts = {(position[2 * a % modulus] - i) % k for i, a in enumerate(ordered)}
    return Fraction(shifts.pop(), k) if len(shifts) == 1 else None
