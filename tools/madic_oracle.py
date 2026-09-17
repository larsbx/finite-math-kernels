"""Independent Python implementation of the M-adic ball carrier.

This is the oracle `tests/finite_linear_algebra/test_madic_oracle.py` compares
`finite_linear_algebra/madic_ball.mojo` against. It is written from the
definitions rather than transliterated from the Mojo, so that agreement between
the two is evidence rather than an echo.

An `M`-adic ball of level `k` is a coset `v + M^k Z^n`. Its radius is the
lattice `M^k Z^n`, not a number. Two points in the same coset at level `k` are
*unknown*, exactly as two values in one closed rational interval are unknown:
membership of the difference in `M^k Z^n` does not make them equal. Two points
in different cosets are certainly distinct, and that is the only certificate
this carrier issues.

The spec is `docs/madic-ball-arithmetic-spec.md`.
"""

from __future__ import annotations

from fractions import Fraction
from itertools import combinations
from math import gcd

Matrix = list[list[int]]


def identity(n: int) -> Matrix:
    return [[1 if i == j else 0 for j in range(n)] for i in range(n)]


def multiply(a: Matrix, b: Matrix) -> Matrix:
    n = len(a)
    return [[sum(a[i][t] * b[t][j] for t in range(n)) for j in range(n)] for i in range(n)]


def power(a: Matrix, k: int) -> Matrix:
    """`a ** k` for `k >= 0`, by repeated squaring over unbounded integers."""
    if k < 0:
        raise ValueError("M-adic levels are non-negative")
    result, base = identity(len(a)), [row[:] for row in a]
    while k:
        if k & 1:
            result = multiply(result, base)
        base = multiply(base, base)
        k >>= 1
    return result


def determinant(a: Matrix) -> int:
    """Exact determinant by fraction-free elimination over the rationals."""
    n = len(a)
    rows = [[Fraction(x) for x in row] for row in a]
    sign, det = 1, Fraction(1)
    for c in range(n):
        pivot = next((r for r in range(c, n) if rows[r][c] != 0), None)
        if pivot is None:
            return 0
        if pivot != c:
            rows[c], rows[pivot] = rows[pivot], rows[c]
            sign = -sign
        det *= rows[c][c]
        for r in range(c + 1, n):
            factor = rows[r][c] / rows[c][c]
            for j in range(c, n):
                rows[r][j] -= factor * rows[c][j]
    value = sign * det
    assert value.denominator == 1
    return int(value)


MAX_DIMENSION = 6
"""Minor enumeration is `C(n, i)^2` per size, so the dimension is bounded and a
larger one is refused rather than silently made slow."""


def _minor_gcds(a: Matrix) -> list[int]:
    """`D_i`, the gcd of every `i x i` minor, for `i = 1 .. n`, with `D_0 = 1`."""
    n = len(a)
    if n > MAX_DIMENSION:
        raise ValueError(f"dimension {n} exceeds MAX_DIMENSION {MAX_DIMENSION}")
    divisors = [1]
    for size in range(1, n + 1):
        acc = 0
        for rows in combinations(range(n), size):
            for cols in combinations(range(n), size):
                block = [[a[i][j] for j in cols] for i in rows]
                acc = gcd(acc, determinant(block))
        divisors.append(acc)
    return divisors


def smith_invariants(a: Matrix) -> list[int]:
    """The invariant factors `d_1 | d_2 | ... | d_n` of an integer matrix.

    `Z^n / A Z^n` is the direct sum of the `Z / d_i`, so this is what reports the
    *group structure* of the quotient rather than only its order.

    Computed from the determinantal divisors, `d_i = D_i / D_{i-1}` where `D_i`
    is the gcd of the `i x i` minors. That characterisation is classical and
    terminates by construction, which a hand-rolled elimination sweep does not:
    the first draft of this oracle used one and did not terminate on `M^4` for
    the canonical determinant-two substitution.
    """
    divisors = _minor_gcds(a)
    out: list[int] = []
    for i in range(1, len(divisors)):
        previous, current = divisors[i - 1], divisors[i]
        if current == 0:
            out.append(0)          # the lattice degenerates at this size
            continue
        assert current % previous == 0, "determinantal divisors must form a chain"
        out.append(current // previous)
    return out


def quotient_invariants(m: Matrix, level: int) -> list[int]:
    """Invariant factors of `Z^n / M^k Z^n`, trivial factors included."""
    return smith_invariants(power(m, level))


def quotient_order(m: Matrix, level: int) -> int:
    """`|det M^k|`, the order of the quotient; `0` when the lattice degenerates."""
    return abs(determinant(power(m, level)))


def contains(m: Matrix, level: int, delta: list[int]) -> bool:
    """Whether `delta` lies in the lattice `M^k Z^n`.

    Solves `M^k x = delta` over the rationals and asks whether `x` is integral.
    Requires `det M != 0`; a singular `M` has no well-defined level filtration
    and is refused by the caller rather than answered here.
    """
    lattice = power(m, level)
    n = len(lattice)
    rows = [[Fraction(x) for x in lattice[i]] + [Fraction(delta[i])] for i in range(n)]
    for c in range(n):
        pivot = next((r for r in range(c, n) if rows[r][c] != 0), None)
        if pivot is None:
            raise ValueError("singular lattice: det M must be non-zero")
        rows[c], rows[pivot] = rows[pivot], rows[c]
        lead = rows[c][c]
        rows[c] = [x / lead for x in rows[c]]
        for r in range(n):
            if r != c and rows[r][c] != 0:
                factor = rows[r][c]
                rows[r] = [rows[r][j] - factor * rows[c][j] for j in range(n + 1)]
    return all(rows[i][n].denominator == 1 for i in range(n))


def same_coset(m: Matrix, level: int, a: list[int], b: list[int]) -> bool:
    """Whether `a` and `b` agree modulo `M^k Z^n`. **Not** equality: see below."""
    return contains(m, level, [a[i] - b[i] for i in range(len(a))])


def separated(m: Matrix, level: int, a: list[int], b: list[int]) -> bool:
    """Different cosets at this level, which certifies `a != b`."""
    return not same_coset(m, level, a, b)


# --- non-claims -----------------------------------------------------------------


def same_coset_means_equal() -> bool:
    """Agreeing modulo `M^k Z^n` is the unknown answer, not equality. Refining
    the level can still separate the pair, and for an expanding `M` the
    intersection of every level is trivial, so only the limit decides."""
    return False


def carrier_is_scalar_padic() -> bool:
    """It is not, and the difference is not cosmetic: `Z^n / M^k Z^n` need not
    be cyclic, while a scalar `Z_p` ball at precision `k` always is."""
    return False
