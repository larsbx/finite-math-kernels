"""Exact Gram minors, faithful planarity and projective degeneracy.

The Gram-null but non-planar counterexample is essential: an isotropic
radical in the span makes the restricted form degenerate without reducing
the dimension of the span. Tests use the upstream ExactField/FpField.
"""
from std.testing import assert_true, assert_false
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import (
    add8, norm8, scale8, spread8
)
from projective_limits.gram_geometry import (
    gram_pair8, gram2_determinant8, gram3_determinant8,
    normalized_gram3_determinant8, minor3_at, rank_le_two8,
    planar_triple_spread_defect8, unrestricted_triple_spread_defect8,
    gram_triple_spread_defect8
)


def axis[p: Int64](i: Int) -> List[Fp[p]]:
    var out = List[Fp[p]]()
    for j in range(8):
        out.append(Fp[p](Int64(1 if i == j else 0)))
    return out^


def norm_one[p: Int64](i: Int) -> List[Fp[p]]:
    var v = axis[p](i)
    v[i + 4] = Fp[p](1) / Fp[p](2)
    return v^


def check_gram_field[p: Int64]() raises:
    var x = norm_one[p](0)
    var y = norm_one[p](1)
    var z = norm_one[p](2)
    var xy = add8[FpField[p]](x, y)
    var xyz = add8[FpField[p]](xy, axis[p](2))

    assert_true(gram_pair8[FpField[p]](x, x) == norm8[FpField[p]](x))
    assert_true(gram_pair8[FpField[p]](x, y).is_zero())
    assert_true(gram2_determinant8[FpField[p]](x, y) == Fp[p](1))
    assert_true(gram3_determinant8[FpField[p]](x, y, z) == Fp[p](1))
    assert_true(normalized_gram3_determinant8[FpField[p]](x, y, z) == Fp[p](1))

    # True planar triple: coordinate-rank test succeeds and guarded identity 0.
    assert_true(rank_le_two8[FpField[p]](x, y, xy) == Fp[p](1))
    assert_true(gram3_determinant8[FpField[p]](x, y, xy).is_zero())
    assert_true(planar_triple_spread_defect8[FpField[p]](x, y, xy).is_zero())

    # Non-planar, three mutually orthogonal non-null rays.
    assert_true(rank_le_two8[FpField[p]](x, y, z) == Fp[p](0))
    assert_false(planar_triple_spread_defect8[FpField[p]](x, y, z).accepted())

    # Gram null does NOT mean planar: xyz = x + y + isotropic e_2,
    # with e_2 orthogonal to x and y. Rank is THREE, Gram determinant zero.
    assert_true(norm8[FpField[p]](xyz) == Fp[p](2))
    assert_true(gram3_determinant8[FpField[p]](x, y, xyz).is_zero())
    assert_true(rank_le_two8[FpField[p]](x, y, xyz) == Fp[p](0))
    assert_false(planar_triple_spread_defect8[FpField[p]](x, y, xyz).accepted())

    # The unrestricted defect equals an independent Gram expression.
    # Orthogonal independent triples have (1,1,1) spreads: defect -1.
    assert_true(unrestricted_triple_spread_defect8[FpField[p]](x, y, z) == Fp[p](-1))
    assert_true(gram_triple_spread_defect8[FpField[p]](x, y, z) == Fp[p](-1))
    assert_true(unrestricted_triple_spread_defect8[FpField[p]](x, y, xy).is_zero())
    assert_true(gram_triple_spread_defect8[FpField[p]](x, y, xy).is_zero())

    # Gram-null does not imply planar, and does force defect zero.
    assert_true(unrestricted_triple_spread_defect8[FpField[p]](x, y, xyz).is_zero())
    assert_true(gram_triple_spread_defect8[FpField[p]](x, y, xyz).is_zero())

    # More subtle: nonplanar, NONZERO Gram determinant, but still
    # triple spread defect zero. x, x+e1, -x+2f1 have norms 1,
    # pairings (1,1,-1) and Gram determinant -4.
    var x_plus_e1 = add8[FpField[p]](x, axis[p](1))
    var minus_x = scale8[FpField[p]](Fp[p](-1), x)
    var z_exception = add8[FpField[p]](
        minus_x, scale8[FpField[p]](Fp[p](2), axis[p](5))
    )
    assert_true(norm8[FpField[p]](x_plus_e1) == Fp[p](1))
    assert_true(norm8[FpField[p]](z_exception) == Fp[p](1))
    assert_true(rank_le_two8[FpField[p]](x, x_plus_e1, z_exception) == Fp[p](0))
    assert_true(gram3_determinant8[FpField[p]](x, x_plus_e1, z_exception) == Fp[p](-4))
    assert_true(unrestricted_triple_spread_defect8[FpField[p]](
        x, x_plus_e1, z_exception
    ).is_zero())
    assert_true(gram_triple_spread_defect8[FpField[p]](
        x, x_plus_e1, z_exception
    ).is_zero())

    # Distinct non-null rays spanning a tangent line: absolute double
    # intersection. Ordinary two-reference cross ratio cannot be assumed.
    var tangent = add8[FpField[p]](x, axis[p](2))
    assert_true(norm8[FpField[p]](tangent) == Fp[p](1))
    assert_true(gram2_determinant8[FpField[p]](x, tangent).is_zero())
    assert_true(spread8[FpField[p]](x, tangent) == Fp[p](0))

    # Exterior rank is basis-independent under invertible coordinate changes.
    # Scaling non-null projective representatives leaves normalized Gram fixed.
    var scale = Fp[p](2)
    var new_x = scale8[FpField[p]](scale, x)
    var new_z = scale8[FpField[p]](scale, z)
    assert_true(normalized_gram3_determinant8[FpField[p]](new_x, y, new_z) == Fp[p](1))
    assert_true(rank_le_two8[FpField[p]](new_x, y, new_z) == Fp[p](0))

    # Null vectors prevent normalization, but do NOT invalidate polynomial ranks.
    assert_false(normalized_gram3_determinant8[FpField[p]](axis[p](0), y, z).accepted())
    assert_false(unrestricted_triple_spread_defect8[FpField[p]](axis[p](0), y, z).accepted())
    assert_false(gram_triple_spread_defect8[FpField[p]](axis[p](0), y, z).accepted())
    assert_false(planar_triple_spread_defect8[FpField[p]](axis[p](0), y, xy).accepted())
    assert_false(minor3_at[FpField[p]](x, y, z, 1, 1, 2).accepted())


def main() raises:
    check_gram_field[3]()
    check_gram_field[5]()
    check_gram_field[7]()
    print("[PASS] Gram minors, tangent and radical falsifiers, exact planar guard")
