# finite_polynomial: exact univariate polynomial arithmetic over BigZ.
#
# Extracted conceptually from finite-mandelbrot-research/src/poly_z.mojo and
# its polynomial-division plan, but promoted here to dynamic unbounded BigZ
# coefficients.  The package owns finite algebra only; consumers own theorem
# and certificate interpretations.
#
#   polynomial_z      PolyZ, exact BigZ polynomial arithmetic; re-exports
#                     cyclotomic_polynomial.
#   cyclotomic_polynomial
#                     Phi_n by x^n - 1 = prod_(d|n) Phi_d (Gauss 1801).
#   cyclotomic_q      CyclotomicQ, exact arithmetic in Q[X]/(Phi_n).
#   cyclotomic_field  Cyc[q] and CyclotomicField[q] (compile-time conductor),
#                     CyclotomicRing (run-time conductor); re-exports the two
#                     arithmetic functions below.
#   euler_totient     Euler's phi (Euler 1763).
#   moebius_function  the Moebius function mu (Moebius 1832), re-exported
#                     from rational_dynamics.moebius, its one implementation.
#   coefficient_ring  CoefficientRing and CoefficientField, rings as values;
#                     FieldRing[K] adapts any finite_exact ExactField;
#                     ComplexBoxRing, closed_q boxes as an enclosure ring.
#   truncated_jet     TruncatedJet[R] over any CoefficientRing: seed, constant,
#                     add, sub, scale, truncated and full products, reciprocal,
#                     vanishing order.
#   taylor_model      the Taylor model of Berz and Makino (1998) over complex
#                     boxes, re-exported here.
#   quadratic_germ    exact jets of lambda*w + w^2 over Q(zeta_q).
#   polynomial_fp     polynomials over Z/m and F_p with a run-time modulus
#                     below 2^31: gcd, Bezout, powers mod f, the Frobenius
#                     map. Extracted from the finite-mandelbrot-research
#                     exact-type irreducibility and critical-relation
#                     kernels, with the named algorithms below.
#   miller_rabin      deterministic Miller-Rabin primality below 2^31
#   distinct_degree   distinct-degree factorization (Cantor-Zassenhaus 1981)
#   rabin_irreducibility
#                     Rabin's irreducibility test (1980) with a replayable
#                     certificate
#   hensel_lifting    one Hensel step (Hensel 1908) from mod p to mod p^2
#
# The Taylor model and the named F_p algorithms are re-exported here.

from .taylor_model import (
    TaylorModel,
    enclosure_evaluate,
    enclosure_power,
    taylor_add,
    taylor_add_constant,
    taylor_mul,
    taylor_refused,
    taylor_square,
    taylor_variable,
)
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
