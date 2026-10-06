"""The Farey determinant and Farey adjacency of two reduced fractions, exactly.

Two reduced fractions `p/q` and `r/s` are neighbours in a Farey sequence
exactly when `p s - q r = +-1`. References: J. Farey, "On a curious property
of vulgar fractions", Philosophical Magazine 47 (1816) 385-386; G. H. Hardy
and E. M. Wright, *An Introduction to the Theory of Numbers* (1938; 6th ed.,
Oxford, 2008), chapter III. The independent Python reference is the `farey`
module of `oracles/rational_dynamics_py`.

Previously in `rational_dynamics/rational.mojo`, which still re-exports both
names. What is claimed: the determinant is the exact BigZ of the formula.
"""

from finite_exact.bigint_z import bigz_abs, bigz_eq, bigz_from_i64, bigz_mul, bigz_sub
from rational_dynamics.rational import BigZResult, ReducedFraction, rejected_bigz_result


def farey_determinant(
    left: ReducedFraction,
    right: ReducedFraction,
) -> BigZResult:
    """p*s - q*r for p/q and r/s."""
    if left.rejected or right.rejected:
        return rejected_bigz_result()
    var out = BigZResult()
    out.value = bigz_sub(
        bigz_mul(left.num, right.den),
        bigz_mul(left.den, right.num),
    )
    return out^


def farey_adjacent(left: ReducedFraction, right: ReducedFraction) -> Bool:
    """Whether the exact Farey determinant has absolute value one."""
    var determinant = farey_determinant(left, right)
    return (
        not determinant.rejected and
        bigz_eq(bigz_abs(determinant.value), bigz_from_i64(1))
    )
