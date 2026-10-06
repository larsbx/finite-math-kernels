"""reference/truncated_jet_reference.py and taylor_model_reference.py: the pinned specimens of
tests/finite_polynomial/test_truncated_jet.mojo, recomputed, and the jets
checked against untruncated composition and the cyclotomic reference's own
germ iterates and reciprocal series."""

from __future__ import annotations

import random
from fractions import Fraction as F

import pytest

import cyclotomic_reference as cyc
import taylor_model_reference as TM
import truncated_jet_reference as T
from closed_interval import ComplexIQ

Q, BOXES = T.FRACTIONS, T.BOXES


def orbit(ring, point, c, steps, order):
    state = T.seed(ring, point, order)
    for _ in range(steps):
        state = T.add(ring, T.mul(ring, state, state), T.constant(ring, c, order))
    return state


def residual(ring, point, c, preperiod, period, order):
    return T.sub(ring, orbit(ring, point, c, preperiod + period, order), orbit(ring, point, c, preperiod, order))


def untruncated_orbit(point: F, c: F, steps: int) -> list[F]:
    """f_c^steps(point + e) as a full polynomial in e, by plain composition."""
    poly = [point, F(1)]
    for _ in range(steps):
        square = [F(0)] * (2 * len(poly) - 1)
        for i, a in enumerate(poly):
            for j, b in enumerate(poly):
                square[i + j] += a * b
        square[0] += c
        poly = square
    return poly


def box(re, im=0) -> ComplexIQ:
    return ComplexIQ.singleton(re, im)


def domain_of(radius: F) -> ComplexIQ:
    return ComplexIQ.of(-radius, radius, -radius, radius)


def test_q_specimens():
    assert orbit(Q, F(1, 3), F(0), 2, 2) == (F(1, 81), F(4, 27), F(2, 3))
    assert orbit(Q, F(-1, 2), F(-3, 4), 2, 4) == (F(-1, 2), 1, 0, -2, 1)


@pytest.mark.parametrize("point,c,steps,order", [
    (F(1, 3), F(0), 3, 5), (F(-1, 2), F(-3, 4), 3, 4), (F(2, 7), F(1, 5), 4, 6), (F(0), F(-2), 2, 1),
])
def test_jets_are_the_truncated_composition(point, c, steps, order):
    assert orbit(Q, point, c, steps, order) == tuple(untruncated_orbit(point, c, steps)[:order + 1])


def test_reciprocal_specimens_and_law():
    p = (F(1), F(-1), F(-1), 0, 0, 0, 0)
    assert T.reciprocal(Q, p) == (1, 1, 2, 3, 5, 8, 13)
    with pytest.raises(ValueError):
        T.reciprocal(Q, T.seed(Q, F(0), 3))
    with pytest.raises(ValueError):
        T.add(Q, T.seed(Q, F(1), 2), T.seed(Q, F(1), 3))


@pytest.mark.parametrize("q,p", [(3, 1), (4, 1), (5, 2), (7, 3)])
def test_cyclotomic_jets_match_the_germ_reference(q, p):
    ring, lam = T.cyclotomic_ring(q), cyc.zeta_power(q, p)
    order = 2 * q + 2
    state = T.seed(ring, ring.zero, order - 1)
    for _ in range(q):
        state = T.add(ring, T.scale(ring, state, lam), T.mul(ring, state, state))
    assert state == cyc.truncated_iterate(lam, q, order)
    factor = cyc.parabolic_factor(lam, q)
    assert T.reciprocal(ring, factor) == cyc.reciprocal_series(factor)


def test_gaussian_specimen_over_q_zeta4_and_boxes():
    gauss = T.cyclotomic_ring(4)
    exact = orbit(gauss, gauss.zero, cyc.zeta(4), 3, 3)
    assert exact == tuple(cyc.from_polynomial(4, (re, im)) for re, im in ((0, -1), (0, 0), (-4, -4), (0, 0)))
    assert orbit(BOXES, BOXES.zero, box(0, 1), 3, 3) == (box(0, -1), box(0), box(-4, -4), box(0))


def test_multiplicity_specimens():
    gauss, zero, i = T.cyclotomic_ring(4), box(0), box(0, 1)
    assert T.vanishing_order(BOXES, residual(BOXES, zero, zero, 1, 1, 6)) == 2
    assert T.vanishing_order(BOXES, residual(BOXES, box(1), zero, 0, 1, 6)) == 1
    assert T.vanishing_order(BOXES, residual(BOXES, zero, i, 2, 2, 6)) == 2
    assert T.vanishing_order(gauss, residual(gauss, gauss.zero, cyc.zeta(4), 2, 2, 6)) == 2
    assert T.vanishing_order(BOXES, residual(BOXES, box(F(1, 2)), box(F(1, 4)), 0, 1, 6)) == 2
    assert T.vanishing_order(BOXES, residual(BOXES, box(F(-1, 2)), box(F(-3, 4)), 0, 2, 6)) == 3
    c_q4, z_q4 = cyc.from_polynomial(4, (F(1, 4), F(1, 2))), cyc.from_polynomial(4, (0, F(1, 2)))
    assert T.vanishing_order(gauss, residual(gauss, z_q4, c_q4, 0, 4, 9)) == 5
    assert T.vanishing_order(BOXES, residual(BOXES, zero, i, 2, 2, 1)) is None


def iterate_model(model, c, steps, product):
    for _ in range(steps):
        model = TM.add_constant(BOXES, product(model), c)
    return model


def test_taylor_specimens():
    once = iterate_model(TM.variable(BOXES, box(-1), domain_of(F(1, 64)), 3), box(0), 1,
                         lambda m: TM.square_model(BOXES, m))
    assert once.polynomial == (box(1), box(-2), box(1), box(0))
    assert once.remainder == box(0)
    state = iterate_model(TM.variable(BOXES, box(0, F(1, 2)), domain_of(F(1, 32)), 3), box(F(1, 4), F(1, 2)), 3,
                          lambda m: TM.square_model(BOXES, m))
    assert state.polynomial[1] == box(0, -1)
    assert state.remainder == ComplexIQ.of(
        F(-8020741, 274877906944), F(1002593, 34359738368), F(-387425, 34359738368), F(897533, 34359738368))


def test_square_is_the_product_with_itself():
    start, c = TM.variable(BOXES, box(0, F(1, 2)), domain_of(F(1, 32)), 2), box(F(1, 4), F(1, 2))
    squared = iterate_model(start, c, 3, lambda m: TM.square_model(BOXES, m))
    multiplied = iterate_model(start, c, 3, lambda m: TM.mul_models(BOXES, m, m))
    assert squared == multiplied


def test_models_over_different_domains_are_refused():
    left = TM.variable(BOXES, box(0), domain_of(F(1, 8)), 2)
    with pytest.raises(ValueError):
        TM.mul_models(BOXES, left, TM.variable(BOXES, box(0), domain_of(F(1, 4)), 2))


def test_the_enclosure_contains_every_orbit():
    rng = random.Random(20261006)
    centre, radius, c = box(F(1, 5), F(-1, 7)), F(1, 50), box(F(-1, 8), F(1, 8))
    model = TM.variable(BOXES, centre, domain_of(radius), 2)
    points = [box(F(1, 5) + F(rng.randint(-50, 50), 2500), F(-1, 7) + F(rng.randint(-50, 50), 2500))
              for _ in range(40)]
    for _ in range(5):
        model = TM.add_constant(BOXES, TM.square_model(BOXES, model), c)
        points = [z.square().add(c) for z in points]
        enclosure = model.enclosure()
        assert all(z.subset_of(enclosure) for z in points)
