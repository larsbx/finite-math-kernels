"""Exact rational dynamics in pure Python: fractions, Farey structure, the
doubling map on ``Q/Z`` and the arithmetic functions it reads.

This is the vendorable Python plane of ``rational_dynamics`` for consumers
that have no Mojo toolchain (decision D1 of
docs/vendoring-candidates-2026-10-05.md). It depends on the standard library
only (``fractions``, ``math``), is exact throughout, and fails closed: an
input outside a function's domain raises ``ValueError`` (``TypeError`` for a
wrong type). Integer parameters, including both ``Address`` constructor
fields, require non-boolean ``int`` values. An input is never rounded,
clamped or coerced into range. Direct ``Address`` construction enforces a
nonnegative numerator and positive denominator and reduces to lowest terms,
as the ``address`` factory does. No search stops at a cap. It is named
``rational_dynamics_py`` so that it never shares a
package name (and so a ``vendored.toml`` entry) with the Mojo package.

It is non-authoritative in this repository's sense (``oracles/``): the Mojo
``rational_dynamics`` and ``angle_doubling`` packages under ``kernel/`` are
canonical where the two overlap, and the R1 functions here are their
independent Python reference.

Modules. Each named object of the literature has a module named after it,
whose docstring cites its source; the generic helpers have their own module.

``addresses``
    reduced addresses (R1), the modular inverse, units, and the input checks.
``continued_fractions``
    regular continued fractions and convergents (Khinchin; Hardy-Wright X).
``farey``
    Farey determinants and adjacency, mediants, Farey sequences and Farey
    (Stern-Brocot) parents (Farey 1816; Hardy-Wright III).
``doubling``
    preperiod and period in closed form, binary expansions, doubling orbits.
``mechanical_words``
    the mechanical words of a rational rotation (Morse-Hedlund 1940).
``rotation_sets``
    the ``p/q`` rotation cycle of doubling and rotation numbers (Goldberg 1992).
``wakes``
    the characteristic arc of a rotation cycle (Douady-Hubbard; Milnor 2000).
``moebius_function``, ``dedekind_sums``, ``ramanujan_sums``
    Moebius (1832), Dedekind sums by reciprocity (Dedekind 1892;
    Rademacher-Grosswald 1972), Ramanujan sums as divisor sums (1918).

``arithmetic`` (Moebius, Dedekind, Ramanujan) and the moved names of
``farey`` and ``doubling`` remain importable from their old modules, which
re-export the same objects.

Where the consumers' copies this was ported from differ from it, the
difference is deliberate and stated in the function's docstring:

- ``units(1) == (0,)``; bulbs ``coprime_numerators(1) == ()``.
- ``farey_sequence(n)`` is the full ``F_n``; bulbs ``farey(n)`` is
  ``farey_sequence(n, interior=True)``.
- ``farey_parents`` refuses ``r`` outside ``(0, 1)``; Mandelbrot
  ``farey_neighbours`` returned ``None`` sides there, asymmetrically
  (``(None, 1)`` at ``0`` but ``(None, None)`` at ``1``).
- ``wake`` refuses ``p/q = 0``; Mandelbrot ``rotation_angles(0) == (0, 0)``.
- ``period`` is exact with no cap and is the eventual period; math-vizops
  ``period_of`` answered ``None`` both for a preperiodic angle and for a
  period past its cap (``cap=32``, whose loop admits 33), conflating "not
  periodic" with "not found".
- ``exact_type`` reduces any rational modulo one; Mandelbrot ``exact_type``
  answered ``None`` outside ``[0, 1)`` or past a denominator bound of
  ``2^20``, which is that consumer's data policy, not arithmetic.
- ``moebius(n)`` refuses ``n < 1``; the Mandelbrot reference returned ``0``.
- ``ramanujan_sum`` is the exact integer; bulbs ``ramanujan`` summed cosines.
- ``dedekind_sum(h, k)`` divides out ``gcd(h, k)`` before reciprocity, so it
  equals the defining sum for every ``h``; bulbs ``dedekind`` agreed only for
  coprime ``h, k`` (it gave ``s(2, 4) = -1/32``; the sum is ``0``).
- ``rotation_number`` and ``doubling_orbit`` refuse inputs on which the bulbs
  helpers raised ``KeyError`` or looped forever.
"""

from __future__ import annotations

from .addresses import Address, address, as_fraction, double_mod_one, mod_inverse, signed_mod_inverse, units
from .continued_fractions import continued_fraction, convergents, from_continued_fraction
from .dedekind_sums import dedekind_sum
from .doubling import (
    binary_block,
    binary_digits,
    binary_expansion,
    doubling_orbit,
    exact_type,
    order_of_two,
    period,
    preperiod,
)
from .farey import farey_adjacent, farey_determinant, farey_parents, farey_sequence, mediant
from .mechanical_words import mechanical_word
from .moebius_function import moebius
from .ramanujan_sums import ramanujan_sum
from .rotation_sets import rotation_cycle, rotation_number
from .wakes import wake

__all__ = [
    "Address",
    "address",
    "as_fraction",
    "binary_block",
    "binary_digits",
    "binary_expansion",
    "continued_fraction",
    "convergents",
    "dedekind_sum",
    "double_mod_one",
    "doubling_orbit",
    "exact_type",
    "farey_adjacent",
    "farey_determinant",
    "farey_parents",
    "farey_sequence",
    "from_continued_fraction",
    "mechanical_word",
    "mediant",
    "mod_inverse",
    "moebius",
    "order_of_two",
    "period",
    "preperiod",
    "ramanujan_sum",
    "rotation_cycle",
    "rotation_number",
    "signed_mod_inverse",
    "units",
    "wake",
]
