# cyclotomic_polynomial.mojo
#
# The cyclotomic polynomials Phi_n over BigZ, exactly.
#
# Phi_n is the monic integer polynomial whose roots are the primitive n-th
# roots of unity; x^n - 1 = product_(d|n) Phi_d, so Phi_n is built bottom-up
# by exact monic division, and deg Phi_n = phi(n). References: C. F. Gauss,
# *Disquisitiones Arithmeticae* (1801), section VII; S. Lang, *Algebra*
# (3rd ed., Springer GTM 211, 2002), chapter VI, section 3.
#
# Previously in polynomial_z.mojo, which supplies the BigZ polynomial
# arithmetic these are built on and still re-exports all three names. What is
# claimed: the coefficients are the exact integers of the product formula.
# Irreducibility of Phi_n over Q is Gauss's theorem, which a consumer that
# reads Q[X]/(Phi_n) as a field imports.

from finite_polynomial.polynomial_z import (
    PolyZ,
    poly_div_exact_monic,
    poly_equal,
    poly_is_monic,
    poly_mul,
    poly_one,
    poly_xn_minus_one,
    rejected_poly,
)


def cyclotomic_polynomial(conductor: Int) -> PolyZ:
    """Phi_n by x^n-1 = product_(d|n) Phi_d, built bottom-up exactly."""
    if conductor < 1:
        return rejected_poly()

    var table = List[PolyZ]()
    for n in range(1, conductor + 1):
        var current = poly_xn_minus_one(n)
        for divisor in range(1, n):
            if n % divisor == 0:
                var division = poly_div_exact_monic(current, table[divisor - 1])
                if division.rejected:
                    return rejected_poly()
                current = division.quotient.copy()
        if not poly_is_monic(current):
            return rejected_poly()
        table.append(current.copy())
    return table[conductor - 1].copy()


def cyclotomic_degree(conductor: Int) -> Int:
    var value = cyclotomic_polynomial(conductor)
    return value.degree()


def cyclotomic_product_identity(conductor: Int) -> Bool:
    """Check product_(d|n) Phi_d = x^n - 1 exactly."""
    if conductor < 1:
        return False
    var product = poly_one()
    for divisor in range(1, conductor + 1):
        if conductor % divisor == 0:
            product = poly_mul(product, cyclotomic_polynomial(divisor))
            if product.rejected:
                return False
    return poly_equal(product, poly_xn_minus_one(conductor))
