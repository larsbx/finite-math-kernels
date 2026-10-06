# multiplicative_order.mojo
#
# The multiplicative order of 2 modulo an odd m: ord_m(2), the least k >= 1
# with 2^k = 1 (mod m), exactly over BigZ and without a cap.
#
# C. F. Gauss, Disquisitiones Arithmeticae (1801), articles 45-52 (the
# exponent to which a number belongs); standard reference: Ireland and Rosen,
# A Classical Introduction to Modern Number Theory, 2nd ed. (1990), chapter 4.
# ord_m(2) is the period of every angle p/m in lowest terms under doubling
# (`doubling.period`). Artin's conjecture on primitive roots concerns when it
# equals phi(m) for prime m; nothing here assumes it.
#
# The order is found by direct powering for small orders and otherwise from
# the Carmichael function (`carmichael`) by trial-division factorisation,
# dividing out primes while 2^(order/p) = 1. Either way it is exact; the cost
# of a huge m with a huge order is time, never a wrong answer and never a
# silent cap. Independent reference: `order_of_two` of
# `oracles/rational_dynamics_py/doubling.py`.

from finite_exact.bigint_z import BigZ, bigz_add, bigz_eq, bigz_from_i64, bigz_is_canonical, bigz_lt, bigz_sub
from rational_dynamics.carmichael import carmichael_of_factors
from rational_dynamics.integers import (
    bigz_divides,
    bigz_is_even,
    bigz_mod,
    bigz_one,
    bigz_quotient,
    bigz_result,
    power_of_two_mod,
    prime_factors,
)
from rational_dynamics.rational import BigZResult, rejected_bigz_result

# Below this many steps the order of two is found by direct powering.
comptime DIRECT_STEPS = 4096


def order_of_two(modulus: BigZ) -> BigZResult:
    """`ord_m(2)`, the least `k >= 1` with `2^k = 1 (mod m)`, for odd `m >= 1`.

    `m == 1` gives `1`. An even or non-positive `m` is refused: two is not a
    unit there.
    """
    if not bigz_is_canonical(modulus) or modulus.sign <= 0 or bigz_is_even(modulus):
        return rejected_bigz_result()
    if bigz_eq(modulus, bigz_one()):
        return bigz_result(bigz_one())
    var power = bigz_mod(bigz_from_i64(2), modulus)
    for k in range(1, DIRECT_STEPS + 1):
        if bigz_eq(power, bigz_one()):
            return bigz_result(bigz_from_i64(Int64(k)))
        power = bigz_add(power, power)
        if not bigz_lt(power, modulus):
            power = bigz_sub(power, modulus)
    var order = carmichael_of_factors(prime_factors(modulus))
    var primes = prime_factors(order)
    for i in range(len(primes)):
        var p = primes[i][0].copy()
        while bigz_divides(p, order) and bigz_eq(power_of_two_mod(bigz_quotient(order, p), modulus), bigz_one()):
            order = bigz_quotient(order, p)
    return bigz_result(order)
