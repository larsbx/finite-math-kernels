# finite_linear_algebra: exact finite-dimensional linear algebra and
# rank-three tensor combinatorics over finite_exact.Q.
#
#   scalar    q_int, q_vec (integer lifts) and the fail-closed q_is_zero.
#   mat3      Mat3: integer 3x3 product, scale, apply, trace, det, adjugate,
#             characteristic polynomial; has_rational_root for a monic cubic.
#   qlinalg   n-dimensional RREF, rank, nullspace, span test, matvec over Q.
#   qpoly     exact polynomials over Q: division, gcd, squarefree part, the
#             Cauchy root bound, the Sturm chain, an isolating bracket for the
#             largest real root, and the characteristic polynomial in any
#             dimension (docs/exact-polynomial-root-isolation-spec.md).
#   tensor3   Q^27 with lex coordinates: shuffle functional and matrix, cube
#             action of a Mat3, Levi-Civita contraction.
#   w3        the shuffle kernel W_3 = ker(S): derived basis, membership,
#             span comparison.
#
# The library computes; it does not promote a finite-corpus result to a
# theorem. Mat3 and the rank-three tensors are explicit fixed-dimension fast
# paths (qlinalg is generic in the dimension). Consumers vendor this directory
# together with finite_exact/ and pin both in their vendored.toml (README.md).
