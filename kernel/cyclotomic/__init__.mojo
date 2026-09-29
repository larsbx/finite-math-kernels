# cyclotomic: exact arithmetic in Q(zeta_q) and the quadratic germ at zeta.
#
#   field  C1, C2 of docs/rational-dynamics-cyclotomic-bridge.md: Phi_q by the
#          Moebius product, Q(zeta_q) = Q[X]/(Phi_q) as CyclotomicField[q], an
#          ExactField with elements Cyc[q]; the Galois action zeta -> zeta^e,
#          trace and norm to Q, inverse through the norm, canonical bytes.
#   germ   Q1, Q2: truncated iterates of g(w) = lambda w + w^2, the parabolic
#          factor, and reciprocal series, each with a sticky rejection.
#
# No angle, trigonometric function or floating-point number is constructed:
# zeta_q is the class of X. The Python reference (reference/
# cyclotomic_reference.py) computes Phi_q by recursive division and inverses by
# extended Euclid; conformance/cyclotomic_field_v1.txt is replayed here.
