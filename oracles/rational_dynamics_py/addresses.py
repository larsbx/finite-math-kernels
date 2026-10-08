"""Reduced addresses, units and the generic input checks of this package, exactly.

Everything here is integer arithmetic over Python's unbounded ``int`` and
``fractions.Fraction``; nothing is rounded and nothing is capped. A value
outside a function's domain is refused with ``ValueError``, never coerced into
range.

The R1 part (``Address`` to ``signed_mod_inverse``) is the independent Python
reference for the Mojo ``rational_dynamics`` package; with the Farey
determinant of ``farey`` and the expansion of ``continued_fractions`` it was
previously ``reference/rational_dynamics_reference.py``, which now re-exports
it through ``farey``. ``units`` is ported from
larsbx/mandelbrot-bulbs-and-ford-circles-research (kernel/bulbford/wake.py).
These are generic helpers; the named objects built on them live in the
modules named after them (``continued_fractions``, ``farey``,
``moebius_function``, ``dedekind_sums``, ``ramanujan_sums``,
``mechanical_words``, ``rotation_sets``, ``wakes``).

What is claimed: each function computes the stated finite object exactly.
What is not: nothing here says anything about parameter space, landing of
rays or any other dynamical fact a consumer reads into these objects.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from math import gcd


@dataclass(frozen=True, slots=True)
class Address:
    """A reduced address with an integer numerator >= 0 and denominator > 0.

    Direct construction has the same checks and reduction as ``address``.
    """

    numerator: int
    denominator: int

    def __post_init__(self) -> None:
        require_int(self.numerator, self.denominator)
        if self.numerator < 0:
            raise ValueError("numerator must be nonnegative")
        if self.denominator <= 0:
            raise ValueError("denominator must be positive")
        common = gcd(self.numerator, self.denominator)
        object.__setattr__(self, "numerator", self.numerator // common)
        object.__setattr__(self, "denominator", self.denominator // common)


def require_int(*values: object) -> None:
    """Refuse anything that is not an ``int`` (``bool`` included) instead of coercing it."""
    for value in values:
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError(f"expected an integer, got {type(value).__name__}")


def address(numerator: int, denominator: int) -> Address:
    """The reduced address of ``numerator / denominator``; refuses a negative
    numerator and a non-positive denominator."""
    return Address(numerator, denominator)


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


def as_fraction(value: Fraction | int | Address) -> Fraction:
    """An ``Address``, ``int`` or ``Fraction`` as a ``Fraction``; refuses
    anything else, a float included, rather than converting it."""
    if isinstance(value, Address):
        return Fraction(value.numerator, value.denominator)
    if isinstance(value, bool) or not isinstance(value, (int, Fraction)):
        raise TypeError(f"expected an int, Fraction or Address, got {type(value).__name__}")
    return Fraction(value)


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
