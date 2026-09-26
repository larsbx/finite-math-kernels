"""Independent exact reference for Q[X]/(Phi_n).

The representation is a conductor plus the unique reduced coefficient vector
of degree below phi(n).  Coefficients are fractions.Fraction and all reduction
is exact.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from math import gcd

from tools.cyclotomic_reference import cyclotomic


@dataclass(frozen=True, slots=True)
class CQ:
    conductor: int
    coefficients: tuple[Fraction, ...]


def reduce_coefficients(conductor: int, values) -> CQ:
    if conductor < 1:
        raise ValueError("conductor must be positive")
    phi = cyclotomic(conductor)
    degree = len(phi) - 1
    work = [Fraction(v) for v in values]
    if len(work) < degree:
        work.extend(Fraction(0) for _ in range(degree - len(work)))

    for k in range(len(work) - 1, degree - 1, -1):
        lead = work[k]
        if lead:
            shift = k - degree
            for j in range(degree):
                work[shift + j] -= lead * phi[j]
            work[k] = 0

    return CQ(conductor, tuple(work[:degree]))


def zero(conductor: int) -> CQ:
    return reduce_coefficients(conductor, [0])


def one(conductor: int) -> CQ:
    return reduce_coefficients(conductor, [1])


def zeta(conductor: int) -> CQ:
    return reduce_coefficients(conductor, [0, 1])


def add(left: CQ, right: CQ) -> CQ:
    if left.conductor != right.conductor:
        raise ValueError("conductor mismatch")
    return reduce_coefficients(
        left.conductor,
        [a + b for a, b in zip(left.coefficients, right.coefficients)],
    )


def neg(value: CQ) -> CQ:
    return reduce_coefficients(value.conductor, [-c for c in value.coefficients])


def sub(left: CQ, right: CQ) -> CQ:
    return add(left, neg(right))


def mul(left: CQ, right: CQ) -> CQ:
    if left.conductor != right.conductor:
        raise ValueError("conductor mismatch")
    out = [Fraction(0)] * (len(left.coefficients) + len(right.coefficients) - 1)
    for i, a in enumerate(left.coefficients):
        for j, b in enumerate(right.coefficients):
            out[i + j] += a * b
    return reduce_coefficients(left.conductor, out)


def power(value: CQ, exponent: int) -> CQ:
    if exponent < 0:
        raise ValueError("negative exponent")
    out = one(value.conductor)
    base = value
    e = exponent
    while e:
        if e & 1:
            out = mul(out, base)
        e //= 2
        if e:
            base = mul(base, base)
    return out


def automorphism(value: CQ, exponent: int) -> CQ:
    if exponent < 0 or gcd(exponent, value.conductor) != 1:
        raise ValueError("exponent is not a unit modulo the conductor")
    image = power(zeta(value.conductor), exponent % value.conductor)
    out = zero(value.conductor)
    p = one(value.conductor)
    for coefficient in value.coefficients:
        out = add(
            out,
            reduce_coefficients(
                value.conductor,
                [coefficient * c for c in p.coefficients],
            ),
        )
        p = mul(p, image)
    return out
