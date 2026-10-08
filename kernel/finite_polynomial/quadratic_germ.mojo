# quadratic_germ.mojo
#
# Exact finite jets for
#
#     g_lambda(w) = lambda*w + w^2
#
# over an exact cyclotomic coefficient ring.  For lambda^q = 1, this module
# computes the formal coefficient
#
#     [w^q] 1/P(w),  where
#     w - g_lambda^q(w) = w^(q+1) P(w).
#
# This is a finite algebraic coefficient.  Consumers may attach dynamical
# meaning under their own definitions/theorems; this kernel does not infer
# bulb geometry, landing, connectivity, or any analytic statement.
#
# The jets are finite_polynomial.truncated_jet's, over CyclotomicRing.

from finite_exact.integer_gcd import gcd_int
from finite_polynomial.cyclotomic_field import CyclotomicRing
from finite_polynomial.cyclotomic_q import (
    CyclotomicQ,
    cyclotomic_pow,
    rejected_cyclotomic,
    zeta,
)
from finite_polynomial.truncated_jet import (
    TruncatedJet,
    jet_add,
    jet_mul,
    jet_reciprocal,
    jet_scale,
    jet_seed,
    jet_sub,
    rejected_jet,
)

comptime CyclotomicJet = TruncatedJet[CyclotomicRing]


def quadratic_germ_step(
    state: CyclotomicJet,
    multiplier: CyclotomicQ,
) -> CyclotomicJet:
    """`lambda*w + w^2` on a jet; refused across conductors."""
    return jet_add(jet_scale(state, multiplier), jet_mul(state, state))


def quadratic_germ_iterate(
    multiplier: CyclotomicQ,
    steps: Int,
    order: Int,
) -> CyclotomicJet:
    """The order-`order` jet of g_lambda^steps at w = 0."""
    var ring = CyclotomicRing(multiplier.conductor)
    if multiplier.rejected or steps < 0 or order < 1:
        return rejected_jet(ring)
    var state = jet_seed(ring, ring.zero(), order)
    for _ in range(steps):
        state = quadratic_germ_step(state, multiplier)
        if state.rejected:
            return state^
    return state^


def quadratic_germ_index_coefficient(p: Int, q: Int) -> CyclotomicQ:
    """Exact [w^q] 1/P for lambda=zeta_q^p.

    Requires q >= 1, p >= 1, gcd(p,q)=1.  The q=1 case uses zeta_1=1.
    """
    if q < 1 or p < 1:
        return rejected_cyclotomic()
    try:
        if gcd_int(p, q) != 1:
            return rejected_cyclotomic()
    except:
        return rejected_cyclotomic()

    var generator = zeta(q)
    if generator.rejected:
        return generator^
    var multiplier = cyclotomic_pow(generator, p % q)
    if multiplier.rejected:
        return multiplier^

    var ring = CyclotomicRing(q)
    var order = 2 * q + 1
    var difference = jet_sub(
        jet_seed(ring, ring.zero(), order),
        quadratic_germ_iterate(multiplier, q, order),
    )
    if difference.rejected:
        return rejected_cyclotomic()

    # Exact parabolic multiplicity check.  If any lower coefficient survives,
    # the requested factorization is not present and the computation refuses.
    for index in range(q + 1):
        if not ring.is_zero(difference.coeffs[index]):
            return rejected_cyclotomic()

    var p_coeffs = List[CyclotomicQ]()
    for index in range(q + 1):
        p_coeffs.append(difference.coeffs[q + 1 + index].copy())
    var reciprocal = jet_reciprocal(CyclotomicJet(ring, p_coeffs^))
    if reciprocal.rejected:
        return rejected_cyclotomic()
    return reciprocal.coeffs[q].copy()
