# krawczyk_moore.mojo
#
# The Krawczyk-Moore existence and uniqueness test: R. E. Moore, "A Test for
# Existence of Solutions to Nonlinear Systems", SIAM Journal on Numerical
# Analysis 14 (1977), 611-615, for the operator of R. Krawczyk, Computing 4
# (1969), 187-201; in the form with an arbitrary point preconditioner,
# A. Neumaier, "Interval Methods for Systems of Equations", Cambridge
# University Press (1990), chapter 5.
#
# Specification: docs/root-isolation-spec.md, sections 3-4. This module
# Arithmetic: docs/rational-interval-arithmetic-spec.md, sections 2.3-2.4
# (enclosures over `closed_q`; the strict-inclusion hypothesis of 2.4).
# decides the hypothesis -- `K(X)` in the interior of `X` -- and never states
# the conclusion (exactly one zero in `X`, simple). The theorem is the
# consumer's import (`KrawczykMooreUniqueness`).

from finite_exact.closed_interval import ComplexIQ, IQBoolResult


def strictly_inside(image: ComplexIQ, x: ComplexIQ) -> IQBoolResult:
    """The isolation test: `image` in the interior of `x`, real and imaginary.

    Rejected when either box is, so a consumer can keep arithmetic rejection
    apart from a valid non-contraction. The Krawczyk-Moore hypothesis, not its
    conclusion (spec section 4).
    """
    if not (image.accepted() and x.accepted()):
        return IQBoolResult(False, True)
    return image.strict_subset_of(x)
