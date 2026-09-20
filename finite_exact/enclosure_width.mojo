# enclosure_width.mojo
#
# Specification: docs/rational-interval-arithmetic-spec.md, section 2.5.
#
# The quantitative half of the wrapping effect. Section 2.3's inclusion
# theorem says the enclosure contains the point and nothing about how far the
# two drift apart, so it cannot say whether refining a box ever decides
# anything. These bounds say it, from one number the caller supplies: a
# rational step factor `K >= 1` with `rad(F(X)) <= K rad(X)` for every
# enclosure confined to the region of interest.
#
# K belongs to the caller because it depends on the map. Everything here is
# the same for every map that has one, which is why it lives in the interval
# layer rather than in any one consumer's dynamics.

from finite_exact.closed_q import ComplexIQ
from finite_exact.rat_q import Q, q_max


def sup_radius(box: ComplexIQ) -> Q:
    """Half the larger coordinate width: the radius in the sup norm."""
    if not box.accepted():
        return Q(0, 0)
    var widths = q_max(box.re.hi.sub(box.re.lo), box.im.hi.sub(box.im.lo))
    return widths.div(Q(2, 1))


def iterated_radius_bound(factor: Q, steps: Int, radius: Q) -> Q:
    """`K^n r`, valid while every iterate stays in the confining region."""
    if steps < 0 or not (factor.accepted() and radius.accepted()):
        return Q(0, 0)
    var accumulated = radius.copy()
    for _ in range(steps):
        accumulated = accumulated.mul(factor)
    return accumulated.copy()


def orbit_gap_bound(factor: Q, steps: Int, radius: Q) -> Q:
    """`2 K^n r`: how far the enclosure can be from the orbit it contains.

    The enclosure contains the iterate of every point of the box, so a bound
    on its radius bounds their distance, doubled.
    """
    return Q(2, 1).mul(iterated_radius_bound(factor, steps, radius))


def refinement_radius(factor: Q, steps: Int, margin: Q) -> Q:
    """`margin / (2 K^n)`: refine below it and a certificate that holds for
    the point with that margin holds for the whole enclosure."""
    if not (margin.accepted() and Q.zero().lt(margin)):
        return Q(0, 0)
    return margin.div(Q(2, 1).mul(iterated_radius_bound(factor, steps, Q(1, 1))))


def confined(factor: Q, steps: Int, radius: Q) -> Bool:
    """Is the box small enough that its enclosures cannot leave the region?

    The induction the bounds rest on: while the enclosure stays within `1` of
    an orbit that stays a unit inside the region, it stays in the region.
    """
    return orbit_gap_bound(factor, steps, radius).le(Q(1, 1))


def enclosure_width_smoke() -> Bool:
    """The bounds against each other, on the cases the statement turns on."""
    var factor = Q(6, 1)
    var radius = Q(1, 4)
    # Zero steps is the box itself, and the gap is its diameter.
    if not iterated_radius_bound(factor, 0, radius).eq(radius):
        return False
    if not orbit_gap_bound(factor, 0, radius).eq(Q(1, 2)):
        return False
    # Steps compose.
    if not iterated_radius_bound(factor, 2, radius).eq(factor.square().mul(radius)):
        return False
    # The refinement radius delivers its margin, and only just.
    var margin = Q(1, 10)
    var refined = refinement_radius(factor, 3, margin)
    if not orbit_gap_bound(factor, 3, refined).eq(margin):
        return False
    # A margin at most one also confines, which is what the induction needs.
    if not confined(factor, 3, refined):
        return False
    # Refusals are values, not aborts.
    if refinement_radius(factor, 3, Q(0, 1)).accepted():
        return False
    return not iterated_radius_bound(factor, -1, radius).accepted()
