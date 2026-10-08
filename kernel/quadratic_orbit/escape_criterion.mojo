# escape_criterion.mojo
#
# The escape criterion of the quadratic family `z -> z^2 + c`: an orbit that
# reaches `|z| > max(2, |c|)` tends to infinity. Standard references:
# L. Carleson and T. W. Gamelin, Complex Dynamics (Springer Universitext,
# 1993), chapter VIII on the quadratic family; J. Milnor, Dynamics in One
# Complex Variable, 3rd ed. (Annals of Mathematics Studies 160, Princeton,
# 2006), on the filled Julia set of a polynomial.
#
# Specification: docs/rational-interval-arithmetic-spec.md.
# The quadrance form and the growth certificate are derived, without the
# modulus, in larsbx/finite-julia-set-research:docs/escape-criterion.md,
# where this module was written.
#
# Here the criterion is stated in quadrances, `t = N(z)` and `m = N(c)`, so no
# modulus and no square root is taken:
#
#   test         `t > max(4, m)`, strictly, on the lower end of the box's
#                quadrance and the upper end of the parameter's.
#   certificate  a rational ratio `r > 1` with `m <= t`, `t > 1 + r` and
#                `T(t, r) > 0`, which gives `N(f(z)) >= r t` at every later
#                step. Its admissible ratios are `1 < r < (sqrt(t) - 1)^2`,
#                nonempty exactly when `t > 4`.
#
# Every quadrance the test passes carries a certificate. The converse fails
# only on the tie `t = m > 4`, which the test leaves undecided: the test is
# the conservative one, and it is the one the consumers' verdicts were
# recorded with.
#
# Fail-closed: a rejected or negative quadrance makes the bound rejected, a
# rejected bound passes nothing, and the test returns false on any refusal.
# False is never a claim that the orbit is bounded.

from finite_exact.closed_interval import ComplexIQ
from finite_exact.rat_q import Q, q_max, q_rejected


def escape_bound(parameter_quadrance: Q) -> Q:
    """`max(4, m)`, the quadrance past which an orbit at `N(c) = m` escapes."""
    if not parameter_quadrance.accepted() or parameter_quadrance.lt(Q.zero()):
        return q_rejected()
    return q_max(Q(4, 1), parameter_quadrance)


def escape_bound_quadrance(c: ComplexIQ) -> Q:
    """`max(4, N(c))`, with the largest quadrance the parameter box allows."""
    if not c.accepted():
        return q_rejected()
    return escape_bound(c.quadrance().hi)


def quadrance_escapes(t: Q, m: Q) -> Bool:
    """`t > max(4, m)`: is a point of quadrance `t` past the bound at `N(c) = m`?"""
    var bound = escape_bound(m)
    return t.accepted() and bound.accepted() and bound.lt(t)


def escapes(z: ComplexIQ, c: ComplexIQ) -> Bool:
    """Is every point of the box past the escape bound of every parameter in `c`?

    The test reads the lower end of the box's quadrance, so a box that merely
    reaches past the bound, or touches it, does not qualify.
    """
    if not (z.accepted() and c.accepted()):
        return False
    return quadrance_escapes(z.quadrance().lo, c.quadrance().hi)


def threshold_form(t: Q, ratio: Q) -> Q:
    """`T(t, r) = t^2 - 2t(1 + r) + (r - 1)^2`.

    Its roots in `t` are `(sqrt(r) ± 1)^2`, so a positive value alone does not
    say which side of the parabola `t` is on. `certificate_holds` adds the
    vertex condition that picks the upper one.
    """
    var one = Q(1, 1)
    var two = Q(2, 1)
    return t.square().sub(two.mul(t).mul(one.add(ratio))).add(ratio.sub(one).square())


def growth_form(t: Q, m: Q, ratio: Q) -> Q:
    """`G(t, m, r) = (t^2 + m - r t)^2 - 4 t^2 m`, as a quadratic in `m`."""
    var two = Q(2, 1)
    var linear = two.mul(t).mul(t.add(ratio)).mul(m)
    return m.square().sub(linear).add(t.square().mul(t.sub(ratio).square()))


def certificate_holds(t: Q, m: Q, ratio: Q) -> Bool:
    """Does `ratio` certify that the quadrance grows by that factor at every step?

    Four exact comparisons: the ratio exceeds one, the parameter quadrance
    does not exceed the point's, the point is past the vertex, and the
    threshold form is positive there. A rejected value refuses rather than
    answering.
    """
    if not (t.accepted() and m.accepted() and ratio.accepted()):
        return False
    var zero = Q.zero()
    var one = Q(1, 1)
    if not one.lt(ratio):
        return False
    if not (zero.le(m) and m.le(t)):
        return False
    if not one.add(ratio).lt(t):
        return False
    return zero.lt(threshold_form(t, ratio))


def next_quadrance_bound(t: Q, ratio: Q) -> Q:
    """The certified lower bound on the next quadrance, `r t`."""
    return ratio.mul(t)


def escape_certificate_smoke() -> Bool:
    """The identities, the branch trap, and the threshold, on pinned values."""
    var t = Q(9, 1)
    var m = Q(4, 1)
    # G(t, t, r) = t^2 T(t, r): the worst parameter is m = t.
    if not growth_form(t, t, Q(2, 1)).eq(t.square().mul(threshold_form(t, Q(2, 1)))):
        return False
    # T vanishes at (sqrt(r) + 1)^2; for r = 4 that is t = 9.
    if not threshold_form(Q(9, 1), Q(4, 1)).eq(Q.zero()):
        return False
    if not certificate_holds(t, m, Q(2, 1)):
        return False
    if not next_quadrance_bound(t, Q(2, 1)).eq(Q(18, 1)):
        return False
    # The lower branch: T > 0 and the claim false. Vertex condition rejects it.
    var trap_t = Q(163, 31)
    var trap_m = Q(98, 19)
    var trap_ratio = Q(263, 19)
    if not Q.zero().lt(threshold_form(trap_t, trap_ratio)):
        return False
    if certificate_holds(trap_t, trap_m, trap_ratio):
        return False
    # At the classical threshold the admissible ratios are empty.
    if certificate_holds(Q(4, 1), Q(4, 1), Q(1, 1)):
        return False
    return not certificate_holds(Q(4, 1), Q(4, 1), Q(3, 2))
