"""Truncated jets and Taylor models over a CoefficientRing.

Pinned specimens are shared with tests/finite_polynomial/test_truncated_jet_reference.py,
which recomputes them with reference/truncated_jet_reference.py and checks the
jets against untruncated polynomial composition. Run with
`pixi run test-truncated-jet`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.closed_q import ComplexIQ, IQ
from finite_exact.field import QField
from finite_exact.fp import Fp, FpField
from finite_exact.rat_q import Q, q_rejected
from finite_polynomial.coefficient_ring import ComplexBoxRing, CoefficientRing, FieldRing
from finite_polynomial.cyclotomic_field import CyclotomicRing
from finite_polynomial.cyclotomic_q import CyclotomicQ, cyclotomic_from_coeffs, zeta
from finite_polynomial.taylor_model import (
    enclosure_power,
    taylor_add,
    taylor_add_constant,
    taylor_mul,
    taylor_square,
    taylor_variable,
)
from finite_polynomial.truncated_jet import (
    TruncatedJet,
    jet_add,
    jet_constant,
    jet_convolve,
    jet_mul,
    jet_reciprocal,
    jet_scale,
    jet_seed,
    jet_sub,
    jet_vanishing_order,
)

comptime QRing = FieldRing[QField]


def orbit[R: CoefficientRing](ring: R, point: R.Element, c: R.Element, steps: Int, order: Int) -> TruncatedJet[R]:
    """The jet of `z -> z^2 + c` iterated `steps` times, at `point`."""
    var state = jet_seed(ring, point, order)
    for _ in range(steps):
        state = jet_add(jet_mul(state, state), jet_constant(ring, c, order))
    return state^


def residual[R: CoefficientRing](ring: R, point: R.Element, c: R.Element, preperiod: Int, period: Int, order: Int) -> TruncatedJet[R]:
    return jet_sub(orbit(ring, point, c, preperiod + period, order), orbit(ring, point, c, preperiod, order))


def box(re: Q, im: Q) -> ComplexIQ:
    return ComplexIQ.singleton(re, im)


def same_box(a: ComplexIQ, b: ComplexIQ) -> Bool:
    return ComplexBoxRing().identical(a, b)


def gaussian(re: Int64, im: Int64) -> CyclotomicQ:
    return cyclotomic_from_coeffs(4, [Q(re, 1), Q(im, 1)])


def test_q_jets_carry_every_derivative() raises:
    var ring = QRing()
    # (x^2)^2 at 1/3: value, derivative, half the second derivative.
    var state = orbit(ring, Q(1, 3), Q.zero(), 2, 2)
    assert_true(state.accepted())
    assert_true(state.coeffs[0].eq(Q(1, 81)))
    assert_true(state.coeffs[1].eq(Q(4, 27)))
    assert_true(state.coeffs[2].eq(Q(2, 3)))
    # c = -3/4 from -1/2, two steps: (-1/2, 1, 0, -2, 1), exactly the polynomial.
    var parabolic = orbit(ring, Q(-1, 2), Q(-3, 4), 2, 4)
    var expected: List[Q] = [Q(-1, 2), Q(1, 1), Q.zero(), Q(-2, 1), Q(1, 1)]
    for index in range(5):
        assert_true(parabolic.coeffs[index].eq(expected[index]))


def test_reciprocal_is_the_fibonacci_series() raises:
    var ring = QRing()
    var p = TruncatedJet[QRing](ring, [Q(1, 1), Q(-1, 1), Q(-1, 1), Q.zero(), Q.zero(), Q.zero(), Q.zero()])
    var r = jet_reciprocal(p)
    var fibonacci: List[Int64] = [1, 1, 2, 3, 5, 8, 13]
    for index in range(7):
        assert_true(r.coeffs[index].eq(Q(fibonacci[index], 1)))
    var one = jet_mul(p, r)
    assert_true(one.coeffs[0].eq(Q.one()))
    assert_equal(jet_vanishing_order(jet_sub(one, jet_constant(ring, Q.one(), 6))), -1)
    assert_true(jet_sub(one, jet_constant(ring, Q.one(), 6)).accepted())


def test_reciprocal_over_f13_and_q_zeta5() raises:
    var fp = FieldRing[FpField[13]]()
    var u = jet_seed(fp, Fp[13](5), 5)
    var back = jet_mul(u, jet_reciprocal(u))
    assert_equal(jet_vanishing_order(jet_sub(back, jet_constant(fp, fp.one(), 5))), -1)

    var cr = CyclotomicRing(5)
    var v = jet_seed(cr, zeta(5), 4)
    var w = jet_mul(v, jet_reciprocal(v))
    assert_true(w.accepted())
    assert_equal(jet_vanishing_order(jet_sub(w, jet_constant(cr, cr.one(), 4))), -1)


def test_refusals_are_sticky() raises:
    var ring = QRing()
    # A constant term that is not a unit.
    assert_false(jet_reciprocal(jet_seed(ring, Q.zero(), 3)).accepted())
    # Different orders.
    assert_false(jet_add(jet_seed(ring, Q.one(), 2), jet_seed(ring, Q.one(), 3)).accepted())
    assert_false(jet_mul(jet_seed(ring, Q.one(), 2), jet_seed(ring, Q.one(), 3)).accepted())
    # A rejected coefficient, and everything built on it.
    var bad = jet_seed(ring, q_rejected(), 2)
    assert_false(bad.accepted())
    assert_false(jet_convolve(bad, jet_seed(ring, Q.one(), 2)).accepted())
    assert_equal(jet_vanishing_order(bad), -1)
    assert_false(jet_seed(ring, Q.one(), -1).accepted())
    # An element of another cyclotomic field.
    var gauss = CyclotomicRing(4)
    assert_false(jet_scale(jet_seed(gauss, gauss.zero(), 2), zeta(3)).accepted())
    assert_false(jet_seed(gauss, zeta(3), 2).accepted())
    assert_false(jet_seed(CyclotomicRing(0), zeta(3), 2).accepted())
    # A rejected box.
    var boxes = ComplexBoxRing()
    assert_false(jet_seed(boxes, boxes.rejected(), 2).accepted())


def test_gaussian_jets_agree_over_q_zeta4_and_singleton_boxes() raises:
    # z^2 + i at 0, three steps, order 3: (-i, 0, -4 - 4i, 0).
    var gauss = CyclotomicRing(4)
    var exact = orbit(gauss, gauss.zero(), zeta(4), 3, 3)
    var boxes = ComplexBoxRing()
    var enclosed = orbit(boxes, boxes.zero(), box(Q.zero(), Q(1, 1)), 3, 3)
    var re: List[Int64] = [0, 0, -4, 0]
    var im: List[Int64] = [-1, 0, -4, 0]
    for index in range(4):
        assert_true(gauss.is_zero(gauss.sub(exact.coeffs[index], gaussian(re[index], im[index]))))
        assert_true(same_box(enclosed.coeffs[index], box(Q(re[index], 1), Q(im[index], 1))))


def test_multiplicities_of_the_quadratic_family() raises:
    # The specimens of finite-julia-set-research's jet_smoke, over both rings.
    var boxes = ComplexBoxRing()
    var gauss = CyclotomicRing(4)
    var zero_box = boxes.zero()
    var i_box = box(Q.zero(), Q(1, 1))
    assert_equal(jet_vanishing_order(residual(boxes, zero_box, zero_box, 1, 1, 6)), 2)
    assert_equal(jet_vanishing_order(residual(boxes, box(Q(1, 1), Q.zero()), zero_box, 0, 1, 6)), 1)
    assert_equal(jet_vanishing_order(residual(boxes, zero_box, i_box, 2, 2, 6)), 2)
    assert_equal(jet_vanishing_order(residual(gauss, gauss.zero(), zeta(4), 2, 2, 6)), 2)
    assert_equal(jet_vanishing_order(residual(boxes, box(Q(1, 2), Q.zero()), box(Q(1, 4), Q.zero()), 0, 1, 6)), 2)
    assert_equal(jet_vanishing_order(residual(boxes, box(Q(-1, 2), Q.zero()), box(Q(-3, 4), Q.zero()), 0, 2, 6)), 3)
    var c_q4 = cyclotomic_from_coeffs(4, [Q(1, 4), Q(1, 2)])
    var z_q4 = cyclotomic_from_coeffs(4, [Q.zero(), Q(1, 2)])
    assert_equal(jet_vanishing_order(residual(gauss, z_q4, c_q4, 0, 4, 9)), 5)
    # Order one is too low to see a double root, and says nothing.
    assert_equal(jet_vanishing_order(residual(boxes, zero_box, i_box, 2, 2, 1)), -1)


def test_box_jets_enclose_point_jets() raises:
    var boxes = ComplexBoxRing()
    var c = box(Q(-1, 8), Q(1, 4))
    var point_box = ComplexIQ(IQ(Q(1, 4), Q(1, 3)), IQ(Q(-1, 5), Q(1, 7)))
    var wide = orbit(boxes, point_box, c, 3, 3)
    var points: List[ComplexIQ] = [box(Q(1, 4), Q(-1, 5)), box(Q(1, 3), Q(1, 7)), box(Q(2, 7), Q.zero())]
    for point in points:
        var narrow = orbit(boxes, point, c, 3, 3)
        for index in range(4):
            var inside = narrow.coeffs[index].subset_of(wide.coeffs[index])
            assert_true(inside.value and not inside.rejected)


def domain_of(radius: Q) -> ComplexIQ:
    return ComplexIQ(IQ(radius.neg(), radius), IQ(radius.neg(), radius))


def test_taylor_model_specimens() raises:
    var boxes = ComplexBoxRing()
    # z^2 from -1 at order 3: one step truncates nothing; remainder stays zero.
    var model = taylor_variable(box(Q(-1, 1), Q.zero()), domain_of(Q(1, 64)), 3)
    var once = taylor_add_constant(taylor_square(model), boxes.zero())
    var expected: List[Int64] = [1, -2, 1, 0]
    for index in range(4):
        assert_true(same_box(once.polynomial.coeffs[index], box(Q(expected[index], 1), Q.zero())))
    assert_true(boxes.is_zero(once.remainder))
    # z^2 + 1/4 + i/2 from i/2 (multiplier i), radius 1/32, order 3, three steps.
    var c = box(Q(1, 4), Q(1, 2))
    var state = taylor_variable(box(Q.zero(), Q(1, 2)), domain_of(Q(1, 32)), 3)
    for _ in range(3):
        state = taylor_add_constant(taylor_square(state), c)
    assert_true(same_box(state.polynomial.coeffs[1], box(Q.zero(), Q(-1, 1))))
    var remainder = ComplexIQ(
        IQ(Q(-8020741, 274877906944), Q(1002593, 34359738368)),
        IQ(Q(-387425, 34359738368), Q(897533, 34359738368)),
    )
    assert_true(same_box(state.remainder, remainder))


def test_taylor_square_is_the_product_with_itself() raises:
    var c = box(Q(1, 4), Q(1, 2))
    var squared = taylor_variable(box(Q.zero(), Q(1, 2)), domain_of(Q(1, 32)), 2)
    var multiplied = squared.copy()
    for _ in range(3):
        squared = taylor_add_constant(taylor_square(squared), c)
        multiplied = taylor_add_constant(taylor_mul(multiplied, multiplied), c)
    assert_true(same_box(squared.remainder, multiplied.remainder))
    for index in range(3):
        assert_true(same_box(squared.polynomial.coeffs[index], multiplied.polynomial.coeffs[index]))


def test_taylor_enclosure_contains_the_orbit() raises:
    var c = box(Q(-1, 8), Q(1, 8))
    var centre = box(Q(1, 5), Q(-1, 7))
    var domain = domain_of(Q(1, 50))
    var state = taylor_variable(centre, domain, 2)
    var corners: List[ComplexIQ] = [
        box(Q(1, 5), Q(-1, 7)),
        box(Q(1, 5).add(Q(1, 50)), Q(-1, 7).sub(Q(1, 50))),
        box(Q(1, 5).sub(Q(1, 50)), Q(-1, 7).add(Q(1, 50))),
    ]
    for _ in range(5):
        state = taylor_add_constant(taylor_square(state), c)
        for index in range(len(corners)):
            corners[index] = corners[index].square().add(c)
            var inside = corners[index].subset_of(state.enclosure())
            assert_true(inside.value and not inside.rejected)


def test_taylor_refusals() raises:
    var boxes = ComplexBoxRing()
    var left = taylor_variable(boxes.zero(), domain_of(Q(1, 8)), 2)
    var other_domain = taylor_variable(boxes.zero(), domain_of(Q(1, 4)), 2)
    var other_order = taylor_variable(boxes.zero(), domain_of(Q(1, 8)), 3)
    assert_false(taylor_mul(left, other_domain).accepted())
    assert_false(taylor_add(left, other_order).accepted())
    assert_true(taylor_add(left, left).accepted())
    var refused = taylor_add_constant(left, boxes.rejected())
    assert_false(refused.accepted())
    assert_false(taylor_square(refused).accepted())
    assert_false(boxes.accepted(refused.enclosure()))
    assert_false(boxes.accepted(enclosure_power(domain_of(Q(1, 8)), -1)))
    # The sharp square: a box straddling both axes has a strictly narrower
    # square than product.
    var straddling = domain_of(Q(1, 8))
    var sharp = enclosure_power(straddling, 2)
    var loose = straddling.mul(straddling)
    assert_true(sharp.subset_of(loose).value)
    assert_false(loose.subset_of(sharp).value)


def main() raises:
    test_q_jets_carry_every_derivative()
    print("[PASS] test_q_jets_carry_every_derivative")
    test_reciprocal_is_the_fibonacci_series()
    print("[PASS] test_reciprocal_is_the_fibonacci_series")
    test_reciprocal_over_f13_and_q_zeta5()
    print("[PASS] test_reciprocal_over_f13_and_q_zeta5")
    test_refusals_are_sticky()
    print("[PASS] test_refusals_are_sticky")
    test_gaussian_jets_agree_over_q_zeta4_and_singleton_boxes()
    print("[PASS] test_gaussian_jets_agree_over_q_zeta4_and_singleton_boxes")
    test_multiplicities_of_the_quadratic_family()
    print("[PASS] test_multiplicities_of_the_quadratic_family")
    test_box_jets_enclose_point_jets()
    print("[PASS] test_box_jets_enclose_point_jets")
    test_taylor_model_specimens()
    print("[PASS] test_taylor_model_specimens")
    test_taylor_square_is_the_product_with_itself()
    print("[PASS] test_taylor_square_is_the_product_with_itself")
    test_taylor_enclosure_contains_the_orbit()
    print("[PASS] test_taylor_enclosure_contains_the_orbit")
    test_taylor_refusals()
    print("[PASS] test_taylor_refusals")
    print("11 truncated-jet and Taylor-model tests passed.")
