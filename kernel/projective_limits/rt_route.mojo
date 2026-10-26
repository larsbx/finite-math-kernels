# Domain-neutral exact F5/ExactField eight-vector update and route checks.
#
# The finite-math-kernels package owns reusable arithmetic. Consumers decide
# which route graph/permutohedral cells and signed receipts to materialize.
# An RT spread gate is NEVER a substitute for exact effect equality.
# Characteristic two is outside the projective spread contract.
from finite_exact.field import ExactField
from projective_limits.hyperbolic_rt import (
    add8, sub8, scale8, valid8, rejected8, equal8, norm8, spread8
)
from projective_limits.gram_geometry import gram_pair8


def affine_step8[K: ExactField](
    state: List[K.Element],
    offset: List[K.Element],
    gain: K.Element,
    coordinate: Int,
    shear: List[K.Element]
) -> List[K.Element]:
    """U(x) = x + (1 + gain*x[coordinate])*offset + x[coordinate]*shear.

    The state MAY be null. Offset is required non-null, since it identifies
    a declared directional influence. Invalid dimensions, index, or field
    elements are rejected, not mapped to the zero update.
    """
    if not valid8[K](state) or not valid8[K](offset) or not valid8[K](shear):
        return rejected8[K]()
    if coordinate < 0 or coordinate >= 8 or not K.accepted(gain):
        return rejected8[K]()
    var n = norm8[K](offset)
    if not K.accepted(n) or K.is_zero(n):
        return rejected8[K]()
    var coordinate_value = state[coordinate].copy()
    var amplitude = K.add(K.one(), K.mul(gain, coordinate_value))
    var first = add8[K](state, scale8[K](amplitude, offset))
    return add8[K](first, scale8[K](coordinate_value, shear))


def gram2_spread8[K: ExactField](
    u0: List[K.Element], u1: List[K.Element],
    v0: List[K.Element], v1: List[K.Element]
) -> K.Element:
    """Rank-two subspace spread 1 - det(M12)^2/(det(M11)*det(M22)).

    Mij are B2/2 Gram blocks. Reject any degenerate restricted form, null
    vector, invalid coordinate or zero denominator. No ordering or roots.
    This is a Gram invariant, not a metric.
    """
    if not (valid8[K](u0) and valid8[K](u1)
            and valid8[K](v0) and valid8[K](v1)):
        return K.rejected()
    var aa = K.sub(
        K.mul(gram_pair8[K](u0, u0), gram_pair8[K](u1, u1)),
        K.mul(gram_pair8[K](u0, u1), gram_pair8[K](u1, u0))
    )
    var bb = K.sub(
        K.mul(gram_pair8[K](v0, v0), gram_pair8[K](v1, v1)),
        K.mul(gram_pair8[K](v0, v1), gram_pair8[K](v1, v0))
    )
    if not K.accepted(aa) or not K.accepted(bb):
        return K.rejected()
    if K.is_zero(aa) or K.is_zero(bb):
        return K.rejected()
    var mixed = K.sub(
        K.mul(gram_pair8[K](u0, v0), gram_pair8[K](u1, v1)),
        K.mul(gram_pair8[K](u0, v1), gram_pair8[K](u1, v0))
    )
    var den = K.mul(aa, bb)
    if not K.accepted(mixed) or not K.accepted(den) or K.is_zero(den):
        return K.rejected()
    return K.sub(K.one(), K.div(K.mul(mixed, mixed), den))


def guarded_spread8[K: ExactField](
    x: List[K.Element], y: List[K.Element],
    gate: List[K.Element]
) -> Bool:
    """Explicit finite gate membership; rejected/null spreads never pass."""
    var value = spread8[K](x, y)
    if not K.accepted(value):
        return False
    for item in gate:
        if K.accepted(item) and K.eq(item, value):
            return True
    return False


def guarded_gram2_spread8[K: ExactField](
    u0: List[K.Element], u1: List[K.Element],
    v0: List[K.Element], v1: List[K.Element],
    gate: List[K.Element]
) -> Bool:
    var value = gram2_spread8[K](u0, u1, v0, v1)
    if not K.accepted(value):
        return False
    for item in gate:
        if K.accepted(item) and K.eq(item, value):
            return True
    return False


def swap_residual8[K: ExactField](
    state: List[K.Element],
    a: List[K.Element], a_gain: K.Element, a_coord: Int,
    a_shear: List[K.Element],
    b: List[K.Element], b_gain: K.Element, b_coord: Int,
    b_shear: List[K.Element]
) -> List[K.Element]:
    """U_b(U_a(x)) - U_a(U_b(x)); all 8 coefficients matter."""
    var after_a = affine_step8[K](state, a, a_gain, a_coord, a_shear)
    var after_b = affine_step8[K](state, b, b_gain, b_coord, b_shear)
    var ab = affine_step8[K](after_a, b, b_gain, b_coord, b_shear)
    var ba = affine_step8[K](after_b, a, a_gain, a_coord, a_shear)
    return sub8[K](ab, ba)


def swap_equal8[K: ExactField](
    state: List[K.Element],
    a: List[K.Element], a_gain: K.Element, a_coord: Int,
    a_shear: List[K.Element],
    b: List[K.Element], b_gain: K.Element, b_coord: Int,
    b_shear: List[K.Element]
) -> Bool:
    """Whole-vector local effect equality, not null quadratic norm."""
    var residual = swap_residual8[K](
        state, a, a_gain, a_coord, a_shear,
        b, b_gain, b_coord, b_shear
    )
    if not valid8[K](residual):
        return False
    return equal8[K](residual, scale8[K](K.zero(), residual))


def certified_swap8[K: ExactField](
    state: List[K.Element],
    a: List[K.Element], a_gain: K.Element, a_coord: Int,
    a_shear: List[K.Element],
    b: List[K.Element], b_gain: K.Element, b_coord: Int,
    b_shear: List[K.Element],
    gate: List[K.Element],
    direction_rank: Int,
    a_probe: List[K.Element],
    b_probe: List[K.Element]
) -> Bool:
    """Auditable local adjacent-swap admission for ray/rank-two RT.

    Inputs represent the *actual common prefix* state. No certificate
    authorizes any state-dependent swap at other prefix states.
    """
    if direction_rank != 1 and direction_rank != 2:
        return False
    var after_a = affine_step8[K](state, a, a_gain, a_coord, a_shear)
    var after_b = affine_step8[K](state, b, b_gain, b_coord, b_shear)
    if not valid8[K](after_a) or not valid8[K](after_b):
        return False
    var ab = affine_step8[K](after_a, b, b_gain, b_coord, b_shear)
    var ba = affine_step8[K](after_b, a, a_gain, a_coord, a_shear)
    if not valid8[K](ab) or not valid8[K](ba):
        return False
    if not equal8[K](ab, ba):
        return False
    var da = sub8[K](after_a, state)
    var da_after = sub8[K](ba, after_b)
    var db = sub8[K](after_b, state)
    var db_after = sub8[K](ab, after_a)
    if direction_rank == 1:
        return guarded_spread8[K](da, da_after, gate) and guarded_spread8[K](
            db, db_after, gate
        )
    return guarded_gram2_spread8[K](
        da, a_probe, da_after, a_probe, gate
    ) and guarded_gram2_spread8[K](
        db, b_probe, db_after, b_probe, gate
    )
