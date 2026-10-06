# finite_polynomial: exact univariate polynomial arithmetic over BigZ.
#
# Extracted conceptually from finite-mandelbrot-research/src/poly_z.mojo and
# its polynomial-division plan, but promoted here to dynamic unbounded BigZ
# coefficients.  The package owns finite algebra only; consumers own theorem
# and certificate interpretations.
#
#   polynomial_fp          polynomials over Z/m and F_p with a run-time modulus
#                          below 2^31: gcd, Bezout, powers mod f, the Frobenius
#                          map. Extracted from the finite-mandelbrot-research
#                          exact-type irreducibility and critical-relation
#                          kernels, with the named algorithms below.
#   miller_rabin           deterministic Miller-Rabin primality below 2^31
#   distinct_degree        distinct-degree factorization (Cantor-Zassenhaus 1981)
#   rabin_irreducibility   Rabin's irreducibility test (1980) with a replayable
#                          certificate
#   hensel_lifting         one Hensel step (Hensel 1908) from mod p to mod p^2
#
# The named algorithms are re-exported here.

from .miller_rabin import is_prime
from .distinct_degree import DegreePart, poly_fp_distinct_degree, poly_fp_factor_degrees
from .rabin_irreducibility import (
    IrreducibilityCertificate,
    poly_fp_certificate_valid,
    poly_fp_irreducibility_certificate,
    poly_fp_is_irreducible,
    prime_divisors,
)
from .hensel_lifting import HenselStep, hensel_step, hensel_step_valid
