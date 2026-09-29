# finite_exact: exact integer and rational arithmetic.
#
#   bigint_z  BigZ, dynamic base-10^9 limbs: exact ring and order operations,
#             quotient/remainder by long division, exact division, gcd, and
#             the canonical Z(sign, byte_len, magnitude) encoding.
#   rat_q     Q, a normalized BigZ fraction with a sticky `rejected` flag,
#             cofactor-scaled addition and order, cross-cancelled products,
#             and the canonical Q(num, den) encoding.
#   field     ExactField, a field as a structure over its Element type, which
#             field-generic kernels are written against; QField adapts Q.
#   fp        Fp[p], elements of Z/pZ with a compile-time prime modulus below
#             2^31, canonical residues, operators + - * / == and sticky
#             rejection; FpField[p].
#
# Public boundary and stability promise: docs/exact-arithmetic-public-boundary.md.
# Specification: docs/rational-interval-arithmetic-spec.md.
#
# Nothing in this package raises, aborts, or decides certificate acceptance:
# invalid arithmetic is reported through the `rejected` flag, and what an
# accepted value is allowed to prove is the consumer's decision. Consumers
# pin a released commit of this monorepo; see docs/audit/CONSOLIDATION_PROVENANCE.md.
