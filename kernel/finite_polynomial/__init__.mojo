# finite_polynomial: exact univariate polynomial arithmetic over BigZ.
#
# Extracted conceptually from finite-mandelbrot-research/src/poly_z.mojo and
# its polynomial-division plan, but promoted here to dynamic unbounded BigZ
# coefficients.  The package owns finite algebra only; consumers own theorem
# and certificate interpretations.
#
#   polynomial_z      PolyZ, BigZ polynomials and cyclotomic polynomials Phi_n.
#   cyclotomic_q      CyclotomicQ, exact arithmetic in Q[X]/(Phi_n).
#   cyclotomic_field  Cyc[q] and CyclotomicField[q] (compile-time conductor),
#                     CyclotomicRing (run-time conductor).
#   coefficient_ring  CoefficientRing and CoefficientField, rings as values;
#                     FieldRing[K] adapts any finite_exact ExactField;
#                     ComplexBoxRing, closed_q boxes as an enclosure ring.
#   truncated_jet     TruncatedJet[R] over any CoefficientRing: seed, constant,
#                     add, sub, scale, truncated and full products, reciprocal,
#                     vanishing order.
#   taylor_model      the Taylor model of Berz and Makino (1998) over complex
#                     boxes, re-exported here.
#   quadratic_germ    exact jets of lambda*w + w^2 over Q(zeta_q).

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
