# homogeneous.mojo
#
# The degree-2 lift of z -> z^2 + c to the projective line.
# Specification: docs/rational-interval-arithmetic-spec.md.

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult
from finite_exact.rat_q import Q


def unit_box() -> ComplexIQ:
    """The singleton box at the multiplicative unit."""
    return ComplexIQ.singleton(Q(1, 1), Q(0, 1))


def zero_box() -> ComplexIQ:
    """The singleton box at the additive unit."""
    return ComplexIQ.singleton(Q.zero(), Q.zero())


def rejected_box() -> ComplexIQ:
    """A box that is rejected by construction, for a refused result.

    Built from a reversed interval, which `IQ` rejects on construction. A
    refusal is returned as data rather than raised, so a caller decides what a
    refusal means to it.
    """
    var reversed = IQ(Q(1, 1), Q.zero())
    return ComplexIQ(reversed, reversed)


struct Homogeneous(Copyable):
    """A pair of coordinate records, read modulo scaling.

    The fields are named for their place in the pair, not for a value: `[z : w]`
    is a class, and it becomes a value only in a chart.
    """

    var z: ComplexIQ
    var w: ComplexIQ

    def __init__(out self, z: ComplexIQ, w: ComplexIQ):
        self.z = z.copy()
        self.w = w.copy()

    def accepted(self) -> Bool:
        return self.z.accepted() and self.w.accepted()


def homogeneous(z: ComplexIQ, w: ComplexIQ) -> Homogeneous:
    return Homogeneous(z, w)


def infinity() -> Homogeneous:
    """`[1 : 0]`, the class the lift fixes."""
    return Homogeneous(unit_box(), zero_box())


def embed(z: ComplexIQ) -> Homogeneous:
    """`[z : 1]`, the affine plane inside the projective line."""
    return Homogeneous(z, unit_box())


def quadratic_lift(p: Homogeneous, c: ComplexIQ) -> Homogeneous:
    """`F([z : w]) = [z^2 + c w^2 : w^2]`.

    Polynomial in both coordinates: no division, no limit, and no case for
    infinity, which is fixed because the coordinates say so. The two forms
    vanish together only at `z = w = 0`, which is not a class, so the lift has
    no base point and needs no exceptional branch.
    """
    var w_squared = p.w.square()
    return Homogeneous(p.z.square().add(c.mul(w_squared)), w_squared.copy())


def degenerate(p: Homogeneous) -> IQBoolResult:
    """Could both coordinates be zero, leaving no class at all?

    Three-valued and fail-closed: true means the pair is certainly degenerate,
    false means it certainly is not, and a rejected coordinate rejects.
    """
    if not p.accepted():
        return IQBoolResult(False, True)
    var z_nonzero = complex_excludes_zero(p.z)
    var w_nonzero = complex_excludes_zero(p.w)
    if z_nonzero.rejected or w_nonzero.rejected:
        return IQBoolResult(False, True)
    if z_nonzero.value or w_nonzero.value:
        return IQBoolResult(False, False)
    return IQBoolResult(is_exactly_zero(p.z) and is_exactly_zero(p.w), False)


def separated_classes(a: Homogeneous, b: Homogeneous) -> IQBoolResult:
    """Are `a` and `b` provably different classes?

    The test is the cross product `a.z * b.w - b.z * a.w`, which vanishes
    exactly when the pairs are proportional. Over boxes only one direction is
    decidable: a cross product that excludes zero certifies difference, and
    everything else is false, never equality.
    """
    if not (a.accepted() and b.accepted()):
        return IQBoolResult(False, True)
    return complex_excludes_zero(a.z.mul(b.w).sub(b.z.mul(a.w)))


def at_infinity(p: Homogeneous) -> IQBoolResult:
    """Is `p` the class `[1 : 0]`?

    True only for an exactly zero second coordinate with a nonzero first one.
    A box that merely contains zero is not at infinity and does not say it is.
    """
    if not p.accepted():
        return IQBoolResult(False, True)
    var z_nonzero = complex_excludes_zero(p.z)
    if z_nonzero.rejected:
        return IQBoolResult(False, True)
    return IQBoolResult(z_nonzero.value and is_exactly_zero(p.w), False)


def is_exactly_zero(z: ComplexIQ) -> Bool:
    """Is the box the singleton at the origin?"""
    if not z.accepted():
        return False
    return (
        z.re.lo.eq(Q.zero()) and z.re.hi.eq(Q.zero()) and
        z.im.lo.eq(Q.zero()) and z.im.hi.eq(Q.zero())
    )


def complex_excludes_zero(z: ComplexIQ) -> IQBoolResult:
    """Does the box miss the origin in at least one coordinate?"""
    if not z.accepted():
        return IQBoolResult(False, True)
    var re_result = z.re.excludes_zero()
    var im_result = z.im.excludes_zero()
    if re_result.rejected or im_result.rejected:
        return IQBoolResult(False, True)
    return IQBoolResult(re_result.value or im_result.value, False)
