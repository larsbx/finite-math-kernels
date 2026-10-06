"""Reduced fractions, continued fractions and Farey structure, exactly.

Everything here is integer arithmetic over Python's unbounded ``int`` and
``fractions.Fraction``; nothing is rounded and nothing is capped. A value
outside a function's domain is refused with ``ValueError``, never coerced into
range.

The R1 part (``Address`` to ``farey_adjacent``) is the independent Python
reference for the Mojo ``rational_dynamics`` package and was previously
``reference/rational_dynamics_reference.py``; that file now re-exports it.
The rest is ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
(kernel/bulbford/cf.py and wake.py) and larsbx/finite-mandelbrot-research
(reference/python/atlas/structure_names_reference.py, ``farey_neighbours``);
the package docstring lists where each consumer's semantics differ.

What is claimed: each function computes the stated finite object exactly.
What is not: nothing here says anything about parameter space, landing of
rays or any other dynamical fact a consumer reads into these objects.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from fractions import Fraction
from math import gcd


@dataclass(frozen=True, slots=True)
class Address:
    """``numerator / denominator`` in lowest terms, both non-negative."""

    numerator: int
    denominator: int


def require_int(*values: object) -> None:
    """Refuse anything that is not an ``int`` (``bool`` included) instead of coercing it."""
    for value in values:
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError(f"expected an integer, got {type(value).__name__}")


def address(numerator: int, denominator: int) -> Address:
    """The reduced address of ``numerator / denominator``; refuses a negative
    numerator and a non-positive denominator."""
    require_int(numerator, denominator)
    if numerator < 0:
        raise ValueError("numerator must be nonnegative")
    if denominator <= 0:
        raise ValueError("denominator must be positive")
    common = gcd(numerator, denominator)
    return Address(numerator // common, denominator // common)


def double_mod_one(value: Address) -> Address:
    """``2 x mod 1`` of an address."""
    return address((2 * value.numerator) % value.denominator, value.denominator)


def mod_inverse(value: Address) -> int:
    """``p^{-1} mod q`` in ``[1, q)`` for ``value = p/q``; refuses a zero residue."""
    residue = value.numerator % value.denominator
    if residue == 0:
        raise ValueError("zero residue is not invertible")
    return pow(residue, -1, value.denominator)


def signed_mod_inverse(value: Address) -> int:
    """The inverse of ``mod_inverse`` centred into ``(-q/2, q/2]``."""
    inv = mod_inverse(value)
    return inv - value.denominator if 2 * inv > value.denominator else inv


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


def farey_determinant(left: Address, right: Address) -> int:
    """``a d - b c`` for ``left = a/b`` and ``right = c/d``."""
    return left.numerator * right.denominator - left.denominator * right.numerator


def farey_adjacent(left: Address, right: Address) -> bool:
    """Whether the Farey determinant is ``+-1``."""
    return abs(farey_determinant(left, right)) == 1


# --- beyond R1 ----------------------------------------------------------------


def as_fraction(value: Fraction | int | Address) -> Fraction:
    """An ``Address``, ``int`` or ``Fraction`` as a ``Fraction``; refuses
    anything else, a float included, rather than converting it."""
    if isinstance(value, Address):
        return Fraction(value.numerator, value.denominator)
    if isinstance(value, bool) or not isinstance(value, (int, Fraction)):
        raise TypeError(f"expected an int, Fraction or Address, got {type(value).__name__}")
    return Fraction(value)


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


def units(q: int) -> tuple[int, ...]:
    """The residues ``0 <= p < q`` coprime to ``q``, increasing: ``(Z/qZ)^x``.

    ``len(units(q))`` is Euler's ``phi(q)`` for every ``q >= 1``; in
    particular ``units(1) == (0,)``. For ``q >= 2`` this is the bulbs
    ``coprime_numerators(q)``; at ``q == 1`` that returned ``()``.
    """
    require_int(q)
    if q < 1:
        raise ValueError("the modulus must be positive")
    return tuple(p for p in range(q) if gcd(p, q) == 1)


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
