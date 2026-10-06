"""Smith normal form invariants of an integer matrix, by determinantal divisors.

Every integer matrix `A` is equivalent over `Z` to a diagonal
`diag(d_1, ..., d_n)` with `d_1 | d_2 | ... | d_n`, and the invariant factors
are `d_i = D_i / D_(i-1)`, where `D_s` is the gcd of the `s x s` minors (the
determinantal divisors, `D_0 = 1`). References: H. J. S. Smith, "On systems of
linear indeterminate equations and congruences", Phil. Trans. R. Soc. London
151 (1861) 293-326; M. Newman, *Integral Matrices* (Academic Press, 1972),
chapter II, Theorem II.9; specification: docs/madic-ball-arithmetic-spec.md.

`minor_gcds` and `smith_invariants` were previously in
`finite_linear_algebra/madic_ball.mojo`, which reads the structure of
`Z^n / M^k Z^n` from them and still re-exports both. What is claimed: the
numbers are the exact gcds and quotients of the formula. What is not: Smith's
theorem that they classify the quotient group, which a consumer imports.
"""

from std.os import abort

from finite_exact.bigint_z import BigZ, bigz_divmod, bigz_from_i64, bigz_gcd
from finite_exact.rat_q import Q
from finite_linear_algebra.madic_ball import MAX_DIMENSION, index_subsets, q_integer_numerator, qmat_det, submatrix


def minor_gcds(a: List[List[Q]]) -> List[BigZ]:
    """`D_s`, the gcd of every `s x s` minor, for `s = 0 .. n`, with `D_0 = 1`."""
    var n = len(a)
    if n < 1 or n > MAX_DIMENSION:
        abort("M-adic dimension outside the supported range")
    var out = List[BigZ]()
    out.append(bigz_from_i64(1))
    for size in range(1, n + 1):
        var acc = bigz_from_i64(0)
        var row_sets = index_subsets(n, size)
        var col_sets = index_subsets(n, size)
        for r in range(len(row_sets)):
            for c in range(len(col_sets)):
                var block = submatrix(a, row_sets[r], col_sets[c])
                acc = bigz_gcd(acc, q_integer_numerator(qmat_det(block)))
        out.append(acc^)
    return out^


def smith_invariants(a: List[List[Q]]) -> List[BigZ]:
    """Invariant factors `d_1 | d_2 | ... | d_n` of an integer matrix over `Q`.

    `Z^n / A Z^n` is the direct sum of the `Z / d_i`, so this reports the group
    *structure* of the quotient and not only its order.

    Computed from the determinantal divisors, `d_i = D_i / D_{i-1}`. That
    characterisation is classical and terminates by construction; a hand-rolled
    elimination sweep does not, and the first draft of the Python oracle used
    one and failed to terminate on `M^4` for the canonical substitution.
    """
    var divisors = minor_gcds(a)
    var out = List[BigZ]()
    for i in range(1, len(divisors)):
        if divisors[i].is_zero():
            out.append(bigz_from_i64(0))      # the lattice degenerates here
            continue
        var division = bigz_divmod(divisors[i], divisors[i - 1])
        if division.rejected or not division.remainder.is_zero():
            abort("determinantal divisors must form a divisibility chain")
        out.append(division.quotient.copy())
    return out^
