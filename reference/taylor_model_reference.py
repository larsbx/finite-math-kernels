"""Independent Python reference for finite_polynomial.taylor_model.

Taylor models: M. Berz and K. Makino, "Verified integration of ODEs and flows
using differential algebraic methods on high-order Taylor models", Reliable
Computing 4(4) (1998) 361-369; K. Makino and M. Berz, "Taylor models and other
validated functional inclusion methods", Int. J. Pure Appl. Math. 4(4) (2003)
379-456.

A model is a jet over BOXES (reference/truncated_jet_reference.py) plus a
remainder box over a domain box, with the guarantee

    for every z = centre + e with e in domain,   g(z) in p(e) + remainder.

A refusal raises ``ValueError``. Non-authoritative: kernel/finite_polynomial is
canonical.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from truncated_jet_reference import BOXES, Jet, Ring, convolve, seed


def power(ring: Ring, box, exponent: int):
    if exponent < 0 or not box.accepted():
        raise ValueError("power refused")
    result, base = ring.one, box
    while exponent:
        if exponent & 1:
            result = ring.mul(result, base)
        exponent >>= 1
        if exponent:
            base = ring.square(base)
    return result


def evaluate(ring: Ring, coefficients: Jet, domain):
    """Term by term with sharp powers, not Horner."""
    if not domain.accepted() or not coefficients:
        raise ValueError("evaluation refused")
    total = coefficients[0]
    for degree, a in enumerate(coefficients[1:], start=1):
        if not ring.is_zero(a):
            total = ring.add(total, ring.mul(a, power(ring, domain, degree)))
    return total


@dataclass(frozen=True)
class TaylorModel:
    centre: Any
    domain: Any
    polynomial: Jet
    remainder: Any

    def order(self) -> int:
        return len(self.polynomial) - 1

    def enclosure(self, ring: Ring = BOXES):
        return ring.add(evaluate(ring, self.polynomial, self.domain), self.remainder)


def variable(ring: Ring, centre, domain, order: int) -> TaylorModel:
    return TaylorModel(centre, domain, seed(ring, centre, order), ring.zero)


def add_constant(ring: Ring, model: TaylorModel, value) -> TaylorModel:
    p = (ring.add(model.polynomial[0], value),) + model.polynomial[1:]
    return TaylorModel(model.centre, model.domain, p, model.remainder)


def _split(ring: Ring, model: TaylorModel, full: Jet):
    order = model.order()
    low, high = full[:order + 1], full[order + 1:]
    tail = ring.zero
    if high:
        tail = ring.mul(evaluate(ring, high, model.domain), power(ring, model.domain, order + 1))
    return low, tail


def _compatible(left: TaylorModel, right: TaylorModel) -> None:
    if (left.centre, left.domain, left.order()) != (right.centre, right.domain, right.order()):
        raise ValueError("models over different centres, domains or orders")


def mul_models(ring: Ring, left: TaylorModel, right: TaylorModel) -> TaylorModel:
    _compatible(left, right)
    low, tail = _split(ring, left, convolve(ring, left.polynomial, right.polynomial))
    cross = ring.add(
        ring.add(
            ring.mul(evaluate(ring, left.polynomial, left.domain), right.remainder),
            ring.mul(left.remainder, evaluate(ring, right.polynomial, right.domain)),
        ),
        ring.mul(left.remainder, right.remainder),
    )
    return TaylorModel(left.centre, left.domain, low, ring.add(tail, cross))


def square_model(ring: Ring, model: TaylorModel) -> TaylorModel:
    low, tail = _split(ring, model, convolve(ring, model.polynomial, model.polynomial))
    cross = ring.mul(evaluate(ring, model.polynomial, model.domain), model.remainder)
    cross = ring.add(ring.add(cross, cross), ring.mul(model.remainder, model.remainder))
    return TaylorModel(model.centre, model.domain, low, ring.add(tail, cross))
