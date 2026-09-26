"""Independent exact reference for the quadratic germ coefficient.

For lambda = zeta_q^p, compute

    [w^q] 1/P(w),
    w - g_lambda^q(w) = w^(q+1) P(w),
    g_lambda(w) = lambda*w + w^2.

Every operation is over fractions and the exact quotient Q[X]/Phi_q.
"""

from __future__ import annotations

from math import gcd

from tools.cyclotomic_quotient_reference import (
    CQ,
    add,
    inverse,
    mul,
    neg,
    one,
    power,
    sub,
    zero,
    zeta,
)


def _is_zero(value: CQ) -> bool:
    return all(coefficient == 0 for coefficient in value.coefficients)


def _convolve(left: list[CQ], right: list[CQ], order: int) -> list[CQ]:
    conductor = left[0].conductor
    out = [zero(conductor) for _ in range(order + 1)]
    for i, a in enumerate(left):
        for j, b in enumerate(right):
            if i + j > order:
                break
            out[i + j] = add(out[i + j], mul(a, b))
    return out


def germ_iterate(multiplier: CQ, steps: int, order: int) -> list[CQ]:
    if steps < 0 or order < 1:
        raise ValueError("invalid jet request")
    conductor = multiplier.conductor
    state = [zero(conductor) for _ in range(order + 1)]
    state[1] = one(conductor)
    for _ in range(steps):
        squared = _convolve(state, state, order)
        state = [
            add(mul(multiplier, coefficient), squared[i])
            for i, coefficient in enumerate(state)
        ]
    return state


def index_coefficient(p: int, q: int) -> CQ:
    if q < 1 or p < 1 or gcd(p, q) != 1:
        raise ValueError("p/q must be reduced with positive entries")

    multiplier = power(zeta(q), p % q)
    order = 2 * q + 1
    iterate = germ_iterate(multiplier, q, order)

    identity = [zero(q) for _ in range(order + 1)]
    identity[1] = one(q)
    difference = [sub(identity[i], iterate[i]) for i in range(order + 1)]

    if any(not _is_zero(value) for value in difference[: q + 1]):
        raise ArithmeticError("parabolic factorization failed")

    p_coeffs = difference[q + 1 : 2 * q + 2]
    inv0 = inverse(p_coeffs[0])
    reciprocal = [inv0]
    for n in range(1, q + 1):
        total = zero(q)
        for k in range(1, n + 1):
            total = add(total, mul(p_coeffs[k], reciprocal[n - k]))
        reciprocal.append(neg(mul(inv0, total)))
    return reciprocal[q]
