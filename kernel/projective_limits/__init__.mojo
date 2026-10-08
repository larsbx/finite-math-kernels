# projective_limits: exact limits of rational functions as points of P^1(K).
#
# K is any finite_exact.field.ExactField: QField by default (P1, Poly, ...
# are the QField instances of P1Over, PolyOver, ...), or FpField[p]. A limit of
# f in K(x) at a point of P^1(K) lies in P^1(K); see
# docs/projective-limits-over-exact-fields.md.
#
#   line    P1 in normal form, the squared chordal metric; re-exports
#           mobius_transformation.
#   mobius_transformation  Moebius maps of P^1(K): PGL_2 action and
#           composition (Moebius 1855; Ahlfors, chapter 3).
#   rotor   rotations as non-isotropic points of P^1(K): the group law
#           a (+) b = R_a(b), the half-turn infinity, orders, turns a/n
#           through a generator, the circle chart, spreads; re-exports
#           spread_polynomial.
#   spread_polynomial  the spread polynomials S_n (Wildberger 2005).
#   limits  the landing kernel (lowest-order point on the exceptional divisor)
#           and what it computes: limits at any point of P^1, tangent slopes
#           in the pencil, asymptotes, directional and arc limits of bivariate
#           quotients, and path-dependence witnesses.
#
# The package decides only exact finite facts. A path-dependence witness
# certifies nonexistence of a limit; a search that finds none is inconclusive.
