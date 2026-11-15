"""The trace polynomials of the Fibonacci substitution, over Q.

`t_(-1) = 2`, `t_0 = E`, `t_1 = E - lam` and `t_(k+1) = t_k t_(k-1) - t_(k-2)`.
`t_k` is monic of degree the Fibonacci number `F_k` (`F_0 = F_1 = 1`).
References: A. Suto, "The spectrum of a quasiperiodic Schrodinger operator",
Comm. Math. Phys. 111 (1987) 409-415, in the normalization `t_k = 2 x_k`;
M. Kohmoto, L. P. Kadanoff and C. Tang, "Localization problem in one
dimension: mapping and escape", Phys. Rev. Lett. 50 (1983) 1870-1872;
specification: docs/fibonacci-hamiltonian-band-edges-spec.md, section 1. The
executable reference is `reference/fibonacci_hamiltonian_reference.py`.

What is claimed: the polynomials are the exact ones of the recurrence. What
is not: that `t_k` is the trace of a transfer matrix, which the tests check
against a characteristic polynomial at stated levels and no further.
"""

from finite_exact.rat_q import Q
from finite_linear_algebra.qpoly import add, mul, sub
from finite_linear_algebra.scalar import q_int


def constant(n: Int) -> List[Q]:
    var out = List[Q]()
    out.append(q_int(n))
    return out^


def trace_polynomials(k: Int, lam: Q) -> List[List[Q]]:
    """`[t_0, ..., t_k]`; empty for a negative level."""
    var levels = List[List[Q]]()
    if k < 0:
        return levels^
    var before = constant(2)
    var here = List[Q]()
    here.append(Q.zero())
    here.append(Q.one())
    var after = List[Q]()
    after.append(lam.neg())
    after.append(Q.one())
    levels.append(here.copy())
    for _ in range(k):
        levels.append(after.copy())
        var next = sub(mul(after, here), before)
        before = here^
        here = after^
        after = next^
    return levels^


def trace_polynomial(k: Int, lam: Q) -> List[Q]:
    """`t_k`; the zero polynomial for a negative level."""
    var levels = trace_polynomials(k, lam)
    if len(levels) == 0:
        return List[Q]()
    return levels[k].copy()


def trace_value(k: Int, lam: Q, energy: Q) -> Q:
    """`t_k(energy)` by the scalar recurrence, without forming a polynomial."""
    var before = q_int(2)
    var here = energy.copy()
    var after = energy.sub(lam)
    for _ in range(k):
        var next = after.mul(here).sub(before)
        before = here^
        here = after^
        after = next^
    return here^


def invariant(a: List[Q], b: List[Q], c: List[Q]) -> List[Q]:
    """`a^2 + b^2 + c^2 - a b c - 4`, the Fricke-Vogt invariant of three traces."""
    var squares = add(add(mul(a, a), mul(b, b)), mul(c, c))
    return sub(sub(squares, mul(mul(a, b), c)), constant(4))
