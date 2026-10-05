# chart.mojo
#
# The two affine charts of the projective line, and the map in each.
# Specification: docs/rational-interval-arithmetic-spec.md.
#
# A chart is a division, so each function here has a domain: the quadrance of
# the coordinate being divided by must exclude zero. Over a box that is a
# three-valued test, and a box that straddles the origin leaves the chart
# rather than being evaluated anyway. Refusal is returned as a rejected box.

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult
from finite_exact.rat_q import Q
from projective.homogeneous import Homogeneous, complex_excludes_zero, rejected_box, unit_box


def complex_reciprocal(z: ComplexIQ) -> ComplexIQ:
    """`1 / z`, as conjugate over quadrance.

    The quadrance interval's reciprocal rejects when it contains zero, so the
    domain of this map is enforced by the arithmetic rather than by a caller
    contract. The enclosure is valid but not tight: the numerator and the
    reciprocal are enclosed separately.
    """
    if not z.accepted():
        return rejected_box()
    var inverse_quadrance = z.quadrance().reciprocal()
    if not inverse_quadrance.accepted():
        return rejected_box()
    return ComplexIQ(z.re.mul(inverse_quadrance), z.im.neg().mul(inverse_quadrance))


def affine_value(p: Homogeneous) -> ComplexIQ:
    """`z / w`, the value of the class in the chart that misses infinity."""
    var inverse = complex_reciprocal(p.w)
    if not inverse.accepted():
        return rejected_box()
    return p.z.mul(inverse)


def chart_at_infinity(p: Homogeneous) -> ComplexIQ:
    """`w / z`, the value of the class in the chart centred on infinity.

    Infinity itself has value zero here, which is the whole point: the class
    the lift fixes becomes an ordinary coordinate record, and the map around
    it becomes an ordinary contraction.
    """
    var inverse = complex_reciprocal(p.z)
    if not inverse.accepted():
        return rejected_box()
    return p.w.mul(inverse)


def chart_step(u: ComplexIQ, c: ComplexIQ) -> ComplexIQ:
    """`u -> u^2 / (1 + c u^2)`, the quadratic map in the chart at infinity.

    Zero is fixed with derivative zero, so infinity is superattracting of
    order two. The denominator is the second domain condition: where it could
    vanish, the step refuses.
    """
    var u_squared = u.square()
    var denominator = unit_box().add(c.mul(u_squared))
    var inverse = complex_reciprocal(denominator)
    if not inverse.accepted():
        return rejected_box()
    return u_squared.mul(inverse)


def in_chart_at_infinity(p: Homogeneous) -> IQBoolResult:
    """Is the class inside the chart centred on infinity?"""
    if not p.accepted():
        return IQBoolResult(False, True)
    return complex_excludes_zero(p.z)


def in_affine_chart(p: Homogeneous) -> IQBoolResult:
    """Is the class inside the chart that misses infinity?"""
    if not p.accepted():
        return IQBoolResult(False, True)
    return complex_excludes_zero(p.w)
