# carmichael.mojo
#
# The Carmichael function lambda(n): the exponent of the unit group (Z/nZ)^*,
# the least m >= 1 with a^m = 1 (mod n) for every unit a.
#
# R. D. Carmichael, "Note on a new number theory function", Bull. Amer. Math.
# Soc. 16 (1910) 232-238. For an odd n = prod p^k it is the lcm of
# phi(p^k) = (p - 1) p^(k-1); the even case is not needed here and is refused.
# `multiplicative_order` reads ord_n(2) off it: the order divides lambda(n).

from finite_exact.bigint_z import BigZ, bigz_gcd, bigz_is_canonical, bigz_mul, bigz_sub
from rational_dynamics.integers import (
    bigz_is_even,
    bigz_one,
    bigz_quotient,
    bigz_result,
    prime_factors,
)
from rational_dynamics.rational import BigZResult, rejected_bigz_result


def carmichael_of_factors(factors: List[Tuple[BigZ, Int]]) -> BigZ:
    """`lambda(n)` from the factorisation of an odd `n`: the lcm of `(p - 1) p^(k-1)`."""
    var out = bigz_one()
    for i in range(len(factors)):
        var p = factors[i][0].copy()
        var term = bigz_sub(p, bigz_one())
        for _ in range(factors[i][1] - 1):
            term = bigz_mul(term, p)
        out = bigz_quotient(bigz_mul(out, term), bigz_gcd(out, term))
    return out^


def carmichael_lambda(n: BigZ) -> BigZResult:
    """`lambda(n)` for odd `n >= 1` (`lambda(1) = 1`); an even or non-positive `n` is refused."""
    if not bigz_is_canonical(n) or n.sign <= 0 or bigz_is_even(n):
        return rejected_bigz_result()
    return bigz_result(carmichael_of_factors(prime_factors(n)))
