"""Executable laws for `quadratic_orbit.escape_criterion` and `quadratic_orbit.multiplier_classification`.

Run with `pixi run test-quadratic-orbit`. The escape test, the growth
certificate behind it, and the multiplier trichotomy are checked on values
where the answer is known by hand, and every refusal is checked to be a value
that decides nothing. `tests/quadratic_orbit/test_escape_criterion_oracle.py` replays a
transcript of the same functions against an independent Python computation.
"""

from finite_exact.closed_interval import ComplexIQ, IQ, complex_box, gaussian_singleton
from finite_exact.rat_q import Q, q_rejected
from quadratic_orbit.escape_criterion import (
    certificate_holds,
    escape_bound,
    escape_bound_quadrance,
    escape_certificate_smoke,
    escapes,
    growth_form,
    next_quadrance_bound,
    quadrance_escapes,
    threshold_form,
)
from quadratic_orbit.multiplier_classification import (
    MULTIPLIER_ATTRACTING,
    MULTIPLIER_INDIFFERENT,
    MULTIPLIER_REJECTED,
    MULTIPLIER_REPELLING,
    MULTIPLIER_UNDECIDED,
    multiplier_regime,
)
from quadratic_orbit.orbit import critical_orbit_term
from quadratic_orbit import MULTIPLIER_REPELLING as FACADE_REPELLING, escapes as facade_escapes, multiplier_regime as facade_regime


def rejected_box() -> ComplexIQ:
    return ComplexIQ.singleton(q_rejected(), q_rejected())


def test_the_bound_is_max_four_and_the_parameter_quadrance() -> Bool:
    return (
        escape_bound_quadrance(gaussian_singleton(0, 1, 0, 1)).eq(Q(4, 1)) and
        escape_bound_quadrance(gaussian_singleton(1, 4, 0, 1)).eq(Q(4, 1)) and
        escape_bound_quadrance(gaussian_singleton(3, 1, 4, 1)).eq(Q(25, 1)) and
        # A parameter box contributes the largest quadrance it allows.
        escape_bound_quadrance(complex_box(-3, 1, 0, 0, 1)).eq(Q(9, 1)) and
        escape_bound(Q(5, 1)).eq(Q(5, 1)) and escape_bound(Q(1, 2)).eq(Q(4, 1))
    )


def test_a_refused_bound_is_rejected_and_not_zero() -> Bool:
    """The old consumer copies answered an accepted zero for a rejected
    parameter, and a zero bound certifies escape for every box off the
    origin. The bound is now rejected, and nothing escapes past it."""
    var z = gaussian_singleton(5, 1, 0, 1)
    return (
        not escape_bound_quadrance(rejected_box()).accepted() and
        not escape_bound(q_rejected()).accepted() and
        not escape_bound(Q(-1, 1)).accepted() and
        not escapes(z, rejected_box()) and
        not escapes(rejected_box(), gaussian_singleton(0, 1, 0, 1)) and
        not quadrance_escapes(Q(25, 1), q_rejected()) and
        not quadrance_escapes(q_rejected(), Q(1, 1)) and
        not quadrance_escapes(Q(25, 1), Q(-1, 1))
    )


def test_the_test_is_strict_and_reads_the_lower_quadrance() -> Bool:
    var c = gaussian_singleton(1, 1, 0, 1)
    # On the bound is not past it: c = -2 has the bounded orbit 0, -2, 2, 2.
    var tip = gaussian_singleton(-2, 1, 0, 1)
    return (
        not escapes(gaussian_singleton(2, 1, 0, 1), c) and
        escapes(gaussian_singleton(5, 1, 0, 1), c) and
        not escapes(critical_orbit_term(tip, 2), tip) and
        not escapes(critical_orbit_term(tip, 3), tip) and
        # A box reaching past the bound in part does not escape as a whole.
        not escapes(complex_box(1, 3, 0, 0, 1), c) and
        escapes(complex_box(5, 6, 5, 6, 2), c) and
        # A box straddling the origin has quadrance lower end zero.
        not escapes(complex_box(-9, 9, -9, 9, 1), c)
    )


def test_the_certificate_forms() -> Bool:
    var t = Q(9, 1)
    var r = Q(2, 1)
    return (
        growth_form(t, t, r).eq(t.square().mul(threshold_form(t, r))) and
        threshold_form(Q(9, 1), Q(4, 1)).eq(Q.zero()) and
        certificate_holds(t, Q(4, 1), r) and
        next_quadrance_bound(t, r).eq(Q(18, 1)) and
        not certificate_holds(q_rejected(), Q(4, 1), r) and
        not certificate_holds(t, Q(-1, 1), r) and
        escape_certificate_smoke()
    )


def test_the_test_implies_a_certificate() -> Bool:
    """Every quadrance the test passes carries a ratio; the converse fails
    only on the tie `t = m > 4`, which the test leaves undecided."""
    var m = Q(5, 1)
    var r = Q(51, 50)
    return (
        quadrance_escapes(Q(26, 5), m) and certificate_holds(Q(26, 5), m, r) and
        not quadrance_escapes(Q(5, 1), m) and certificate_holds(Q(5, 1), m, r) and
        not quadrance_escapes(Q(4, 1), Q(1, 1)) and not certificate_holds(Q(4, 1), Q(1, 1), r)
    )


def test_the_multiplier_trichotomy_is_exact() -> Bool:
    return (
        multiplier_regime(gaussian_singleton(0, 1, 0, 1)) == MULTIPLIER_ATTRACTING and
        multiplier_regime(gaussian_singleton(1, 2, 1, 2)) == MULTIPLIER_ATTRACTING and
        multiplier_regime(gaussian_singleton(3, 5, 4, 5)) == MULTIPLIER_INDIFFERENT and
        multiplier_regime(gaussian_singleton(0, 1, -1, 1)) == MULTIPLIER_INDIFFERENT and
        multiplier_regime(gaussian_singleton(4, 1, 4, 1)) == MULTIPLIER_REPELLING and
        multiplier_regime(gaussian_singleton(1, 1, 1, 100)) == MULTIPLIER_REPELLING
    )


def test_a_box_decides_only_what_every_point_shares() -> Bool:
    """A box decides a regime only when every multiplier in it is in that
    regime. One that meets the unit quadrance decides nothing, and a
    refusal is neither attracting nor repelling."""
    return (
        multiplier_regime(complex_box(-1, 1, -1, 1, 4)) == MULTIPLIER_ATTRACTING and
        multiplier_regime(complex_box(5, 6, 0, 1, 4)) == MULTIPLIER_REPELLING and
        multiplier_regime(complex_box(3, 5, 0, 0, 4)) == MULTIPLIER_UNDECIDED and
        multiplier_regime(complex_box(4, 5, 0, 0, 4)) == MULTIPLIER_UNDECIDED and
        multiplier_regime(complex_box(3, 4, 0, 0, 4)) == MULTIPLIER_UNDECIDED and
        multiplier_regime(rejected_box()) == MULTIPLIER_REJECTED
    )


def test_the_package_facade_re_exports_the_named_modules() -> Bool:
    var c = gaussian_singleton(1, 1, 0, 1)
    var z = gaussian_singleton(5, 1, 0, 1)
    return facade_escapes(z, c) == escapes(z, c) and facade_regime(z) == FACADE_REPELLING


def main() raises:
    if not test_the_bound_is_max_four_and_the_parameter_quadrance():
        raise Error("the escape bound is not max(4, N(c))")
    if not test_a_refused_bound_is_rejected_and_not_zero():
        raise Error("a refused escape bound decided something")
    if not test_the_test_is_strict_and_reads_the_lower_quadrance():
        raise Error("the escape test is not strict on the lower quadrance")
    if not test_the_certificate_forms():
        raise Error("the escape certificate forms are wrong")
    if not test_the_test_implies_a_certificate():
        raise Error("the escape test and its certificate disagree")
    if not test_the_multiplier_trichotomy_is_exact():
        raise Error("the multiplier trichotomy is wrong on a point")
    if not test_a_box_decides_only_what_every_point_shares():
        raise Error("the multiplier trichotomy decided a box it must not")
    if not test_the_package_facade_re_exports_the_named_modules():
        raise Error("the quadratic_orbit facade does not re-export the named modules")
    print("quadratic_orbit escape and multiplier laws passed.")
