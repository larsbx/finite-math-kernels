# krawczyk_operator.mojo
#
# Specification: docs/rational-interval-arithmetic-spec.md, section 2.4;
# docs/root-isolation-spec.md, sections 2-4.
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
# This is the z^2 + c application: the generic, map-agnostic operator and test
# are `root_isolation.krawczyk` and `root_isolation.krawczyk_moore`; this
# module supplies the residual, its chain-rule derivative and the exact
# preconditioner. Previously in preperiodic.mojo, which re-exports both names.
# The theorem is an import, and the consumer names and gates it: this module
# returns the hypothesis, not the conclusion.

from finite_exact.closed_interval import ComplexIQ
from quadratic_orbit.preperiodic import preperiodic_residual, preperiodic_residual_derivative
from root_isolation import centre, exact_inverse, rejected_box, strictly_inside
from root_isolation import krawczyk_image as krawczyk_operator


def krawczyk_image(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> ComplexIQ:
    """`K(Z) = m - Y R(m) + (1 - Y R'(Z))(Z - m)`, with `Y = 1/R'(m)`.

    The operator of docs/root-isolation-spec.md section 2, with the residual
    and its derivative as the enclosures; a refused `Y` refuses the image.
    """
    var m = centre(z)
    var y = exact_inverse(preperiodic_residual_derivative(m, c, l, k))
    if not y.accepted():
        return rejected_box()
    return krawczyk_operator(z, m, y, preperiodic_residual(m, c, l, k), preperiodic_residual_derivative(z, c, l, k))


def isolates_preperiodic_point(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> Bool:
    """Does `Z` contain exactly one point of preperiod `l` and period `k`?

    The hypothesis of the Krawczyk-Moore theorem, checked exactly: strict
    inclusion of `K(Z)` in `Z` (docs/root-isolation-spec.md sections 3-4).
    The theorem itself is an import, and the consumer is responsible for
    naming and gating it -- this returns the hypothesis, not the conclusion.
    """
    if l < 0 or k < 1 or not (z.accepted() and c.accepted()):
        return False
    var inside = strictly_inside(krawczyk_image(z, c, l, k), z)
    return inside.value and not inside.rejected
