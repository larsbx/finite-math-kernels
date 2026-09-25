"""Independent Python reference for rational_dynamics R1."""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from math import gcd


@dataclass(frozen=True, slots=True)
class Address:
    numerator: int
    denominator: int


def address(numerator: int, denominator: int) -> Address:
    if numerator < 0:
        raise ValueError("numerator must be nonnegative")
    if denominator <= 0:
        raise ValueError("denominator must be positive")
    common = gcd(numerator, denominator)
    return Address(numerator // common, denominator // common)


def double_mod_one(value: Address) -> Address:
    return address(2 * value.numerator, value.denominator)


def mod_inverse(value: Address) -> int:
    residue = value.numerator % value.denominator
    if residue == 0:
        raise ValueError("zero residue is not invertible")
    return pow(residue, -1, value.denominator)


def signed_mod_inverse(value: Address) -> int:
    inv = mod_inverse(value)
    return inv - value.denominator if 2 * inv > value.denominator else inv


def continued_fraction(value: Address) -> tuple[int, ...]:
    n, d = value.numerator, value.denominator
    out = []
    while d:
        a, r = divmod(n, d)
        out.append(a)
        n, d = d, r
    return tuple(out)


def convergents(value: Address) -> tuple[Fraction, ...]:
    p2, p1 = 0, 1
    q2, q1 = 1, 0
    out = []
    for a in continued_fraction(value):
        p = a * p1 + p2
        q = a * q1 + q2
        out.append(Fraction(p, q))
        p2, p1 = p1, p
        q2, q1 = q1, q
    return tuple(out)


def farey_determinant(left: Address, right: Address) -> int:
    return left.numerator * right.denominator - left.denominator * right.numerator


def farey_adjacent(left: Address, right: Address) -> bool:
    return abs(farey_determinant(left, right)) == 1
