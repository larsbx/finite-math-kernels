"""Closed rational intervals and complex boxes, the Python twin of ``closed_q``.

``IQ`` and ``ComplexIQ`` follow ``kernel/finite_exact/closed_q.mojo`` (public
boundary: docs/exact-arithmetic-public-boundary.md): exact ``Fraction``
endpoints, enclosure semantics, a rejected value that poisons every operation
it enters, and no promotion of an unknown containment to an answer. Ported
from larsbx/finite-julia-set-research reference/interval_box.py, whose public
names are kept (``ComplexBox`` is the same class as ``ComplexIQ``) so that
consumer can switch by import path alone.

Where this differs from ``closed_q.mojo``: a Mojo predicate returns a value
and a rejection flag; here a predicate returns a plain ``bool`` that is
``False`` on a rejected operand, for *every* predicate, ``excludes_zero``
included, so a refusal is never read as evidence either way. ``sign`` returns
``None`` on a rejected operand.

Where this differs from the Julia copy, deliberately and fail-closed:

- ``width`` and ``midpoint`` of a rejected interval raise ``ValueError``; the
  Julia copy answered ``0`` and ``1/2``, so a refused box looked converged.
- Endpoints must be ``int`` or ``Fraction``; a ``float`` (or a string) is
  refused with ``TypeError`` rather than converted.
- The dataclass constructor itself rejects reversed endpoints, as the Mojo
  constructor does; the Julia copy did so only in ``IQ.of``.

Added beyond the Julia copy: ``IQ.excludes_zero`` and ``IQ.sign`` (from
``closed_q.mojo``), ``ComplexIQ.neg``, ``conjugate``, ``contains_zero`` and
``midpoint``.

What is claimed: every result encloses the exact image of its operands, and
the square is the sharp one (spec section 2.5). What is not: tightness of any
other operation, or anything about the sets the boxes are used to cover.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Union

Scalar = Union[int, Fraction]


def exact(value: Scalar) -> Fraction:
    """``value`` as a ``Fraction``; refuses a float, a bool or anything else."""
    if isinstance(value, bool) or not isinstance(value, (int, Fraction)):
        raise TypeError(f"an exact endpoint must be an int or Fraction, got {type(value).__name__}")
    return Fraction(value)


@dataclass(frozen=True, slots=True)
class IQ:
    """A closed interval ``[lo, hi]`` with exact rational endpoints, or a rejected result."""

    lo: Fraction
    hi: Fraction
    rejected: bool = False

    def __post_init__(self) -> None:
        lo, hi = exact(self.lo), exact(self.hi)
        object.__setattr__(self, "lo", lo)
        object.__setattr__(self, "hi", hi)
        if lo > hi:
            object.__setattr__(self, "rejected", True)

    @staticmethod
    def of(lo: Scalar, hi: Scalar) -> "IQ":
        """``[lo, hi]``, rejected when ``lo > hi``."""
        return IQ(exact(lo), exact(hi))

    @staticmethod
    def singleton(x: Scalar) -> "IQ":
        return IQ.of(x, x)

    @staticmethod
    def refused() -> "IQ":
        return IQ(Fraction(1), Fraction(0), True)

    def accepted(self) -> bool:
        return not self.rejected

    def add(self, other: "IQ") -> "IQ":
        if self.rejected or other.rejected:
            return IQ.refused()
        return IQ.of(self.lo + other.lo, self.hi + other.hi)

    def sub(self, other: "IQ") -> "IQ":
        if self.rejected or other.rejected:
            return IQ.refused()
        return IQ.of(self.lo - other.hi, self.hi - other.lo)

    def neg(self) -> "IQ":
        return IQ.refused() if self.rejected else IQ.of(-self.hi, -self.lo)

    def mul(self, other: "IQ") -> "IQ":
        if self.rejected or other.rejected:
            return IQ.refused()
        corners = [self.lo * other.lo, self.lo * other.hi, self.hi * other.lo, self.hi * other.hi]
        return IQ.of(min(corners), max(corners))

    def square(self) -> "IQ":
        """``{x^2 : x in X}`` exactly: never negative, so sharper than ``mul(self)``
        whenever ``0`` is inside."""
        if self.rejected:
            return IQ.refused()
        if self.lo >= 0:
            return IQ.of(self.lo * self.lo, self.hi * self.hi)
        if self.hi <= 0:
            return IQ.of(self.hi * self.hi, self.lo * self.lo)
        return IQ.of(Fraction(0), max(self.lo * self.lo, self.hi * self.hi))

    def contains_zero(self) -> bool:
        """``0 in X``; ``False`` for a rejected interval."""
        return self.accepted() and self.lo <= 0 <= self.hi

    def excludes_zero(self) -> bool:
        """``0 not in X``; also ``False`` for a rejected interval."""
        return self.accepted() and not self.lo <= 0 <= self.hi

    def sign(self) -> int | None:
        """``1`` if every point is positive, ``-1`` if every point is negative,
        ``0`` when ``0`` is inside (unknown), ``None`` when rejected."""
        if self.rejected:
            return None
        if self.lo > 0:
            return 1
        if self.hi < 0:
            return -1
        return 0

    def reciprocal(self) -> "IQ":
        """``1/X``, refused where the interval meets zero: the domain of a
        division is enforced by the arithmetic, not by a caller contract."""
        if not self.accepted() or self.contains_zero():
            return IQ.refused()
        return IQ.of(1 / self.hi, 1 / self.lo)

    def subset_of(self, other: "IQ") -> bool:
        if self.rejected or other.rejected:
            return False
        return other.lo <= self.lo and self.hi <= other.hi

    def strict_subset_of(self, other: "IQ") -> bool:
        """Inside the interior of ``other``."""
        if self.rejected or other.rejected:
            return False
        return other.lo < self.lo and self.hi < other.hi

    def midpoint(self) -> Fraction:
        """The exact centre; a rejected interval has none and raises."""
        if self.rejected:
            raise ValueError("a rejected interval has no midpoint")
        return (self.lo + self.hi) / 2

    def width(self) -> Fraction:
        """``hi - lo``; a rejected interval has none and raises."""
        if self.rejected:
            raise ValueError("a rejected interval has no width")
        return self.hi - self.lo


@dataclass(frozen=True, slots=True)
class ComplexIQ:
    """A rank-2 box: one exact rational interval per coordinate."""

    re: IQ
    im: IQ

    @staticmethod
    def of(re_lo: Scalar, re_hi: Scalar, im_lo: Scalar, im_hi: Scalar) -> "ComplexIQ":
        return ComplexIQ(IQ.of(re_lo, re_hi), IQ.of(im_lo, im_hi))

    @staticmethod
    def singleton(re: Scalar, im: Scalar = 0) -> "ComplexIQ":
        return ComplexIQ(IQ.singleton(re), IQ.singleton(im))

    @staticmethod
    def refused() -> "ComplexIQ":
        return ComplexIQ(IQ.refused(), IQ.refused())

    def accepted(self) -> bool:
        return self.re.accepted() and self.im.accepted()

    def add(self, other: "ComplexIQ") -> "ComplexIQ":
        return ComplexIQ(self.re.add(other.re), self.im.add(other.im))

    def sub(self, other: "ComplexIQ") -> "ComplexIQ":
        return ComplexIQ(self.re.sub(other.re), self.im.sub(other.im))

    def neg(self) -> "ComplexIQ":
        return ComplexIQ(self.re.neg(), self.im.neg())

    def conjugate(self) -> "ComplexIQ":
        """``X - iY``, exactly."""
        if not self.accepted():
            return ComplexIQ.refused()
        return ComplexIQ(self.re, self.im.neg())

    def mul(self, other: "ComplexIQ") -> "ComplexIQ":
        """The expanded product; valid, not sharp (each coordinate occurs twice)."""
        return ComplexIQ(
            self.re.mul(other.re).sub(self.im.mul(other.im)),
            self.re.mul(other.im).add(self.im.mul(other.re)),
        )

    def square(self) -> "ComplexIQ":
        """``(X + iY)^2 = (X^2 - Y^2) + i(2 X Y)`` with the sharp coordinate square,
        not ``mul(self)``: the spec section 2.5 dependency problem."""
        if not self.accepted():
            return ComplexIQ.refused()
        real = self.re.square().sub(self.im.square())
        cross = self.re.mul(self.im)
        return ComplexIQ(real, cross.add(cross))

    def quadrance(self) -> IQ:
        """``X^2 + Y^2``, the squared modulus, with the sharp squares."""
        return self.re.square().add(self.im.square())

    def reciprocal(self) -> "ComplexIQ":
        """``1/z`` as conjugate over quadrance, refused when the quadrance
        interval contains zero. Valid, not tight: numerator and reciprocal
        are enclosed separately."""
        if not self.accepted():
            return ComplexIQ.refused()
        inverse = self.quadrance().reciprocal()
        if not inverse.accepted():
            return ComplexIQ.refused()
        conj = self.conjugate()
        return ComplexIQ(conj.re.mul(inverse), conj.im.mul(inverse))

    def contains_zero(self) -> bool:
        """``0 + 0i`` lies in the box; ``False`` when rejected."""
        return self.re.contains_zero() and self.im.contains_zero()

    def subset_of(self, other: "ComplexIQ") -> bool:
        return self.re.subset_of(other.re) and self.im.subset_of(other.im)

    def strict_subset_of(self, other: "ComplexIQ") -> bool:
        return self.re.strict_subset_of(other.re) and self.im.strict_subset_of(other.im)

    def midpoint(self) -> "ComplexIQ":
        """The singleton box at the exact centre; raises when rejected."""
        return ComplexIQ.singleton(self.re.midpoint(), self.im.midpoint())

    def quarters(self) -> tuple["ComplexIQ", ...]:
        """The four boxes of one bisection in each coordinate, ``()`` when rejected.

        Their union is this box and they overlap on the cut lines, which is
        sound for enclosures and is why refinement never loses a point.
        """
        if not self.accepted():
            return ()
        re_mid, im_mid = self.re.midpoint(), self.im.midpoint()
        re_halves = (IQ.of(self.re.lo, re_mid), IQ.of(re_mid, self.re.hi))
        im_halves = (IQ.of(self.im.lo, im_mid), IQ.of(im_mid, self.im.hi))
        return tuple(ComplexIQ(r, i) for r in re_halves for i in im_halves)

    def width(self) -> Fraction:
        """The larger coordinate width; raises when rejected."""
        return max(self.re.width(), self.im.width())


#: The Julia name for ``ComplexIQ``: one class, two names.
ComplexBox = ComplexIQ
