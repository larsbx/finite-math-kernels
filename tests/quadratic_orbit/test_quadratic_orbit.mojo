"""Executable laws for the quadratic_orbit package.

Run with `pixi run test-quadratic-orbit`
(`mojo run -I . tests/quadratic_orbit/test_quadratic_orbit.mojo`).

The orbit is checked against hand-computed exact terms in both seedings that
consumers use, and the collision partition is checked to be a partition.
"""

from finite_exact.closed_interval import ComplexIQ, IQ
from finite_exact.rat_q import Q
from quadratic_orbit.collision import forbidden_count, intended_count, intended_pair, pair_count
from quadratic_orbit.orbit import (
    collision_interval,
    complex_excludes_zero,
    critical_orbit_term,
    orbit_term,
    quadratic_step,
    separated_terms,
    zero_box,
)


def point(re_num: Int64, re_den: Int64, im_num: Int64, im_den: Int64) -> ComplexIQ:
    return ComplexIQ.singleton(Q(re_num, re_den), Q(im_num, im_den))


def same_point(z: ComplexIQ, re_num: Int64, re_den: Int64, im_num: Int64, im_den: Int64) -> Bool:
    if not z.accepted():
        return False
    return (
        z.re.lo.eq(Q(re_num, re_den)) and z.re.hi.eq(Q(re_num, re_den)) and
        z.im.lo.eq(Q(im_num, im_den)) and z.im.hi.eq(Q(im_num, im_den))
    )


def test_seed_is_the_zeroth_term() -> Bool:
    """No steps means no map applied, at any seed."""
    var seed = point(3, 7, -2, 5)
    var c = point(-1, 1, 0, 1)
    return same_point(orbit_term(seed, c, 0), 3, 7, -2, 5) and same_point(critical_orbit_term(c, 0), 0, 1, 0, 1)


def test_critical_orbit_of_c_minus_two() -> Bool:
    """0 -> -2 -> 2 -> 2: the worked antenna-tip orbit, exactly."""
    var c = point(-2, 1, 0, 1)
    return (
        same_point(critical_orbit_term(c, 1), -2, 1, 0, 1) and
        same_point(critical_orbit_term(c, 2), 2, 1, 0, 1) and
        same_point(critical_orbit_term(c, 3), 2, 1, 0, 1)
    )


def test_critical_orbit_of_c_equals_i() -> Bool:
    """0 -> i -> -1 + i -> -i -> -1 + i: preperiod 2, period 2."""
    var c = point(0, 1, 1, 1)
    return (
        same_point(critical_orbit_term(c, 1), 0, 1, 1, 1) and
        same_point(critical_orbit_term(c, 2), -1, 1, 1, 1) and
        same_point(critical_orbit_term(c, 3), 0, 1, -1, 1) and
        same_point(critical_orbit_term(c, 4), -1, 1, 1, 1)
    )


def test_orbit_term_agrees_with_stepping() -> Bool:
    """Recomputation from the seed is the same orbit as stepping forward."""
    var seed = point(1, 3, 1, 4)
    var c = point(-1, 2, 1, 5)
    var z = seed.copy()
    for n in range(6):
        var direct = orbit_term(seed, c, n)
        if not (direct.accepted() and z.accepted()):
            return False
        if not (direct.re.lo.eq(z.re.lo) and direct.im.lo.eq(z.im.lo)):
            return False
        z = quadratic_step(z, c)
    return True


def test_a_seeded_orbit_is_not_the_critical_orbit() -> Bool:
    """The seed is an argument: a different seed gives a different orbit."""
    var c = point(-1, 1, 0, 1)
    var shifted = orbit_term(point(1, 1, 0, 1), c, 1)
    return same_point(shifted, 0, 1, 0, 1) and same_point(critical_orbit_term(c, 1), -1, 1, 0, 1)


def test_collision_interval_and_zero_exclusion() -> Bool:
    """Separated terms exclude zero; a term against itself cannot."""
    var c = point(-2, 1, 0, 1)
    var a = critical_orbit_term(c, 1)
    var b = critical_orbit_term(c, 2)
    var apart = complex_excludes_zero(collision_interval(a, b))
    var same = complex_excludes_zero(collision_interval(b, b))
    var wide = ComplexIQ(IQ(Q(-1, 1), Q(1, 1)), IQ(Q(-1, 1), Q(1, 1)))
    return (
        apart.value and not apart.rejected and
        not same.value and not same.rejected and
        not complex_excludes_zero(wide).value
    )


def test_separated_terms_is_three_valued() -> Bool:
    var c = point(-2, 1, 0, 1)
    var negative_index = separated_terms(zero_box(), c, -1, 2)
    var separated = separated_terms(zero_box(), c, 1, 2)
    var equal_terms = separated_terms(zero_box(), c, 2, 3)
    return (
        negative_index.rejected and
        separated.value and not separated.rejected and
        not equal_terms.value and not equal_terms.rejected
    )


def test_intended_and_forbidden_partition_the_pairs() -> Bool:
    """Every pair below the horizon is intended or forbidden, never both."""
    var horizon = 6
    var ok = True
    for ell in range(1, 4):
        for period in range(1, 4):
            if intended_count(ell, period, horizon) + forbidden_count(ell, period, horizon) != pair_count(horizon):
                ok = False
    return ok


def test_an_invalid_type_intends_nothing() -> Bool:
    """A caller that forgot to validate gets an empty intended set."""
    return (
        not intended_pair(0, 1, 2, 3) and
        not intended_pair(1, 0, 2, 3) and
        not intended_pair(-1, 2, 2, 4) and
        intended_count(0, 1, 5) == 0 and
        forbidden_count(0, 1, 5) == pair_count(5)
    )


def test_intended_pairs_are_the_preperiodic_ones() -> Bool:
    """Type (2, 2): indices from 2 on, congruent modulo 2."""
    return (
        intended_pair(2, 2, 2, 4) and
        intended_pair(2, 2, 3, 5) and
        not intended_pair(2, 2, 2, 3) and
        not intended_pair(2, 2, 1, 3)
    )


def main() raises:
    if not test_seed_is_the_zeroth_term():
        raise Error("orbit_term at zero steps is not the seed")
    if not test_critical_orbit_of_c_minus_two():
        raise Error("critical orbit of c = -2 is wrong")
    if not test_critical_orbit_of_c_equals_i():
        raise Error("critical orbit of c = i is wrong")
    if not test_orbit_term_agrees_with_stepping():
        raise Error("recomputed orbit disagrees with stepping")
    if not test_a_seeded_orbit_is_not_the_critical_orbit():
        raise Error("the seed is being ignored")
    if not test_collision_interval_and_zero_exclusion():
        raise Error("collision interval or zero exclusion is wrong")
    if not test_separated_terms_is_three_valued():
        raise Error("separated_terms is not three-valued")
    if not test_intended_and_forbidden_partition_the_pairs():
        raise Error("intended and forbidden do not partition the pairs")
    if not test_an_invalid_type_intends_nothing():
        raise Error("an invalid orbit type intends something")
    if not test_intended_pairs_are_the_preperiodic_ones():
        raise Error("the intended pairs of type (2, 2) are wrong")
    print("quadratic_orbit laws passed.")
