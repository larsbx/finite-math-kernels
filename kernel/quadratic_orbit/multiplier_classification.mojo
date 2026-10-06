# multiplier_classification.mojo
#
# The classification of a periodic point by its multiplier `lam`: attracting
# (`|lam| < 1`), indifferent (`|lam| = 1`) or repelling (`|lam| > 1`).
# Standard reference: J. Milnor, Dynamics in One Complex Variable, 3rd ed.
# (Annals of Mathematics Studies 160, Princeton, 2006), the chapters on local
# fixed point theory; the attracting case is the setting of the linearization
# theorem of G. Koenigs (Ann. Sci. Ecole Norm. Sup., 1884).
#
# Specification: docs/rational-interval-arithmetic-spec.md.
#
# The multiplier trichotomy of a cycle of `z -> z^2 + c`, decided exactly on
# the quadrance `N(lam)` against `1`. The multiplier of a cycle through `z` of
# period `k` is `orbit_derivative(z, c, k)` (`quadratic_orbit.preperiodic`).
#
# On a box the regime is the one every multiplier in it shares: attracting
# when the upper end of the quadrance is below one, repelling when the lower
# end is above it, indifferent only when the quadrance is exactly `[1, 1]`.
# A box that meets the unit quadrance otherwise is UNDECIDED, and a refusal
# is REJECTED; neither is ever read as attracting or repelling.
#
# What this does not decide: superattracting is the attracting case at
# `lam = 0`, and the indifferent case's parabolic-versus-irrational split is
# arithmetic of the multiplier's field, both left to the consumer.

from finite_exact.closed_interval import ComplexIQ
from finite_exact.rat_q import Q

comptime MULTIPLIER_REJECTED = -1
comptime MULTIPLIER_ATTRACTING = 0
comptime MULTIPLIER_INDIFFERENT = 1
comptime MULTIPLIER_REPELLING = 2
comptime MULTIPLIER_UNDECIDED = 3


def multiplier_regime(lam: ComplexIQ) -> Int:
    """Attracting, indifferent or repelling for every multiplier in `lam`, or not decided."""
    if not lam.accepted():
        return MULTIPLIER_REJECTED
    var quadrance = lam.quadrance()
    if not quadrance.accepted():
        return MULTIPLIER_REJECTED
    var one = Q(1, 1)
    if quadrance.hi.lt(one):
        return MULTIPLIER_ATTRACTING
    if one.lt(quadrance.lo):
        return MULTIPLIER_REPELLING
    if quadrance.lo.eq(one) and quadrance.hi.eq(one):
        return MULTIPLIER_INDIFFERENT
    return MULTIPLIER_UNDECIDED
