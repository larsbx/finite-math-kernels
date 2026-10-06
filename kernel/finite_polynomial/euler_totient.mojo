# euler_totient.mojo
#
# Euler's totient phi(n), exactly: the number of 1 <= k <= n coprime to n.
#
# It is the degree of Q(zeta_n) over Q, which cyclotomic_field.mojo checks at
# compile time against deg Phi_n. References: L. Euler, "Theoremata arithmetica
# nova methodo demonstrata", Novi Commentarii Acad. Sci. Petropolitanae 8
# (1763) 74-104; G. H. Hardy and E. M. Wright, *An Introduction to the Theory
# of Numbers* (1938; 6th ed., Oxford, 2008), section 5.5.
#
# `euler_phi` was previously in cyclotomic_field.mojo, which keeps the coprimality
# predicate it counts with and still re-exports it.

from finite_polynomial.cyclotomic_field import _coprime


def euler_phi(n: Int) -> Int:
    var count = 0
    for k in range(1, n + 1):
        if _coprime(k, n):
            count += 1
    return count
