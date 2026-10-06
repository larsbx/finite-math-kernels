"""Wielandt's bound on the exponent of a primitive non-negative matrix.

A non-negative `n x n` matrix `M` is primitive exactly when `M^k` is strictly
positive for some `k`, and then already for `k = (n - 1)^2 + 1 = n^2 - 2n + 2`;
the bound is attained. References: H. Wielandt, "Unzerlegbare, nicht negative
Matrizen", Math. Z. 52 (1950) 642-648 (stated there); H. Schneider,
"Wielandt's proof of the exponent inequality for primitive nonnegative
matrices", Linear Algebra Appl. 353 (2002) 5-10 (Wielandt's own proof);
R. A. Brualdi and H. J. Ryser, *Combinatorial Matrix Theory* (Cambridge,
1991), section 3.5.

`wielandt_bound` was previously in `finite_linear_algebra/integer_matrix.mojo`,
which uses it to decide primitivity and still re-exports it. What is claimed:
the number is `n^2 - 2n + 2`, or a refusal. What is not: Wielandt's theorem,
which `integer_matrix.is_primitive` relies on and a consumer imports.
"""

from finite_exact.checked_int import checked_add, checked_mul


def wielandt_bound(size: Int) raises -> Int:
    """`n^2 - 2n + 2`: the largest exponent primitivity can need."""
    if size < 1:
        raise Error("integer matrix dimension must be positive")
    return checked_add(checked_mul(size - 1, size - 1), 1)
