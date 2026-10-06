# hensel_lifting.mojo
#
# One step of Hensel's lemma: a root r of f mod p with f'(r) != 0 mod p lifts
# to the unique root r + p t of f mod p^2, t = -(f(r) / p) f'(r)^-1 mod p. One
# step only, with p^2 < 2^31; this is not a p-adic root.
#
# Source: K. Hensel, Theorie der algebraischen Zahlen, Teubner, Leipzig, 1908;
# standard reference J. von zur Gathen and J. Gerhard, Modern Computer
# Algebra, 3rd ed., 2013, Chapter 15.

from finite_polynomial.polynomial_fp import (
    Modulus,
    PolyFp,
    poly_fp_derivative,
    poly_fp_eval,
    prime_field,
)


@fieldwise_init
struct HenselStep(ImplicitlyCopyable):
    """base is a simple root of f mod p; lifted = base + p digit is the unique
    root of f mod p^2 congruent to it."""

    var prime: Int
    var base: Int
    var digit: Int
    var lifted: Int
    var modulus: Int


def _mod_prime(f: PolyFp, prime: Modulus) -> PolyFp:
    return PolyFp(prime, f.coeffs.copy())


def _square_of(f: PolyFp, prime: Int) raises -> Modulus:
    var p = prime_field(prime)
    if f.modulus.n != p.n * p.n:
        raise Error("Hensel step needs a polynomial modulo p^2")
    return p


def hensel_step(f: PolyFp, root: Int, prime: Int) raises -> HenselStep:
    """Lift a simple root of f mod p to f mod p^2; f is given modulo p^2 (so
    p^2 < 2^31). A non-root or a multiple root raises."""
    var p = _square_of(f, prime)
    var base = p.reduce(root)
    var value = poly_fp_eval(f, base)
    if value % p.n != 0:
        raise Error("not a root modulo p")
    var slope = poly_fp_eval(poly_fp_derivative(_mod_prime(f, p)), base)
    if slope == 0:
        raise Error("not a simple root modulo p")
    var digit = p.mul(-(value // p.n), p.inverse(slope))
    var lifted = base + p.n * digit
    if poly_fp_eval(f, lifted) != 0:
        raise Error("Hensel step failed to lift")
    return HenselStep(p.n, base, digit, lifted, f.modulus.n)


def hensel_step_valid(f: PolyFp, step: HenselStep) -> Bool:
    """Replay: base is a simple root mod p, lifted is the stated lift, and it is
    a root mod p^2."""
    try:
        var p = _square_of(f, step.prime)
        return (
            step.modulus == f.modulus.n and 0 <= step.base and step.base < p.n
            and 0 <= step.digit and step.digit < p.n
            and step.lifted == step.base + p.n * step.digit
            and poly_fp_eval(f, step.base) % p.n == 0
            and poly_fp_eval(poly_fp_derivative(_mod_prime(f, p)), step.base) != 0
            and poly_fp_eval(f, step.lifted) == 0
        )
    except:
        return False
