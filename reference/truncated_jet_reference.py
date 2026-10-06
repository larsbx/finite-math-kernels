"""Independent Python reference for finite_polynomial.truncated_jet and coefficient_ring.

A ring is a value: its zero and one, and the operations on its elements. A
jet is a tuple of coefficients, low order first; the truncation is the object.
Taylor models are in reference/taylor_model_reference.py.

Rings here: ``FRACTIONS`` (Q), ``cyclotomic_ring(n)`` over
reference/cyclotomic_reference.py (Phi_n by recursive division, inverses by the
extended Euclidean algorithm, independent of the Mojo kernel's divisor product
and RREF), and ``BOXES`` over oracles/closed_interval.ComplexIQ.

A refusal raises ``ValueError``; nothing is clamped or rounded.
Non-authoritative: kernel/finite_polynomial is canonical.
"""

from __future__ import annotations

import operator
from dataclasses import dataclass
from fractions import Fraction
from typing import Any, Callable

import cyclotomic_reference as cyc
from closed_interval import ComplexIQ


@dataclass(frozen=True)
class Ring:
    zero: Any
    one: Any
    is_zero: Callable[[Any], bool]
    add: Callable[[Any, Any], Any] = operator.add
    sub: Callable[[Any, Any], Any] = operator.sub
    mul: Callable[[Any, Any], Any] = operator.mul
    inverse: Callable[[Any], Any] | None = None
    square: Callable[[Any], Any] | None = None  # the sharp square, BOXES only


FRACTIONS = Ring(Fraction(0), Fraction(1), lambda a: a == 0, inverse=lambda a: 1 / a)


def cyclotomic_ring(n: int) -> Ring:
    return Ring(cyc.constant(n, 0), cyc.constant(n, 1), cyc.is_zero, cyc.add, cyc.sub, cyc.mul, cyc.inverse)


def _box_is_zero(a: ComplexIQ) -> bool:
    return a.accepted() and a.re.lo == a.re.hi == a.im.lo == a.im.hi == 0


BOXES = Ring(
    ComplexIQ.singleton(0), ComplexIQ.singleton(1), _box_is_zero,
    ComplexIQ.add, ComplexIQ.sub, ComplexIQ.mul, square=ComplexIQ.square,
)

Jet = tuple


def constant(ring: Ring, value, order: int) -> Jet:
    if order < 0:
        raise ValueError("negative order")
    return (value,) + (ring.zero,) * order


def seed(ring: Ring, point, order: int) -> Jet:
    if order < 0:
        raise ValueError("negative order")
    return (point,) + ((ring.one,) + (ring.zero,) * (order - 1) if order else ())


def _same_order(left: Jet, right: Jet) -> None:
    if len(left) != len(right):
        raise ValueError("jets of different orders")


def add(ring: Ring, left: Jet, right: Jet) -> Jet:
    _same_order(left, right)
    return tuple(ring.add(a, b) for a, b in zip(left, right))


def sub(ring: Ring, left: Jet, right: Jet) -> Jet:
    _same_order(left, right)
    return tuple(ring.sub(a, b) for a, b in zip(left, right))


def scale(ring: Ring, state: Jet, factor) -> Jet:
    return tuple(ring.mul(factor, a) for a in state)


def _coefficient(ring: Ring, left: Jet, right: Jet, n: int):
    total = ring.zero
    for i in range(max(0, n - len(right) + 1), min(n, len(left) - 1) + 1):
        total = ring.add(total, ring.mul(left[i], right[n - i]))
    return total


def convolve(ring: Ring, left: Jet, right: Jet) -> Jet:
    """The full product; nothing is dropped."""
    return tuple(_coefficient(ring, left, right, n) for n in range(len(left) + len(right) - 1))


def mul(ring: Ring, left: Jet, right: Jet) -> Jet:
    _same_order(left, right)
    return tuple(_coefficient(ring, left, right, n) for n in range(len(left)))


def reciprocal(ring: Ring, state: Jet) -> Jet:
    """1/state to the same order; refused unless the constant term is a unit."""
    if ring.inverse is None or ring.is_zero(state[0]):
        raise ValueError("reciprocal of a jet whose constant term is not a unit")
    inv0 = ring.inverse(state[0])
    out = [inv0]
    for n in range(1, len(state)):
        total = ring.zero
        for k in range(1, n + 1):
            total = ring.add(total, ring.mul(state[k], out[n - k]))
        out.append(ring.sub(ring.zero, ring.mul(inv0, total)))
    return tuple(out)


def vanishing_order(ring: Ring, state: Jet) -> int | None:
    """The least index whose coefficient is not certainly zero; None if flat."""
    return next((i for i, a in enumerate(state) if not ring.is_zero(a)), None)
