# distinct_degree.mojo
#
# Distinct-degree factorization over F_p: for square-free f, the product of
# its monic irreducible factors of degree i is gcd(g, x^(p^i) - x) once the
# factors of smaller degree are divided out of g. The powers x^(p^i) mod f are
# iterated through the Frobenius map of finite_polynomial.polynomial_fp.
#
# Source: D. G. Cantor and H. Zassenhaus, "A new algorithm for factoring
# polynomials over finite fields", Math. Comp. 36 (1981), 587-592; standard
# reference J. von zur Gathen and J. Gerhard, Modern Computer Algebra,
# 3rd ed., Cambridge University Press, 2013, Algorithm 14.3.

from finite_polynomial.polynomial_fp import (
    FrobeniusMap,
    PolyFp,
    poly_fp_gcd,
    poly_fp_is_squarefree,
    poly_fp_monic,
    poly_fp_quo,
    poly_fp_rem,
    poly_fp_sub,
    poly_fp_x,
    require_field,
)


@fieldwise_init
struct DegreePart(Copyable, Movable):
    """The product of the monic irreducible factors of one degree."""

    var degree: Int
    var product: PolyFp


def poly_fp_distinct_degree(f: PolyFp) raises -> List[DegreePart]:
    """Distinct-degree factorization of a square-free nonconstant f over F_p:
    gcd(g, x^(p^i) - x) strips the factors of degree i, i = 1, 2, ..."""
    require_field(f)
    if f.degree() < 1:
        raise Error("distinct-degree factorization of a constant")
    if not poly_fp_is_squarefree(f):
        raise Error("not squarefree")
    var frobenius = FrobeniusMap(f)
    var x = poly_fp_x(f.modulus)
    var parts = List[DegreePart]()
    var g = poly_fp_monic(f)
    var h = poly_fp_rem(x, f)
    var i = 0
    while g.degree() >= 2 * (i + 1):
        i += 1
        h = frobenius.apply(h)
        var common = poly_fp_gcd(g, poly_fp_sub(h, x))
        if common.degree() > 0:
            g = poly_fp_quo(g, common)
            parts.append(DegreePart(i, common^))
    if g.degree() > 0:
        parts.append(DegreePart(g.degree(), g^))
    return parts^


def poly_fp_factor_degrees(f: PolyFp) raises -> List[Int]:
    """The sorted degrees of the irreducible factors of square-free f over F_p."""
    var degrees = List[Int]()
    for part in poly_fp_distinct_degree(f):
        for _ in range(part.product.degree() // part.degree):
            degrees.append(part.degree)
    sort(degrees)
    return degrees^
