"""The characteristic arc (the ``p/q``-wake angles) of the ``p/q`` rotation
cycle of doubling, exactly.

The shortest arc between consecutive points of the ``p/q`` rotation cycle is
``(x_{p-1}, x_p)``, of length ``1/(2^q - 1)``; its endpoints are the two
external angles bounding the ``p/q``-limb (wake) of the Mandelbrot set.
References: A. Douady and J. H. Hubbard, *Etude dynamique des polynomes
complexes*, Publ. Math. d'Orsay 84-02 and 85-04 (1984-85) [DH];
J. Milnor, "Periodic orbits, external rays and the Mandelbrot set: an
expository account", Asterisque 261 (2000) 277-333 [Mil00]; L. R. Goldberg,
"Fixed points of polynomial maps. I. Rotation subsets of the circles",
Ann. Sci. Ecole Norm. Sup. (4) 25 (1992) 679-685.

Ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
kernel/bulbford/wake.py (``wake``). Previously in ``doubling``, which still
re-exports it.

What is claimed: the function computes the characteristic arc of the
rotation cycle exactly. What is not: that this arc is the angular width of
the ``p/q``-wake [DH, Mil00], an imported theorem a consumer cites; this
module neither proves nor uses it.
"""

from __future__ import annotations

from fractions import Fraction

from .addresses import require_int
from .rotation_sets import rotation_cycle


def wake(p: int, q: int) -> tuple[Fraction, Fraction]:
    """``(theta_minus, theta_plus)``: the characteristic arc of the ``p/q`` rotation cycle.

    The consecutive cycle points bounding the shortest arc; that arc is
    ``(x_{p-1}, x_p)`` and has length ``1/(2^q - 1)``. Bulbs ``wake``; the
    Mandelbrot ``rotation_angles`` computes the same pair by enumerating every
    cycle (and returns ``(0, 0)`` at ``r = 0``, which is refused here).
    """
    require_int(p, q)
    cycle = rotation_cycle(p, q)
    return cycle[p - 1], cycle[p]
