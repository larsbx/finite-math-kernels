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
independent Python reference, as are ``order_of_two``, ``preperiod``,
``period``, ``exact_type``, ``exact_type_count``, ``binary_digits``,
``binary_block`` and ``moebius`` for the Mojo ``rational_dynamics.doubling``,
``.multiplicative_order`` and ``.moebius`` modules
(``tests/rational_dynamics/test_doubling_twin.py``).

Modules:

``farey``
    reduced addresses (R1), continued fractions, units, mediants, Farey
    sequences and Farey parents.
``doubling``
    preperiod and period in closed form, the number of angles of each exact
    type, binary expansions, rotation cycles, mechanical words, characteristic
    arcs (wakes), rotation numbers, doubling
    orbits.
``multiplicative_order``
    ``order_of_two``, the multiplicative order of two (Gauss, 1801).
``carmichael``
    ``carmichael_lambda``, the Carmichael function (Carmichael, 1910).
``arithmetic``
    Moebius, Dedekind sums by reciprocity, Ramanujan sums as divisor sums.

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

from .arithmetic import dedekind_sum, moebius, ramanujan_sum
from .carmichael import carmichael_lambda
from .doubling import (
    binary_block,
    binary_digits,
    binary_expansion,
    doubling_orbit,
    exact_type,
    exact_type_count,
    mechanical_word,
    period,
    preperiod,
    rotation_cycle,
    rotation_number,
    wake,
)
from .multiplicative_order import order_of_two
from .farey import (
    Address,
    address,
    as_fraction,
    continued_fraction,
    convergents,
    double_mod_one,
    farey_adjacent,
    farey_determinant,
    farey_parents,
    farey_sequence,
    from_continued_fraction,
    mediant,
    mod_inverse,
    signed_mod_inverse,
    units,
)

__all__ = [
    "Address",
    "address",
    "as_fraction",
    "binary_block",
    "binary_digits",
    "binary_expansion",
    "carmichael_lambda",
    "continued_fraction",
    "convergents",
    "dedekind_sum",
    "double_mod_one",
    "doubling_orbit",
    "exact_type",
    "exact_type_count",
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
