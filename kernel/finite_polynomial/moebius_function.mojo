# moebius_function.mojo
#
# The Moebius function mu(n), exactly.
#
# mu(n) is 0 when a square greater than one divides n and (-1)^r when n is a
# product of r distinct primes. References: A. F. Moebius, "Ueber eine
# besondere Art von Umkehrung der Reihen", J. reine angew. Math. 9 (1832)
# 105-123; G. H. Hardy and E. M. Wright, *An Introduction to the Theory of
# Numbers* (1938; 6th ed., Oxford, 2008), section 16.3. The independent Python
# twin is the moebius_function module of oracles/rational_dynamics_py.
#
# `mobius_mu` was previously in cyclotomic_field.mojo, which still re-exports it.


def mobius_mu(n: Int) -> Int:
    """mu(n): 0 if a square divides n, else (-1)^(number of prime factors)."""
    var m = n
    var sign = 1
    var p = 2
    while p * p <= m:
        if m % p == 0:
            m //= p
            if m % p == 0:
                return 0
            sign = -sign
        p += 1
    return -sign if m > 1 else sign
