"""Field-generic exact Grassmann k-spread tests (k=1,2,3,4).

Coherence rank R, tensor order r, and plane dimension k are independent.
All cases are exact finite-field, non-null and denominator guarded.
"""
from std.testing import assert_true, assert_false
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import add8, spread8
from projective_limits.grassmann_k_spread import (
    k_plane_spread8, guarded_k_plane_spread8
)


def axis[p: Int64](i: Int) -> List[Fp[p]]:
    var x = List[Fp[p]]()
    for j in range(8):
        x.append(Fp[p](Int64(1 if i == j else 0)))
    return x^


def unit[p: Int64](i: Int) -> List[Fp[p]]:
    var x = axis[p](i)
    x[i + 4] = Fp[p](1) / Fp[p](2)
    return x^


def check_k_planes[p: Int64]() raises:
    var a = unit[p](0)
    var b = unit[p](1)
    var c = unit[p](2)
    var d = unit[p](3)

    var one_a = List[List[Fp[p]]]()
    one_a.append(a.copy())
    var one_b = List[List[Fp[p]]]()
    one_b.append(b.copy())
    assert_true(k_plane_spread8[FpField[p]](one_a, one_b) ==
                spread8[FpField[p]](a, b))

    # Two bases of the same nondegenerate 3-plane have spread exactly zero.
    var u = List[List[Fp[p]]]()
    u.append(a.copy())
    u.append(b.copy())
    u.append(c.copy())
    var u_changed = List[List[Fp[p]]]()
    u_changed.append(add8[FpField[p]](a, b))
    u_changed.append(b.copy())
    u_changed.append(c.copy())
    assert_true(k_plane_spread8[FpField[p]](u, u_changed) == Fp[p](0))

    # Distinct nondegenerate planes: span(a,b,c) versus span(a+d,b,c).
    # Their diagonal Gram blocks are (1,1,1) and (2,1,1).
    # The cross determinant is 1, giving spread 1-1/2.
    var v = List[List[Fp[p]]]()
    v.append(add8[FpField[p]](a, d))
    v.append(b.copy())
    v.append(c.copy())
    var expected = Fp[p](1) - Fp[p](1) / Fp[p](2)
    var value = k_plane_spread8[FpField[p]](u, v)
    assert_true(value == expected)
    var v_changed = List[List[Fp[p]]]()
    v_changed.append(b.copy())
    v_changed.append(add8[FpField[p]](a, d))
    v_changed.append(c.copy())
    assert_true(k_plane_spread8[FpField[p]](u_changed, v_changed) == value)

    var gate = List[Fp[p]]()
    gate.append(expected)
    assert_true(guarded_k_plane_spread8[FpField[p]](u, v, gate))
    var rejects = List[Fp[p]]()
    rejects.append(Fp[p](0))
    assert_false(guarded_k_plane_spread8[FpField[p]](u, v, rejects))

    # Degenerate/repeated frames are rejected, rather than claiming spread 0.
    var repeated = List[List[Fp[p]]]()
    repeated.append(a.copy())
    repeated.append(a.copy())
    repeated.append(c.copy())
    assert_false(k_plane_spread8[FpField[p]](repeated, v).accepted())
    assert_false(guarded_k_plane_spread8[FpField[p]](repeated, v, gate))

    # A nontrivial basis change of the complete four-plane is still span-equal.
    var full = List[List[Fp[p]]]()
    full.append(a.copy())
    full.append(b.copy())
    full.append(c.copy())
    full.append(d.copy())
    var changed = List[List[Fp[p]]]()
    changed.append(add8[FpField[p]](a, b))
    changed.append(b.copy())
    changed.append(c.copy())
    changed.append(d.copy())
    assert_true(k_plane_spread8[FpField[p]](full, changed) == Fp[p](0))

    var bad_dim = List[List[Fp[p]]]()
    assert_false(k_plane_spread8[FpField[p]](bad_dim, bad_dim).accepted())
    assert_false(k_plane_spread8[FpField[p]](full, u).accepted())


def main() raises:
    check_k_planes[3]()
    check_k_planes[5]()
    check_k_planes[7]()
    print("[PASS] exact Grassmann k=1/3/4 spread, basis invariance, guard failures F3/F5/F7")
