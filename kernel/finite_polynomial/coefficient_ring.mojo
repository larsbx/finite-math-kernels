# coefficient_ring.mojo
#
# The coefficient structures that truncated_jet and taylor_model are written
# against. A ring is a *value* naming its `Element` and supplying the
# operations, so a ring may carry runtime data: Q(zeta_n) with a conductor known
# only at run time is one (finite_polynomial.cyclotomic_field.CyclotomicRing).
# finite_exact.field.ExactField is the static, compile-time counterpart;
# FieldRing adapts any ExactField to this interface without touching it.
#
#   CoefficientRing   zero, one, rejected, accepted, is_zero, add, sub, mul.
#   CoefficientField  a CoefficientRing with inverse (division by a unit).
#
# ComplexBoxRing is the one ring here whose elements are sets: add, sub and
# mul are inclusion-isotone enclosures, not equalities, and it is never a
# field. taylor_model is written over it.
#
# Contract. Every operation is total and never raises; an invalid one (inverse
# of zero, a rejected operand, an element of another ring) returns an element
# that is not accepted, and rejection is sticky. `accepted(a)` holds only for
# an accepted element *of this ring* (same conductor, for instance).
# `is_zero(a)` is a certainty: over an exact ring it is equality with zero, over
# an enclosure ring it holds only for the singleton {0}; a rejected element is
# never zero. Nothing here decides certificate acceptance.
#
# Instances: FieldRing[K] for every ExactField K (QField, FpField[p],
# CyclotomicField[q]); CyclotomicRing (cyclotomic_field); ComplexBoxRing over
# finite_exact.closed_q.ComplexIQ.
#
# Specification: docs/rational-interval-arithmetic-spec.md (coefficients are Q and closed_q boxes).

from finite_exact.closed_q import ComplexIQ
from finite_exact.field import ExactField
from finite_exact.rat_q import Q, q_rejected


trait CoefficientRing(Copyable, Deinitable):
    comptime Element: Copyable & Deinitable

    def zero(self) -> Self.Element:
        ...

    def one(self) -> Self.Element:
        ...

    def rejected(self) -> Self.Element:
        ...

    def accepted(self, a: Self.Element) -> Bool:
        ...

    def is_zero(self, a: Self.Element) -> Bool:
        ...

    def add(self, a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    def sub(self, a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    def mul(self, a: Self.Element, b: Self.Element) -> Self.Element:
        ...


trait CoefficientField(CoefficientRing):
    def inverse(self, a: Self.Element) -> Self.Element:
        """The multiplicative inverse; rejected for zero or a rejected element."""
        ...


struct FieldRing[K: ExactField](CoefficientField):
    """Any finite_exact.field.ExactField, as a CoefficientField."""

    comptime Element = Self.K.Element

    def __init__(out self):
        pass

    def zero(self) -> Self.K.Element:
        return Self.K.zero()

    def one(self) -> Self.K.Element:
        return Self.K.one()

    def rejected(self) -> Self.K.Element:
        return Self.K.rejected()

    def accepted(self, a: Self.K.Element) -> Bool:
        return Self.K.accepted(a)

    def is_zero(self, a: Self.K.Element) -> Bool:
        return Self.K.is_zero(a)

    def add(self, a: Self.K.Element, b: Self.K.Element) -> Self.K.Element:
        return Self.K.add(a, b)

    def sub(self, a: Self.K.Element, b: Self.K.Element) -> Self.K.Element:
        return Self.K.sub(a, b)

    def mul(self, a: Self.K.Element, b: Self.K.Element) -> Self.K.Element:
        return Self.K.mul(a, b)

    def inverse(self, a: Self.K.Element) -> Self.K.Element:
        return Self.K.div(Self.K.one(), a)


struct ComplexBoxRing(CoefficientRing):
    """Rectangular boxes over Q (closed_q.ComplexIQ) as an enclosure ring.

    Boxes are not a ring -- multiplication is only subdistributive -- so a jet
    over boxes encloses the exact jet of every choice of points in its input
    boxes, and states no equality. A singleton box is an exact Gaussian
    rational, and over singletons every operation here is exact.
    """

    comptime Element = ComplexIQ

    def __init__(out self):
        pass

    def zero(self) -> ComplexIQ:
        return ComplexIQ.singleton(Q.zero(), Q.zero())

    def one(self) -> ComplexIQ:
        return ComplexIQ.singleton(Q(1, 1), Q.zero())

    def rejected(self) -> ComplexIQ:
        return ComplexIQ.singleton(q_rejected(), q_rejected())

    def accepted(self, a: ComplexIQ) -> Bool:
        return a.accepted()

    def is_zero(self, a: ComplexIQ) -> Bool:
        return (
            a.accepted()
            and a.re.lo.eq(Q.zero()) and a.re.hi.eq(Q.zero())
            and a.im.lo.eq(Q.zero()) and a.im.hi.eq(Q.zero())
        )

    def add(self, a: ComplexIQ, b: ComplexIQ) -> ComplexIQ:
        return a.add(b)

    def sub(self, a: ComplexIQ, b: ComplexIQ) -> ComplexIQ:
        return a.sub(b)

    def mul(self, a: ComplexIQ, b: ComplexIQ) -> ComplexIQ:
        return a.mul(b)

    def square(self, a: ComplexIQ) -> ComplexIQ:
        """The sharp square, tighter than mul(a, a) when a straddles an axis."""
        return a.square()

    def identical(self, a: ComplexIQ, b: ComplexIQ) -> Bool:
        """The same accepted box, endpoint for endpoint."""
        return (
            a.accepted() and b.accepted()
            and a.re.lo.eq(b.re.lo) and a.re.hi.eq(b.re.hi)
            and a.im.lo.eq(b.im.lo) and a.im.hi.eq(b.im.hi)
        )
