# rational_dynamics: exact finite arithmetic on reduced rational fractions.
#
# The package owns representation and integer combinatorics only. It knows
# nothing about measured angles, ray landing, Mandelbrot or Julia sets, Ford
# circles, tuning semantics, or certificate acceptance.
#
# Public operations live in these modules:
#
#   rational     ReducedFraction, reduction, doubling mod one, modular inverses,
#                continued fractions, Farey determinants.
#   doubling     the doubling map on Q/Z without a cap: preperiod, period,
#                exact_type, binary_digits, binary_block, exact_type_count.
#   multiplicative_order  order_of_two, ord_m(2) exactly and uncapped
#                (Gauss, Disquisitiones Arithmeticae, 1801).
#   carmichael   carmichael_lambda, the Carmichael function (Carmichael, 1910).
#   moebius      moebius, the Moebius function (Moebius, 1832).
#   integers     generic BigZ helpers: bigz_to_int (refuses, never
#                truncates), modular powers of two, trial-division factors.
#
# Each named object has its own module, cited in its header.
# oracles/rational_dynamics_py is the independent Python plane.
