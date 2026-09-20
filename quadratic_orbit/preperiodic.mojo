# preperiodic.mojo
#
# Specification: docs/rational-interval-arithmetic-spec.md, sections 2.3-2.4.
#
# The seeded orbit's preperiodic points, as certificates on boxes.
#
#     R^c_{l,k}(z) = f_c^{l+k}(z) - f_c^l(z)
#
# A root of `R^c_{l,k}` is a point whose orbit repeats after `l` steps with
# period dividing `k`. This module never forms that polynomial's coefficients.
# It evaluates it, and its derivative, along the orbit -- the derivative by the
# chain rule, `d/dz f^n(z) = prod_{j<n} 2 f^j(z)` -- so nothing here depends on
# a coefficient list, a degree, or a squarefree decomposition. What the
# parameter plane gets from `sqfree` is a simple root; what this gets is a
# derivative enclosure that misses zero, checked directly.
#
# Two certificates, and they ask opposite things of inclusion:
#
#   exclusion   `0` is not in `R(Z)`      => no such point in `Z`
#   uniqueness  `K(Z)` strictly inside `Z` => exactly one, counted simply
#
# The strictness in the second is not decoration. It is the contraction
# hypothesis of the Krawczyk-Moore theorem (specification section 2.4), which
# is an import and is gated by the consumer. Compare the trap certificate of
# `larsbx/finite-julia-set-research`, which asks only for inclusion because it
# claims only boundedness.

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult
from finite_exact.rat_q import Q
from quadratic_orbit.orbit import complex_excludes_zero, orbit_term, quadratic_step


def one_box() -> ComplexIQ:
    """The multiplicative identity, as a singleton enclosure."""
    return ComplexIQ.singleton(Q(1, 1), Q.zero())


def rejected_box() -> ComplexIQ:
    """A refusal that is a value: every consumer sees `accepted() == False`."""
    return ComplexIQ.singleton(Q(1, 0), Q(1, 0))


def orbit_derivative(seed: ComplexIQ, c: ComplexIQ, steps: Int) -> ComplexIQ:
    """`d/dz f_c^steps(z)` on the enclosure: `prod_{j < steps} 2 f_c^j(z)`.

    Zero steps is the identity map, whose derivative is `1`. A negative count
    is refused rather than read as zero.
    """
    if steps < 0 or not (seed.accepted() and c.accepted()):
        return rejected_box()
    var product = one_box()
    var z = seed.copy()
    var two = ComplexIQ.singleton(Q(2, 1), Q.zero())
    for _ in range(steps):
        product = product.mul(two.mul(z))
        z = quadratic_step(z, c)
    return product.copy()


def preperiodic_residual(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> ComplexIQ:
    """`R^c_{l,k}(z) = f^{l+k}(z) - f^l(z)`, on the enclosure."""
    if l < 0 or k < 1 or not (z.accepted() and c.accepted()):
        return rejected_box()
    return orbit_term(z, c, l + k).sub(orbit_term(z, c, l))


def preperiodic_residual_derivative(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> ComplexIQ:
    """`R'` by the chain rule, with no coefficients formed."""
    if l < 0 or k < 1 or not (z.accepted() and c.accepted()):
        return rejected_box()
    return orbit_derivative(z, c, l + k).sub(orbit_derivative(z, c, l))


def excludes_preperiodic_point(z: ComplexIQ, c: ComplexIQ, l: Int, k: Int) -> IQBoolResult:
    """Does `Z` provably contain no point of preperiod `l` and period `k`?

    True is a proof about every point of the box. False is a statement about
    the enclosure and never about the points: it means the image met the
    origin, which a wider enclosure can do without any root existing.
    """
    return complex_excludes_zero(preperiodic_residual(z, c, l, k))


def midpoint_box(z: ComplexIQ) -> ComplexIQ:
    """The singleton at the centre of a box, exactly."""
    if not z.accepted():
        return rejected_box()
    var two = Q(2, 1)
    return ComplexIQ.singleton(z.re.lo.add(z.re.hi).div(two), z.im.lo.add(z.im.hi).div(two))


def singleton_reciprocal(w: ComplexIQ) -> ComplexIQ:
    """`1/w` for a singleton `w`, exactly, or a refusal.

    The exact regime spends no width here. The Krawczyk operator is usually
    written with an *approximate* inverse of the derivative at the centre,
    because in floating point there is no other kind; over `Q(i)` the inverse
    of a singleton is another singleton, `(a - bi) / (a^2 + b^2)`, and the
    operator inherits no error from it. A vanishing quadrance is refused.
    """
    if not w.accepted():
        return rejected_box()
    if not (w.re.lo.eq(w.re.hi) and w.im.lo.eq(w.im.hi)):
        return rejected_box()
    var a = w.re.lo.copy()
    var b = w.im.lo.copy()
    var quadrance = a.square().add(b.square())
    if quadrance.eq(Q.zero()) or not quadrance.accepted():
        return rejected_box()
    return ComplexIQ.singleton(a.div(quadrance), b.neg().div(quadrance))


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


def preperiodic_smoke() -> Bool:
    """The two certificates at `c = 0`, where the answers are known by hand."""
    var c = ComplexIQ.singleton(Q.zero(), Q.zero())
    # R^0_{0,1}(z) = z^2 - z, with simple roots 0 and 1.
    var around_one = ComplexIQ(IQ(Q(7, 8), Q(9, 8)), IQ(Q(-1, 8), Q(1, 8)))
    if not isolates_preperiodic_point(around_one, c, 0, 1):
        return False
    # Far from both roots the residual misses the origin outright.
    var far = ComplexIQ(IQ(Q(15, 8), Q(17, 8)), IQ(Q(-1, 8), Q(1, 8)))
    var excluded = excludes_preperiodic_point(far, c, 0, 1)
    if not (excluded.value and not excluded.rejected):
        return False
    # At the critical point of the residual the inverse does not exist, and
    # the refusal is a value rather than an abort.
    var at_half = ComplexIQ(IQ(Q(3, 8), Q(5, 8)), IQ(Q(-1, 8), Q(1, 8)))
    if isolates_preperiodic_point(at_half, c, 0, 1):
        return False
    if krawczyk_image(at_half, c, 0, 1).accepted():
        return False
    # The derivative of the identity is one, and a negative count is refused.
    if not orbit_derivative(around_one, c, 0).re.lo.eq(Q(1, 1)):
        return False
    if orbit_derivative(around_one, c, -1).accepted():
        return False
    # Refinement is what the wrapping effect costs. At `(l, k) = (1, 1)` the
    # residual is `z^4 - z^2`, whose derivative enclosure over the same box is
    # far wider, and the contraction is lost -- a fact about the enclosure,
    # not about the point, and the narrower box recovers it.
    if isolates_preperiodic_point(around_one, c, 1, 1):
        return False
    var narrow = ComplexIQ(IQ(Q(63, 64), Q(65, 64)), IQ(Q(-1, 64), Q(1, 64)))
    return isolates_preperiodic_point(narrow, c, 1, 1)
