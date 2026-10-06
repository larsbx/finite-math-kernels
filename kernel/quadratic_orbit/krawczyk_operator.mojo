# krawczyk_operator.mojo
#
# Specification: docs/rational-interval-arithmetic-spec.md, section 2.4.
#
# The Krawczyk operator of the preperiodic residual R^c_{l,k}, over complex
# rational boxes, and the strict-inclusion test that is the hypothesis of the
# Krawczyk-Moore theorem:
#
#     K(Z) = m - Y R(m) + (1 - Y R'(Z)) (Z - m),   m the centre, Y = 1/R'(m);
#     K(Z) strictly inside Z  =>  Z holds exactly one zero of R, a simple one.
#
# References: R. Krawczyk, "Newton-Algorithmen zur Bestimmung von Nullstellen
# mit Fehlerschranken", Computing 4 (1969) 187-201 (the operator);
# R. E. Moore, "A test for existence of solutions to nonlinear systems",
# SIAM J. Numer. Anal. 14 (1977) 611-615 (existence and uniqueness under
# inclusion); A. Neumaier, *Interval Methods for Systems of Equations*
# (Cambridge, 1990), chapter 5.
#
# Previously in preperiodic.mojo, which builds the residual and its derivative
# and still re-exports both names. The theorem is an import, and the consumer
# names and gates it: this module returns the hypothesis, not the conclusion.

from finite_exact.closed_interval import ComplexIQ
from quadratic_orbit.preperiodic import (
    midpoint_box,
    one_box,
    preperiodic_residual,
    preperiodic_residual_derivative,
    rejected_box,
    singleton_reciprocal,
)


def krawczyk_image(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> ComplexIQ:
    """`K(Z) = m - Y R(m) + (1 - Y R'(Z))(Z - m)`, with `Y = 1/R'(m)`."""
    var m = midpoint_box(z)
    var y = singleton_reciprocal(preperiodic_residual_derivative(m, c, l, k))
    if not y.accepted():
        return rejected_box()
    var slope = one_box().sub(y.mul(preperiodic_residual_derivative(z, c, l, k)))
    return m.sub(y.mul(preperiodic_residual(m, c, l, k))).add(slope.mul(z.sub(m)))


def isolates_preperiodic_point(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> Bool:
    """Does `Z` contain exactly one point of preperiod `l` and period `k`?

    The hypothesis of the Krawczyk-Moore theorem, checked exactly: strict
    inclusion of `K(Z)` in `Z`. The theorem itself is an import, and the
    consumer is responsible for naming and gating it -- this returns the
    hypothesis, not the conclusion.
    """
    if l < 0 or k < 1 or not (z.accepted() and c.accepted()):
        return False
    var image = krawczyk_image(z, c, l, k)
    if not image.accepted():
        return False
    var inside = image.strict_subset_of(z)
    return inside.value and not inside.rejected
