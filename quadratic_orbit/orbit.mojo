# orbit.mojo
#
# The seeded quadratic orbit over complex rational interval boxes.
# Specification: docs/rational-interval-arithmetic-spec.md.

from finite_exact.closed_interval import ComplexIQ, IQBoolResult
from finite_exact.rat_q import Q


def zero_box() -> ComplexIQ:
    """The singleton box at the critical point of `z^2 + c`."""
    return ComplexIQ.singleton(Q.zero(), Q.zero())


def quadratic_step(z: ComplexIQ, c: ComplexIQ) -> ComplexIQ:
    """`z^2 + c`, with `z` and `c` enclosures rather than points."""
    return z.square().add(c)


def orbit_term(seed: ComplexIQ, c: ComplexIQ, steps: Int) -> ComplexIQ:
    """The `steps`-th term of the orbit of `seed` under `z^2 + c`.

    Terms are recomputed from the seed rather than stored, which keeps the
    kernel allocation-free. A negative step count returns the seed: there is
    no backward orbit here, and inventing one would be a different map.
    """
    var z = seed.copy()
    for _ in range(steps):
        z = quadratic_step(z, c)
    return z.copy()


def critical_orbit_term(c: ComplexIQ, steps: Int) -> ComplexIQ:
    """`orbit_term` seeded at the critical point: the parameter plane's case."""
    return orbit_term(zero_box(), c, steps)


def collision_interval(a: ComplexIQ, b: ComplexIQ) -> ComplexIQ:
    """`b - a`, the box a collision between two orbit terms would have to meet."""
    return b.sub(a)


def complex_excludes_zero(z: ComplexIQ) -> IQBoolResult:
    """Does the box miss the origin in at least one coordinate?

    Three-valued and fail-closed: a rejected coordinate returns rejected, and
    a box that contains the origin in both coordinates returns false rather
    than unknown-as-true.
    """
    if not z.accepted():
        return IQBoolResult(False, True)
    var re_result = z.re.excludes_zero()
    var im_result = z.im.excludes_zero()
    if re_result.rejected or im_result.rejected:
        return IQBoolResult(False, True)
    return IQBoolResult(re_result.value or im_result.value, False)


def separated_terms(seed: ComplexIQ, c: ComplexIQ, i: Int, j: Int) -> IQBoolResult:
    """Do terms `i` and `j` of the orbit provably differ?

    This is a fact about the enclosures, not about the orbit of any point in
    them: false means the boxes overlap in both coordinates, never that the
    terms are equal.
    """
    if i < 0 or j < 0:
        return IQBoolResult(False, True)
    var a = orbit_term(seed, c, i)
    var b = orbit_term(seed, c, j)
    return complex_excludes_zero(collision_interval(a, b))
