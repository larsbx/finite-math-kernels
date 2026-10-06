# rational_dynamics: exact finite arithmetic on reduced rational fractions.
#
# The package owns representation and integer combinatorics only. It knows
# nothing about measured angles, ray landing, Mandelbrot or Julia sets, Ford
# circles, tuning semantics, or certificate acceptance.
#
# Public operations live in rational.mojo, which also re-exports the named
# modules beside it:
#
#   continued_fractions  regular continued fractions and convergents
#                        (Khinchin; Hardy-Wright, chapter X).
#   farey                the Farey determinant and adjacency (Farey 1816;
#                        Hardy-Wright, chapter III).
