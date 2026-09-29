# field.mojo
#
# ExactField: a field as a structure, separate from its element type, which is
# what field-generic kernels such as projective_limits are written against.
# An instance names its `Element` and supplies the operations on it. Every
# operation is exact; an invalid one (division by zero, a rejected operand)
# returns an element that is not accepted, and rejection is sticky. `eq` holds
# only between accepted equal elements, and a rejected element is never zero.
#
# Keeping the field apart from its elements lets the imported Q stay a
# byte-for-byte copy of its source: QField adapts it without touching it.
#
# Instances: QField (elements Q) and FpField[p] (elements Fp[p], finite_exact.fp).

from finite_exact.rat_q import Q, q_rejected


trait ExactField:
    comptime Element: Copyable & Deinitable

    @staticmethod
    def zero() -> Self.Element:
        ...

    @staticmethod
    def one() -> Self.Element:
        ...

    @staticmethod
    def from_int(n: Int64) -> Self.Element:
        ...

    @staticmethod
    def rejected() -> Self.Element:
        ...

    @staticmethod
    def accepted(a: Self.Element) -> Bool:
        ...

    @staticmethod
    def is_zero(a: Self.Element) -> Bool:
        ...

    @staticmethod
    def neg(a: Self.Element) -> Self.Element:
        ...

    @staticmethod
    def add(a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    @staticmethod
    def sub(a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    @staticmethod
    def mul(a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    @staticmethod
    def div(a: Self.Element, b: Self.Element) -> Self.Element:
        ...

    @staticmethod
    def eq(a: Self.Element, b: Self.Element) -> Bool:
        ...


struct QField(ExactField):
    """The rationals, with elements finite_exact.rat_q.Q."""

    comptime Element = Q

    @staticmethod
    def zero() -> Q:
        return Q.zero()

    @staticmethod
    def one() -> Q:
        return Q.one()

    @staticmethod
    def from_int(n: Int64) -> Q:
        return Q.from_int(n)

    @staticmethod
    def rejected() -> Q:
        return q_rejected()

    @staticmethod
    def accepted(a: Q) -> Bool:
        return a.accepted()

    @staticmethod
    def is_zero(a: Q) -> Bool:
        return a.accepted() and a.num.is_zero()

    @staticmethod
    def neg(a: Q) -> Q:
        return a.neg()

    @staticmethod
    def add(a: Q, b: Q) -> Q:
        return a.add(b)

    @staticmethod
    def sub(a: Q, b: Q) -> Q:
        return a.sub(b)

    @staticmethod
    def mul(a: Q, b: Q) -> Q:
        return a.mul(b)

    @staticmethod
    def div(a: Q, b: Q) -> Q:
        return a.div(b)

    @staticmethod
    def eq(a: Q, b: Q) -> Bool:
        return a.eq(b)
