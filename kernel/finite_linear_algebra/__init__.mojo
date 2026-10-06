# finite_linear_algebra: exact finite-dimensional linear algebra and
# rank-three tensor combinatorics over finite_exact.Q.
#
#   scalar    q_int, q_vec (integer lifts) and the fail-closed q_is_zero.
#   mat3      Mat3: integer 3x3 product, scale, apply, trace, det, adjugate,
#             characteristic polynomial; has_rational_root for a monic cubic.
#   qlinalg   n-dimensional RREF, rank, nullspace, span test, matvec over Q.
#   qpoly     exact polynomials over Q: division, gcd, squarefree part
#             (docs/exact-polynomial-root-isolation-spec.md); re-exports the
#             three named modules below.
#   cauchy_bound       the Cauchy root bound (Cauchy 1829).
#   sturm_sequence     the Sturm chain, sign variations, and an isolating
#             bracket for the largest real root (Sturm 1829).
#   faddeev_leverrier  the characteristic polynomial in any dimension
#             (Le Verrier 1840; Faddeev-Sominsky 1949).
#   integer_matrix  square non-negative Int matrices of any size: product,
#             positivity, primitivity by Wielandt's bound.
#   wielandt_bound     n^2 - 2n + 2, the primitivity exponent bound
#             (Wielandt 1950).
#   integer_module     row operations and Bezout coefficients over BigZ;
#             re-exports hermite_normal_form.
#   hermite_normal_form  the canonical row HNF of a subgroup of Z^d
#             (Hermite 1851).
#   madic_ball  M-adic balls, cosets of M^k Z^n (docs/madic-ball-arithmetic-spec.md);
#             re-exports smith_normal_form.
#   smith_normal_form  invariant factors by determinantal divisors (Smith 1861).
#   integer_vector  checked Int vector add, sub and matvec.
#   tensor3   Q^27 with lex coordinates: shuffle functional and matrix, cube
#             action of a Mat3, Levi-Civita contraction.
#   w3        the shuffle kernel W_3 = ker(S): derived basis, membership,
#             span comparison.
#
# The library computes; it does not promote a finite-corpus result to a
# theorem. Mat3 and the rank-three tensors are explicit fixed-dimension fast
# paths (qlinalg is generic in the dimension). Consumers vendor this directory
# together with finite_exact/ and pin both in their vendored.toml (README.md).
