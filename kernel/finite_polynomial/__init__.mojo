# finite_polynomial: exact univariate polynomial arithmetic over BigZ.
#
# Extracted conceptually from finite-mandelbrot-research/src/poly_z.mojo and
# its polynomial-division plan, but promoted here to dynamic unbounded BigZ
# coefficients.  The package owns finite algebra only; consumers own theorem
# and certificate interpretations.
#
#   polynomial_z           PolyZ: exact BigZ polynomial arithmetic; re-exports
#                          cyclotomic_polynomial.
#   cyclotomic_polynomial  Phi_n by x^n - 1 = prod_(d|n) Phi_d (Gauss 1801).
#   cyclotomic_q           exact arithmetic in Q[X]/(Phi_n).
#   cyclotomic_field       Cyc[q] and CyclotomicField[q]; re-exports the two
#                          arithmetic functions below.
#   euler_totient          Euler's phi (Euler 1763).
#   moebius_function       the Moebius function mu (Moebius 1832).
#   quadratic_germ         exact jets of the quadratic germ.
