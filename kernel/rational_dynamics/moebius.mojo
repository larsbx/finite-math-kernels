# moebius.mojo
#
# The Moebius function mu, exactly.
#
# A. F. Moebius, "Ueber eine besondere Art von Umkehrung der Reihen", J. reine
# angew. Math. 9 (1832) 105-123; standard reference: Hardy and Wright, An
# Introduction to the Theory of Numbers, section 16.3. The doubling-map
# number theory reads it through Moebius inversion over the divisors of
# 2^k - 1 (doubling.exact_type_count).
#
# Mirrors `moebius` of the Python plane `oracles/rational_dynamics_py/moebius_function.py`,
# which is its independent reference. This is the one Mojo implementation:
# finite_polynomial.moebius_function re-exports it, also as `mobius_mu`.
# Machine `Int` in, machine `Int` out: the value is -1, 0 or 1 and trial
# division never forms a product past `n`.


def moebius(n: Int) raises -> Int:
    """`mu(n)` for `n >= 1`: `0` if a square divides `n`, else `(-1)^(number of primes)`.

    `n < 1` is refused: the function is defined on positive integers only.
    """
    if n < 1:
        raise Error("the Moebius function is defined on positive integers")
    var rest = n
    var sign = 1
    var factor = 2
    while factor <= rest // factor:
        if rest % factor == 0:
            rest //= factor
            if rest % factor == 0:
                return 0
            sign = -sign
        factor += 1
    return -sign if rest > 1 else sign
