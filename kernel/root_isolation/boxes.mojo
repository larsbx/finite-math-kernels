# boxes.mojo
#
# Specification: docs/root-isolation-spec.md, sections 1.2, 1.4, 3 and 6, n = 1.
# Arithmetic: docs/rational-interval-arithmetic-spec.md, sections 2.3-2.4
# (enclosures over `closed_q`; the strict-inclusion hypothesis of 2.4).
#
# The generic box helpers the named certificates use: the exact centre, the
# exact inverse of a point, and the two tests that need no theorem --
# exclusion (`0` missed by an enclosure of `F(X)`) and disjointness. A
# refusal is a rejected value; nothing here raises or aborts.

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult
from finite_exact.rat_q import Q


def rejected_box() -> ComplexIQ:
    """A refusal that is a value: `accepted() == False`."""
    return ComplexIQ.singleton(Q(1, 0), Q(1, 0))

def centre(x: ComplexIQ) -> ComplexIQ:
    """The point at the exact centre of a box, never rounded (spec 1.2)."""
    if not x.accepted():
        return rejected_box()
    var two = Q(2, 1)
    return ComplexIQ.singleton(x.re.lo.add(x.re.hi).div(two), x.im.lo.add(x.im.hi).div(two))

def is_point(w: ComplexIQ) -> Bool:
    return w.accepted() and w.re.lo.eq(w.re.hi) and w.im.lo.eq(w.im.hi)

def exact_inverse(w: ComplexIQ) -> ComplexIQ:
    """`1/w` for a point `w`, exactly: `(a - bi) / (a^2 + b^2)`.

    A box that is not a point, or the point zero, is refused (spec 1.4).
    """
    if not is_point(w):
        return rejected_box()
    var a = w.re.lo.copy()
    var b = w.im.lo.copy()
    var quadrance = a.square().add(b.square())
    if not quadrance.accepted() or quadrance.eq(Q.zero()):
        return rejected_box()
    return ComplexIQ.singleton(a.div(quadrance), b.neg().div(quadrance))

def excludes_zero(value: ComplexIQ) -> IQBoolResult:
    """The exclusion test on an enclosure of `F(X)`: does it miss the origin
    in its real or its imaginary part? Rejected on a rejected enclosure."""
    if not value.accepted():
        return IQBoolResult(False, True)
    return IQBoolResult(value.re.excludes_zero().value or value.im.excludes_zero().value, False)

def disjoint(a: ComplexIQ, b: ComplexIQ) -> IQBoolResult:
    """Strict separation of two closed boxes in a real coordinate."""
    if not (a.accepted() and b.accepted()):
        return IQBoolResult(False, True)
    return IQBoolResult(
        a.re.hi.lt(b.re.lo) or b.re.hi.lt(a.re.lo) or a.im.hi.lt(b.im.lo) or b.im.hi.lt(a.im.lo),
        False,
    )