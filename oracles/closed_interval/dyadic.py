"""Directed rounding to bounded-precision dyadic rationals, exactly.

Specification section 2.1 (docs/rational-interval-arithmetic-spec.md in the
consumers) admits an endpoint set ``E = F`` with directed rounding -- lower
endpoints toward minus infinity, upper toward plus infinity. A dyadic
rational ``m / 2^s`` with a numerator of about ``precision`` bits is the same
idea done exactly: the rounding direction is a floor or a ceiling over ``Z``,
decided rather than configured, so no hardware rounding mode is involved.

The exact backend never rounds, so coefficients grow without bound; directed
rounding is what lets a consumer trade width for size. Nothing here loses
soundness: ``round_down(x) <= x <= round_up(x)`` always, and an outward
rounded interval contains the one it came from.

Ported from larsbx/finite-julia-set-research reference/dyadic.py with its
names and its convention that a ``precision`` below one means "do not round"
(the identity, which is exact and therefore sound). Different here: a float
argument is refused with ``TypeError`` rather than converted, and
``round_outward`` refuses a reversed pair ``lo > hi`` with ``ValueError``
rather than returning a reversed pair.

What is claimed: the directed inequalities, and that the result is
``m / 2^s`` with ``s = scale_for(x, precision)`` and ``|m| <= 2^precision``.
What is not: that it is the nearest such dyadic in any sense beyond the
stated floor and ceiling.
"""

from __future__ import annotations

from fractions import Fraction

from .interval import IQ, Scalar, exact

#: Enough to hold the Julia corpus's exact constants without rounding at all.
DEFAULT_PRECISION = 53


def significant_bits(x: Scalar) -> int:
    """The bit length of the numerator of ``x`` in lowest terms, or ``0``."""
    x = exact(x)
    return 0 if x == 0 else abs(x.numerator).bit_length()


def scale_for(x: Fraction, precision: int) -> int:
    """The exponent ``s`` making ``x * 2^s`` an integer of about ``precision`` bits."""
    x = exact(x)
    exponent = abs(x.numerator).bit_length() - abs(x.denominator).bit_length()
    return precision - 1 - exponent


def round_down(x: Scalar, precision: int = DEFAULT_PRECISION) -> Fraction:
    """The largest dyadic of that precision at most ``x`` (``x`` itself when
    ``precision < 1``)."""
    x = exact(x)
    if x == 0 or precision < 1:
        return x
    scale = scale_for(x, precision)
    shifted = x * Fraction(2) ** scale
    return Fraction(shifted.numerator // shifted.denominator) / Fraction(2) ** scale


def round_up(x: Scalar, precision: int = DEFAULT_PRECISION) -> Fraction:
    """The smallest dyadic of that precision at least ``x`` (``x`` itself when
    ``precision < 1``)."""
    return -round_down(-exact(x), precision)


def round_outward(lo: Scalar, hi: Scalar, precision: int = DEFAULT_PRECISION) -> tuple[Fraction, Fraction]:
    """``(round_down(lo), round_up(hi))``: an interval of that precision
    containing ``[lo, hi]``, never narrower. A reversed pair is refused."""
    lo, hi = exact(lo), exact(hi)
    if lo > hi:
        raise ValueError("round_outward needs lo <= hi")
    return round_down(lo, precision), round_up(hi, precision)


def round_interval(value: IQ, precision: int = DEFAULT_PRECISION) -> IQ:
    """``value`` rounded outward; a rejected interval stays rejected."""
    if not value.accepted():
        return IQ.refused()
    return IQ.of(*round_outward(value.lo, value.hi, precision))
