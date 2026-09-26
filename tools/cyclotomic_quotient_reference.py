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


def inverse(value: CQ) -> CQ:
    if all(coefficient == 0 for coefficient in value.coefficients):
        raise ZeroDivisionError("zero has no inverse")

    degree = len(value.coefficients)
    matrix = [[Fraction(0) for _ in range(degree + 1)] for _ in range(degree)]

    generator = zeta(value.conductor)
    basis_power = one(value.conductor)
    for column in range(degree):
        product = mul(value, basis_power)
        for row in range(degree):
            matrix[row][column] = product.coefficients[row]
        basis_power = mul(basis_power, generator)
    matrix[0][degree] = 1

    row = 0
    for column in range(degree):
        pivot = next((i for i in range(row, degree) if matrix[i][column]), None)
        if pivot is None:
            continue
        matrix[row], matrix[pivot] = matrix[pivot], matrix[row]
        pivot_value = matrix[row][column]
        matrix[row] = [entry / pivot_value for entry in matrix[row]]
        for i in range(degree):
            if i == row or not matrix[i][column]:
                continue
            factor = matrix[i][column]
            matrix[i] = [
                matrix[i][j] - factor * matrix[row][j]
                for j in range(degree + 1)
            ]
        row += 1

    if row != degree:
        raise ZeroDivisionError("element is not invertible")

    solution = [Fraction(0)] * degree
    for i in range(degree):
        pivot = next(j for j in range(degree) if matrix[i][j] == 1)
        solution[pivot] = matrix[i][degree]

    result = reduce_coefficients(value.conductor, solution)
    if mul(value, result) != one(value.conductor):
        raise ArithmeticError("inverse replay failed")
    return result


def div(left: CQ, right: CQ) -> CQ:
    if left.conductor != right.conductor:
        raise ValueError("conductor mismatch")
    return mul(left, inverse(right))
