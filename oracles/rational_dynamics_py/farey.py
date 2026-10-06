"""The Farey sequence, Farey neighbours and mediants, exactly.

The Farey sequence ``F_n`` lists the reduced fractions in ``[0, 1]`` of
denominator at most ``n``. Two fractions ``a/b < c/d`` are neighbours in some
``F_n`` exactly when ``b c - a d = 1``, and the first fraction to appear
between them is their mediant ``(a + c) / (b + d)``; read the other way, the
two neighbours of ``p/q`` with smaller denominators are its parents in the
Stern-Brocot tree. References: J. Farey, "On a curious property of vulgar
fractions", Philosophical Magazine 47 (1816) 385-386, with the proof of
A.-L. Cauchy, Exercices de mathematiques (1816); G. H. Hardy and E. M. Wright,
*An Introduction to the Theory of Numbers* (1938; 6th ed., Oxford, 2008),
chapter III; M. A. Stern, J. reine angew. Math. 55 (1858) 193-220 and
A. Brocot, Revue chronometrique 3 (1861) 186-194, as presented in R. L.
Graham, D. E. Knuth and O. Patashnik, *Concrete Mathematics* (2nd ed., 1994),
section 4.5.

Everything here is integer arithmetic over Python's unbounded ``int`` and
``fractions.Fraction``; nothing is rounded and nothing is capped. A value
outside a function's domain is refused with ``ValueError``, never coerced into
range. ``farey_determinant`` and ``farey_adjacent`` are part of the R1
reference for the Mojo ``rational_dynamics`` package (whose ``farey.mojo`` is
the canonical twin). The rest is ported from
larsbx/mandelbrot-bulbs-and-ford-circles-research (kernel/bulbford/cf.py and
wake.py) and larsbx/finite-mandelbrot-research
(reference/python/atlas/structure_names_reference.py, ``farey_neighbours``);
the package docstring lists where each consumer's semantics differ.

This module also re-exports, unchanged, the names that lived here before they
moved to their own modules, so ``from rational_dynamics_py.farey import ...``
keeps working: the reduced addresses and generic checks (now ``addresses``) and
the continued fractions (now ``continued_fractions``).

What is claimed: each function computes the stated finite object exactly.
What is not: nothing here says anything about parameter space, landing of
rays or any other dynamical fact a consumer reads into these objects.
"""

from __future__ import annotations

from fractions import Fraction

from .addresses import (
    Address,
    address,
    as_fraction,
    double_mod_one,
    mod_inverse,
    require_int,
    signed_mod_inverse,
    units,
)
from .continued_fractions import continued_fraction, convergents, from_continued_fraction

__all__ = [
    "Address",
    "address",
    "as_fraction",
    "continued_fraction",
    "convergents",
    "double_mod_one",
    "farey_adjacent",
    "farey_determinant",
    "farey_parents",
    "farey_sequence",
    "from_continued_fraction",
    "mediant",
    "mod_inverse",
    "require_int",
    "signed_mod_inverse",
    "units",
]


def farey_determinant(left: Address, right: Address) -> int:
    """``a d - b c`` for ``left = a/b`` and ``right = c/d``."""
    return left.numerator * right.denominator - left.denominator * right.numerator


def farey_adjacent(left: Address, right: Address) -> bool:
    """Whether the Farey determinant is ``+-1``."""
    return abs(farey_determinant(left, right)) == 1


def mediant(left: Fraction | int | Address, right: Fraction | int | Address) -> Fraction:
    """``(a + c) / (b + d)`` for ``left = a/b`` and ``right = c/d`` in lowest terms."""
    a, b = as_fraction(left), as_fraction(right)
    return Fraction(a.numerator + b.numerator, a.denominator + b.denominator)


def farey_sequence(n: int, *, interior: bool = False) -> tuple[Fraction, ...]:
    """The Farey sequence of order ``n``, increasing.

    The full sequence ``F_n`` runs from ``0/1`` to ``1/1`` inclusive; with
    ``interior=True`` both ends are dropped, which is the bulbs ``farey(n)``
    (the rotation numbers of the bulbs of denominator at most ``n``). Built by
    the next-term recurrence, so each term costs a constant number of integer
    operations. ``n < 1`` is refused.
    """
    require_int(n)
    if n < 1:
        raise ValueError("the order must be positive")
    a, b, c, d = 0, 1, 1, n
    out = [Fraction(0)]
    while c <= n:
        k = (n + b) // d
        a, b, c, d = c, d, k * c - a, k * d - b
        out.append(Fraction(a, b))
    return tuple(out[1:-1]) if interior else tuple(out)


def farey_parents(r: Fraction | int | Address) -> tuple[Fraction, Fraction]:
    """The Farey parents ``(a/b, c/d)`` of ``r = p/q`` with ``0 < r < 1``.

    They are the unique fractions with ``a/b < r < c/d``, ``b, d < q``,
    ``a + c = p``, ``b + d = q`` and ``p b - a q = 1 = c q - p d``, i.e. ``r``
    is their mediant and both are Farey neighbours of ``r``. Read off the
    modular inverse: ``b = p^{-1} mod q``. ``r`` outside the open unit
    interval is refused; the Mandelbrot ``farey_neighbours`` instead returned
    ``None`` on the side ``r`` bounds (and ``(None, None)`` at ``r = 1``).
    """
    value = as_fraction(r)
    if not 0 < value < 1:
        raise ValueError("Farey parents are defined here for 0 < r < 1")
    p, q = value.numerator, value.denominator
    b = pow(p, -1, q)
    a = (p * b - 1) // q
    return Fraction(a, b), Fraction(p - a, q - b)
