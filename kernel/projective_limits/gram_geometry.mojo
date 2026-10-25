# Exact Gram and exterior-minor geometry for split quadratic eight-spaces.
#
# Companion to projective_limits.hyperbolic_rt, using the SAME ExactField
# arithmetic and quadratic contractions. No square roots, field ordering,
# analytic quantities, or Cayley multiplication. B2/2 is calculated as a
# direct bilinear contraction; characteristic 2 is outside the contract.
#
# Critical distinction: det(Gram(x,y,z)) == 0 need NOT imply that the
# three vectors span a 2-plane in an isotropic higher-dimensional space.
# Coordinate 3-minors are the faithful polynomial rank guard.

from finite_exact.field import ExactField
from projective_limits.hyperbolic_rt import (
    norm8, spread8, triple_spread_defect, valid8
)


def gram_pair8[K: ExactField](
    x: List[K.Element], y: List[K.Element]
) -> K.Element:
    """B2(x,y)/2, computed without division; equals N(x) for y=x."""
    if not valid8[K](x) or not valid8[K](y):
        return K.rejected()
    var result = K.zero()
    for i in range(4):
        result = K.add(
            result,
            K.add(K.mul(x[i], y[i + 4]), K.mul(x[i + 4], y[i]))
        )
    return result


def gram2_determinant8[K: ExactField](
    x: List[K.Element], y: List[K.Element]
) -> K.Element:
    """Determinant of [[N(x), <x,y>],[<x,y>, N(y)]]; no division."""
    var a = norm8[K](x)
    var b = norm8[K](y)
    var c = gram_pair8[K](x, y)
    if not K.accepted(a) or not K.accepted(b) or not K.accepted(c):
        return K.rejected()
    return K.sub(K.mul(a, b), K.mul(c, c))


def gram3_determinant8[K: ExactField](
    x: List[K.Element], y: List[K.Element], z: List[K.Element]
) -> K.Element:
    """The 3x3 Gram determinant; zero is NOT a geometric-planarity test."""
    var nx = norm8[K](x)
    var ny = norm8[K](y)
    var nz = norm8[K](z)
    var a = gram_pair8[K](x, y)
    var b = gram_pair8[K](x, z)
    var c = gram_pair8[K](y, z)
    if not (K.accepted(nx) and K.accepted(ny) and K.accepted(nz)
            and K.accepted(a) and K.accepted(b) and K.accepted(c)):
        return K.rejected()
    var pos = K.mul(K.mul(nx, ny), nz)
    pos = K.add(pos, K.mul(K.from_int(2), K.mul(K.mul(a, b), c)))
    var neg = K.add(
        K.add(K.mul(nx, K.mul(c, c)), K.mul(ny, K.mul(b, b))),
        K.mul(nz, K.mul(a, a))
    )
    return K.sub(pos, neg)


def normalized_gram3_determinant8[K: ExactField](
    x: List[K.Element], y: List[K.Element], z: List[K.Element]
) -> K.Element:
    """Ray invariant det(Gram)/(N(x)N(y)N(z)); non-null guard explicit."""
    var nx = norm8[K](x)
    var ny = norm8[K](y)
    var nz = norm8[K](z)
    if not (K.accepted(nx) and K.accepted(ny) and K.accepted(nz)):
        return K.rejected()
    if K.is_zero(nx) or K.is_zero(ny) or K.is_zero(nz):
        return K.rejected()
    var d = gram3_determinant8[K](x, y, z)
    var product = K.mul(K.mul(nx, ny), nz)
    return K.div(d, product)


def minor3_at[K: ExactField](
    x: List[K.Element], y: List[K.Element], z: List[K.Element],
    i: Int, j: Int, k: Int
) -> K.Element:
    """Coordinate minor of columns x,y,z at rows i,j,k, i<j<k."""
    if not (valid8[K](x) and valid8[K](y) and valid8[K](z)):
        return K.rejected()
    if not (0 <= i and i < j and j < k and k < 8):
        return K.rejected()
    var term1 = K.mul(x[i], K.sub(K.mul(y[j], z[k]), K.mul(y[k], z[j])))
    var term2 = K.mul(y[i], K.sub(K.mul(x[j], z[k]), K.mul(x[k], z[j])))
    var term3 = K.mul(z[i], K.sub(K.mul(x[j], y[k]), K.mul(x[k], y[j])))
    return K.add(K.sub(term1, term2), term3)


def rank_le_two8[K: ExactField](
    x: List[K.Element], y: List[K.Element], z: List[K.Element]
) -> K.Element:
    """Accepted field indicator: 1 for rank <= 2, 0 for rank 3.

    Rejected inputs yield K.rejected(). All 56 coordinate 3-minors are
    checked without division. The result is faithful over EVERY field,
    unlike det(Gram)==0 in a split quadratic geometry.
    """
    if not (valid8[K](x) and valid8[K](y) and valid8[K](z)):
        return K.rejected()
    for i in range(8):
        for j in range(i + 1, 8):
            for k in range(j + 1, 8):
                if not K.is_zero(minor3_at[K](x, y, z, i, j, k)):
                    return K.zero()
    return K.one()


def planar_triple_spread_defect8[K: ExactField](
    x: List[K.Element], y: List[K.Element], z: List[K.Element]
) -> K.Element:
    """Triple spread defect ON the planar, non-null domain only.

    A non-planar triple is rejected rather than silently treating the
    planar formula as an unrestricted identity.
    """
    var rank_guard = rank_le_two8[K](x, y, z)
    if not K.accepted(rank_guard) or K.is_zero(rank_guard):
        return K.rejected()
    var sxy = spread8[K](x, y)
    var syz = spread8[K](y, z)
    var szx = spread8[K](z, x)
    if not (K.accepted(sxy) and K.accepted(syz) and K.accepted(szx)):
        return K.rejected()
    return triple_spread_defect[K](sxy, syz, szx)
