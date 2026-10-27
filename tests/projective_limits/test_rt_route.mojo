"""Exact RT route operator and Grassmann direction kernel regressions.

This tests mathematical kernels only; no JSON, optimizer provenance,
P6 topology, or floating-point training semantics is asserted.
"""
from std.testing import assert_true, assert_false
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import (
    add8, equal8, norm8, scale8, spread8
)
from projective_limits.rt_route import (
    affine_step8, gram2_spread8, guarded_spread8,
    swap_residual8, swap_equal8, certified_swap8
)


def axis[p: Int64](i: Int) -> List[Fp[p]]:
    var x = List[Fp[p]]()
    for j in range(8):
        x.append(Fp[p](Int64(1 if i == j else 0)))
    return x^


def zero8[p: Int64]() -> List[Fp[p]]:
    var x = List[Fp[p]]()
    for _ in range(8):
        x.append(Fp[p](0))
    return x^


def direction[p: Int64](i: Int) -> List[Fp[p]]:
    var out = axis[p](i)
    out[i + 4] = Fp[p](1) / Fp[p](2)
    return out^


def test_f5_state_dependent_vs_geometry() raises:
    var x = zero8[5]()
    var d0 = direction[5](0)
    var d1 = direction[5](1)
    var d2 = direction[5](2)
    var d3 = direction[5](3)
    var zeros = zero8[5]()
    var nonnull_residual = axis[5](0)
    var gate = List[Fp[5]]()
    gate.append(Fp[5](0))
    # Pure translations commute exactly and pass projective direction spread.
    var res = swap_residual8[FpField[5]](
        x, d0, Fp[5](0), 1, zeros,
        d1, Fp[5](0), 1, zeros
    )
    assert_true(equal8[FpField[5]](res, zeros))
    assert_true(swap_equal8[FpField[5]](
        x, d0, Fp[5](0), 1, zeros,
        d1, Fp[5](0), 1, zeros
    ))
    assert_true(certified_swap8[FpField[5]](
        x, d0, Fp[5](0), 1, zeros,
        d1, Fp[5](0), 1, zeros,
        gate, 1, d2, d3
    ))
    assert_true(certified_swap8[FpField[5]](
        x, d0, Fp[5](0), 1, zeros,
        d1, Fp[5](0), 1, zeros,
        gate, 2, d2, d3
    ))

    # U0(x) = x + (1+x[1])d0; U1(x)=x+d1.
    # The directions are projectively parallel (spread 0), but U0 and U1
    # differ by a nonzero exact vector when transposed.
    var changed = swap_residual8[FpField[5]](
        x, d0, Fp[5](1), 1, zeros,
        d1, Fp[5](0), 1, zeros
    )
    assert_false(equal8[FpField[5]](changed, zeros))
    assert_true(guarded_spread8[FpField[5]](
        d0, scale8[FpField[5]](Fp[5](2), d0), gate
    ))
    assert_false(certified_swap8[FpField[5]](
        x, d0, Fp[5](1), 1, zeros,
        d1, Fp[5](0), 1, zeros,
        gate, 1, d2, d3
    ))
    assert_false(certified_swap8[FpField[5]](
        x, d0, Fp[5](1), 1, zeros,
        d1, Fp[5](0), 1, zeros,
        gate, 2, d2, d3
    ))

    # A nonzero *null* residual must never be conflated with the zero vector.
    var null_defect = swap_residual8[FpField[5]](
        x, d0, Fp[5](0), 1, nonnull_residual,
        d1, Fp[5](0), 1, zeros
    )
    assert_false(equal8[FpField[5]](null_defect, zeros))
    assert_true(norm8[FpField[5]](null_defect).is_zero())
    assert_false(swap_equal8[FpField[5]](
        x, d0, Fp[5](0), 1, nonnull_residual,
        d1, Fp[5](0), 1, zeros
    ))

    # A null offset is rejected rather than treated as an allowed influence.
    var bad = affine_step8[FpField[5]](
        x, axis[5](0), Fp[5](0), 1, zeros
    )
    assert_false(bad[0].accepted())
    bad = affine_step8[FpField[5]](
        x, d0, Fp[5](0), 8, zeros
    )
    assert_false(bad[0].accepted())
    assert_false(certified_swap8[FpField[5]](
        x, d0, Fp[5](0), 1, zeros, d1, Fp[5](0), 1, zeros,
        gate, 3, d2, d3
    ))


def test_gram_two_basis_invariance() raises:
    var a = direction[5](0)
    var b = direction[5](1)
    var c = direction[5](2)
    var u = add8[FpField[5]](a, c)
    var v = add8[FpField[5]](b, c)
    var baseline = gram2_spread8[FpField[5]](a, b, u, v)
    assert_true(baseline.accepted())
    var changed = gram2_spread8[FpField[5]](
        add8[FpField[5]](a, b), b, v, u
    )
    assert_true(changed == baseline)
    assert_true(gram2_spread8[FpField[5]](a, b, a, b) == Fp[5](0))
    assert_false(gram2_spread8[FpField[5]](a, a, u, v).accepted())
    assert_false(gram2_spread8[FpField[5]](a, b, a, a).accepted())
    assert_false(spread8[FpField[5]](axis[5](0), a).accepted())


def test_other_odd_prime_field() raises:
    var x = direction[7](0)
    var y = direction[7](1)
    var z = zero8[7]()
    assert_true(swap_equal8[FpField[7]](
        z, x, Fp[7](0), 1, z,
        y, Fp[7](0), 1, z
    ))
    var gate = List[Fp[7]]()
    gate.append(Fp[7](0))
    assert_true(certified_swap8[FpField[7]](
        z, x, Fp[7](0), 1, z,
        y, Fp[7](0), 1, z,
        gate, 1, x, y
    ))


def main() raises:
    test_f5_state_dependent_vs_geometry()
    print("[PASS] exact F5 updates, RT guards and null residual")
    test_gram_two_basis_invariance()
    print("[PASS] rank-two guarded Gram direction adapter")
    test_other_odd_prime_field()
    print("[PASS] field-generic F7 update specialization")
