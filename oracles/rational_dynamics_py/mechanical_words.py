"""Mechanical (Christoffel, Sturmian) words of rational slope, exactly.

The mechanical word of slope ``p/q`` and intercept ``r/q`` has letter
``k`` equal to ``floor((k + 1) p/q + r/q) - floor(k p/q + r/q)``; for
``0 < p/q < 1`` in lowest terms its ``q`` rotations are the binary codings of
the ``p/q`` rotation of the circle, and read as binary numerators over
``2^q - 1`` they are the angles of the ``p/q`` rotation cycle of doubling.
References: M. Morse and G. A. Hedlund, "Symbolic dynamics II. Sturmian
trajectories", Amer. J. Math. 62 (1940) 1-42; E. B. Christoffel,
"Observatio arithmetica", Annali di Matematica 6 (1875) 148-152;
M. Lothaire, *Algebraic Combinatorics on Words* (Cambridge, 2002), chapter 2
(J. Berstel and P. Seebold, "Sturmian words"), section 2.1.2; for the
doubling-map reading, S. Bullett and P. Sentenac, "Ordered orbits of the
shift, square roots, and the devil's staircase", Math. Proc. Cambridge
Philos. Soc. 115 (1994) 451-481.

Ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
kernel/bulbford/wake.py (``mechanical``). Previously in ``doubling``, which
still re-exports it.

What is claimed: the function computes the stated finite word exactly.
"""

from __future__ import annotations

from math import gcd

from .addresses import require_int


def _reduced(p: int, q: int) -> None:
    if not (0 < p < q and gcd(p, q) == 1):
        raise ValueError("need 0 < p < q with gcd(p, q) = 1")


def mechanical_word(p: int, q: int, r: int) -> int:
    """The conjugate ``c(r)`` of the ``p/q`` rotation cycle, as a numerator over ``2^q - 1``.

    Bit ``k`` (most significant first, ``k < q``) is ``[(r + k p) mod q >= q - p]``,
    so the word is ``format(mechanical_word(p, q, r), f"0{q}b")``. ``c(0)`` is the
    word ``rotation_cycle`` starts from, doubling sends ``c(r)`` to ``c(r + p)``,
    and the sorted cycle is ``c(0) < c(1) < ... < c(q - 1)``. Bulbs ``mechanical``.
    """
    require_int(p, q, r)
    _reduced(p, q)
    return int("".join("1" if (r + k * p) % q >= q - p else "0" for k in range(q)), 2)
