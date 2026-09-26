"""Independent Python reference for the cyclotomic and quadratic-germ stages.

Stages C1, C2, Q1 and Q2 of ``docs/rational-dynamics-cyclotomic-bridge.md``:

    C1  exact quotient arithmetic in Q[zeta_q] = Q[X]/(Phi_q) and canonical bytes
    C2  the Galois action zeta -> zeta^a, gcd(a, q) = 1
    Q1  truncated iterates of g_lambda(w) = lambda*w + w^2
    Q2  reciprocal-series coefficients, refused on a noninvertible constant

Every value is an exact rational coefficient vector; no angle, trigonometric
function or floating-point number is constructed.  This module is a
non-authoritative reference: it returns finite algebra and names none of it.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from functools import lru_cache, reduce
from math import gcd
from numbers import Rational

Poly = tuple[int, ...]  # integer polynomial, low -> high


# --- integer polynomials -----------------------------------------------------


def _trim(p: tuple) -> tuple:
    end = len(p)
    while end > 1 and p[end - 1] == 0:
        end -= 1
    return p[:end]


def _poly_mul(a: tuple, b: tuple) -> tuple:
    out = [0] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] += x * y
    return tuple(out)


def _poly_exact_div_monic(num: Poly, den: Poly) -> Poly:
    """Exact quotient by a monic divisor; any remainder is refused."""
    rem, quot = list(num), [0] * (len(num) - len(den) + 1)
    for k in range(len(quot) - 1, -1, -1):
        c = rem[k + len(den) - 1]
        quot[k] = c
        for i, d in enumerate(den):
            rem[k + i] -= c * d
    if any(rem):
        raise ValueError("inexact cyclotomic division")
    return tuple(quot)


@lru_cache(maxsize=None)
def cyclotomic_polynomial(q: int) -> Poly:
    """Phi_q with integer coefficients, low -> high, from X^q - 1 = prod_{d | q} Phi_d."""
    if q <= 0:
        raise ValueError("cyclotomic conductor must be positive")
    x_q_minus_1 = (-1,) + (0,) * (q - 1) + (1,)
    lower = reduce(_poly_mul, (cyclotomic_polynomial(d) for d in range(1, q) if q % d == 0), (1,))
    return _poly_exact_div_monic(x_q_minus_1, lower)


def phi(q: int) -> int:
    return len(cyclotomic_polynomial(q)) - 1


# --- C1: Q[zeta_q] -------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Cyclotomic:
    conductor: int
    coefficients: tuple[Fraction, ...]  # basis 1, zeta, ..., zeta^(phi-1)


def _exact(c) -> Fraction:
    if isinstance(c, bool) or not isinstance(c, Rational):
        raise ValueError("coefficient must be an exact rational")
    return Fraction(c)


def cyclotomic(q: int, coefficients) -> Cyclotomic:
    """Canonical constructor: refuses a vector that is not already reduced."""
    n = phi(q)
    coeffs = tuple(_exact(c) for c in coefficients)
    if len(coeffs) != n:
        raise ValueError(f"noncanonical coefficient vector: expected {n} coefficients")
    return Cyclotomic(q, coeffs)


def from_polynomial(q: int, coefficients) -> Cyclotomic:
    """Reduce an arbitrary rational polynomial in zeta modulo Phi_q."""
    phi_q = cyclotomic_polynomial(q)
    n = len(phi_q) - 1
    v = [_exact(c) for c in coefficients] + [Fraction(0)] * n
    for k in range(len(v) - 1, n - 1, -1):
        c = v[k]
        if c:
            for i, d in enumerate(phi_q):
                v[k - n + i] -= c * d
    return Cyclotomic(q, tuple(v[:n]))


def constant(q: int, c) -> Cyclotomic:
    return from_polynomial(q, (c,))


def zeta_power(q: int, k: int) -> Cyclotomic:
    phi(q)  # refuses a nonpositive conductor before the exponent is reduced
    return from_polynomial(q, (0,) * (k % q) + (1,))


def zeta(q: int) -> Cyclotomic:
    return zeta_power(q, 1)


def _same_field(a: Cyclotomic, b: Cyclotomic) -> int:
    if a.conductor != b.conductor:
        raise ValueError("conductor mismatch")
    return a.conductor


def add(a: Cyclotomic, b: Cyclotomic) -> Cyclotomic:
    return Cyclotomic(_same_field(a, b), tuple(x + y for x, y in zip(a.coefficients, b.coefficients)))


def neg(a: Cyclotomic) -> Cyclotomic:
    return Cyclotomic(a.conductor, tuple(-x for x in a.coefficients))


def sub(a: Cyclotomic, b: Cyclotomic) -> Cyclotomic:
    return add(a, neg(b))


def mul(a: Cyclotomic, b: Cyclotomic) -> Cyclotomic:
    return from_polynomial(_same_field(a, b), _poly_mul(a.coefficients, b.coefficients))


def is_zero(a: Cyclotomic) -> bool:
    return not any(a.coefficients)


def exact_equal(a: Cyclotomic, b: Cyclotomic) -> bool:
    return a.conductor == b.conductor and a.coefficients == b.coefficients


def _poly_divmod_q(num: list[Fraction], den: list[Fraction]) -> tuple[list[Fraction], list[Fraction]]:
    """Euclidean division in Q[X] by a divisor with nonzero leading coefficient."""
    rem, quot = list(num), [Fraction(0)] * max(1, len(num) - len(den) + 1)
    for k in range(len(num) - len(den), -1, -1):
        c = rem[k + len(den) - 1] / den[-1]
        quot[k] = c
        for i, d in enumerate(den):
            rem[k + i] -= c * d
    return quot, list(_trim(tuple(rem[: len(den) - 1]) or (Fraction(0),)))


def inverse(a: Cyclotomic) -> Cyclotomic:
    """Field inverse by the extended Euclidean algorithm in Q[X]; zero is refused."""
    if is_zero(a):
        raise ValueError("zero is not invertible")
    r0, r1 = [Fraction(c) for c in cyclotomic_polynomial(a.conductor)], list(_trim(a.coefficients))
    s0, s1 = [Fraction(0)], [Fraction(1)]
    while len(r1) > 1 or r1[0] == 0:
        quot, rem = _poly_divmod_q(r0, r1)
        prod = _poly_mul(tuple(quot), tuple(s1))
        width = max(len(s0), len(prod))
        s_next = [(s0[i] if i < len(s0) else 0) - (prod[i] if i < len(prod) else 0) for i in range(width)]
        r0, r1, s0, s1 = r1, rem, s1, list(_trim(tuple(s_next)))
    unit = r1[0]
    return from_polynomial(a.conductor, tuple(c / unit for c in s1))


def automorphism(a: Cyclotomic, exponent: int) -> Cyclotomic:
    """C2: sigma_exponent(zeta) = zeta^exponent; refused unless gcd(exponent, q) = 1."""
    q = a.conductor
    if gcd(exponent, q) != 1:
        raise ValueError("automorphism exponent not coprime to conductor")
    return reduce(
        add,
        (mul(constant(q, c), zeta_power(q, exponent * i)) for i, c in enumerate(a.coefficients)),
        constant(q, 0),
    )


def _z_bytes(n: int) -> bytes:
    mag = abs(n).to_bytes((abs(n).bit_length() + 7) // 8, "big")
    return bytes([0 if n == 0 else 1 if n > 0 else 2]) + len(mag).to_bytes(8, "big") + mag


def canonical_bytes(a: Cyclotomic) -> bytes:
    """Z(conductor) followed by Q(c_i) for every basis coefficient (docs/canonical-encoding.md)."""
    return _z_bytes(a.conductor) + b"".join(_z_bytes(c.numerator) + _z_bytes(c.denominator) for c in a.coefficients)


# --- Q1: truncated germ iterates ----------------------------------------------

Series = tuple[Cyclotomic, ...]  # coefficients of w^0 .. w^(order-1)


def _series_mul(a: Series, b: Series) -> Series:
    q, order = a[0].conductor, len(a)
    return tuple(
        reduce(add, (mul(a[i], b[k - i]) for i in range(k + 1)), constant(q, 0)) for k in range(order)
    )


def truncated_iterate(lam: Cyclotomic, iterations: int, order: int) -> Series:
    """g_lambda^iterations(w) mod w^order, g_lambda(w) = lambda*w + w^2."""
    if iterations < 0 or order < 2:
        raise ValueError("iterations must be nonnegative and order at least 2")
    q = lam.conductor
    w = (constant(q, 0), constant(q, 1)) + (constant(q, 0),) * (order - 2)
    step = lambda s, _: tuple(add(mul(lam, x), y) for x, y in zip(s, _series_mul(s, s)))
    return reduce(step, range(iterations), w)


def parabolic_factor(lam: Cyclotomic, period: int) -> Series:
    """P with w - g^period(w) = w^(period+1) P(w) mod w^(2 period + 2); refused if the order is lower."""
    order = 2 * period + 2
    residual = tuple(
        sub(constant(lam.conductor, 1 if k == 1 else 0), c) for k, c in enumerate(truncated_iterate(lam, period, order))
    )
    if not all(is_zero(c) for c in residual[: period + 1]):
        raise ValueError("residual does not vanish to order period+1")
    return residual[period + 1 :]


# --- Q2: reciprocal series ----------------------------------------------------


def reciprocal_series(p: Series) -> Series:
    """1/P to the length of P; refused when the constant coefficient is not invertible."""
    if is_zero(p[0]):
        raise ValueError("reciprocal-series request with noninvertible constant coefficient")
    inv0 = inverse(p[0])
    q = p[0].conductor

    def next_coeff(acc: Series, k: int) -> Series:
        tail = reduce(add, (mul(p[i], acc[k - i]) for i in range(1, k + 1)), constant(q, 0))
        return acc + (neg(mul(inv0, tail)),)

    return reduce(next_coeff, range(1, len(p)), (inv0,))


def reciprocal_series_coefficient(p: Series, k: int) -> Cyclotomic:
    if not 0 <= k < len(p):
        raise ValueError("coefficient outside the truncation")
    return reciprocal_series(p[: k + 1])[k]
