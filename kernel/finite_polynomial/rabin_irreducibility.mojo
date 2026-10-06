# rabin_irreducibility.mojo
#
# Rabin's irreducibility test over F_p: f of degree n >= 1 is irreducible iff
# x^(p^n) = x mod f and gcd(f, x^(p^(n/q)) - x) = 1 for every prime q | n. The
# certificate records, for each such q, the image x^(p^(n/q)) mod f and Bezout
# cofactors s, t with s f + t (image - x) = 1, so the coprimality is replayed
# by multiplication alone; the images themselves are recomputed.
#
# Source: M. O. Rabin, "Probabilistic algorithms in finite fields", SIAM J.
# Comput. 9 (1980), 273-280; standard reference J. von zur Gathen and
# J. Gerhard, Modern Computer Algebra, 3rd ed., 2013, Section 14.9.

from finite_polynomial.polynomial_fp import (
    PolyFp,
    poly_fp_add,
    poly_fp_constant,
    poly_fp_equal,
    poly_fp_frobenius_power,
    poly_fp_gcd,
    poly_fp_mul,
    poly_fp_rem,
    poly_fp_sub,
    poly_fp_x,
    poly_fp_xgcd,
    require_field,
)


def prime_divisors(n: Int) -> List[Int]:
    """The distinct primes dividing n >= 1, increasing."""
    var out = List[Int]()
    var rest = n
    var d = 2
    while d <= rest // d:
        if rest % d == 0:
            out.append(d)
            while rest % d == 0:
                rest //= d
        d += 1
    if rest > 1:
        out.append(rest)
    return out^


def poly_fp_is_irreducible(f: PolyFp) raises -> Bool:
    """Rabin: f of degree n >= 1 is irreducible over F_p iff x^(p^n) = x mod f
    and gcd(f, x^(p^(n/q)) - x) = 1 for every prime q | n."""
    require_field(f)
    var n = f.degree()
    if n < 1:
        raise Error("irreducibility of a constant")
    var x = poly_fp_rem(poly_fp_x(f.modulus), f)
    if not poly_fp_equal(poly_fp_frobenius_power(f, n), x):
        return False
    for q in prime_divisors(n):
        var image = poly_fp_frobenius_power(f, n // q)
        if poly_fp_gcd(f, poly_fp_sub(image, x)).degree() != 0:
            return False
    return True


struct IrreducibilityCertificate(Copyable, Movable):
    """Rabin's criterion with its coprimality witnessed: for each prime q | deg f,
    images[i] = x^(p^(n/q)) mod f and s[i] f + t[i] (images[i] - x) = 1."""

    var f: PolyFp
    var divisors: List[Int]
    var images: List[PolyFp]
    var s: List[PolyFp]
    var t: List[PolyFp]

    def __init__(out self, f: PolyFp):
        self.f = f.copy()
        self.divisors = List[Int]()
        self.images = List[PolyFp]()
        self.s = List[PolyFp]()
        self.t = List[PolyFp]()


def poly_fp_irreducibility_certificate(f: PolyFp) raises -> IrreducibilityCertificate:
    """The certificate of an irreducible f; a reducible f raises."""
    if not poly_fp_is_irreducible(f):
        raise Error("reducible")
    var n = f.degree()
    var x = poly_fp_x(f.modulus)
    var out = IrreducibilityCertificate(f)
    for q in prime_divisors(n):
        var image = poly_fp_frobenius_power(f, n // q)
        var bezout = poly_fp_xgcd(f, poly_fp_sub(image, x))
        out.divisors.append(q)
        out.images.append(image^)
        out.s.append(bezout.s.copy())
        out.t.append(bezout.t.copy())
    return out^


def poly_fp_certificate_valid(c: IrreducibilityCertificate) -> Bool:
    """Replay: the divisors are deg f's primes, x^(p^n) = x mod f, each image is
    recomputed, and each Bezout identity holds by multiplication alone."""
    try:
        require_field(c.f)
        var n = c.f.degree()
        if n < 1:
            return False
        var primes = prime_divisors(n)
        if (
            len(primes) != len(c.divisors) or len(c.images) != len(primes)
            or len(c.s) != len(primes) or len(c.t) != len(primes)
        ):
            return False
        var x = poly_fp_x(c.f.modulus)
        if not poly_fp_equal(poly_fp_frobenius_power(c.f, n), poly_fp_rem(x, c.f)):
            return False
        var one = poly_fp_constant(c.f.modulus, 1)
        for i in range(len(primes)):
            if c.divisors[i] != primes[i]:
                return False
            if not poly_fp_equal(c.images[i], poly_fp_frobenius_power(c.f, n // primes[i])):
                return False
            var combination = poly_fp_add(
                poly_fp_mul(c.s[i], c.f), poly_fp_mul(c.t[i], poly_fp_sub(c.images[i], x))
            )
            if not poly_fp_equal(combination, one):
                return False
        return True
    except:
        return False
