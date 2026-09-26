"""Independent Python reference for exact cyclotomic polynomials.

This mirrors only the mathematical recurrence used by the Mojo foundation:
x^n - 1 = product_(d|n) Phi_d.  It is not an acceptance checker.
"""

from __future__ import annotations


def trim(coeffs: list[int]) -> tuple[int, ...]:
    while len(coeffs) > 1 and coeffs[-1] == 0:
        coeffs.pop()
    return tuple(coeffs)


def mul(a: tuple[int, ...], b: tuple[int, ...]) -> tuple[int, ...]:
    out = [0] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] += x * y
    return trim(out)


def xn_minus_one(n: int) -> tuple[int, ...]:
    if n < 1:
        raise ValueError("n must be positive")
    out = [0] * (n + 1)
    out[0] = -1
    out[n] = 1
    return tuple(out)


def exact_div_monic(dividend: tuple[int, ...], divisor: tuple[int, ...]) -> tuple[int, ...]:
    if not divisor or divisor[-1] != 1:
        raise ValueError("divisor must be monic")
    work = list(dividend)
    q = [0] * max(1, len(dividend) - len(divisor) + 1)
    while len(work) >= len(divisor):
        lead = work[-1]
        shift = len(work) - len(divisor)
        q[shift] = lead
        for j, c in enumerate(divisor):
            work[shift + j] -= lead * c
        while len(work) > 1 and work[-1] == 0:
            work.pop()
        if len(work) == 1 and work[0] == 0:
            break
    if any(work):
        raise ValueError("division is not exact")
    return trim(q)


def cyclotomic(n: int) -> tuple[int, ...]:
    if n < 1:
        raise ValueError("conductor must be positive")
    table: list[tuple[int, ...]] = []
    for m in range(1, n + 1):
        current = xn_minus_one(m)
        for d in range(1, m):
            if m % d == 0:
                current = exact_div_monic(current, table[d - 1])
        table.append(current)
    return table[n - 1]


def product_identity(n: int) -> bool:
    if n < 1:
        return False
    product = (1,)
    for d in range(1, n + 1):
        if n % d == 0:
            product = mul(product, cyclotomic(d))
    return product == xn_minus_one(n)
