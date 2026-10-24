"""Shared field-generic split RT tests; classical conformance only.

Run with `pixi run test-projective-limits`.
All tests use the canonical FpField[p] and ExactField arithmetic.
"""
from std.testing import assert_true, assert_false, assert_equal
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import (
    norm8, polar8, spread8, reflection8, equal8, add8, scale8,
    norm_shell_transport8, triple_spread_defect
)


def axis[p: Int64](i: Int, scale: Int64 = 1) -> List[Fp[p]]:
    var out = List[Fp[p]]()
    for j in range(8):
        out.append(Fp[p](scale if j == i else 0))
    return out^


def norm_one[p: Int64](i: Int) -> List[Fp[p]]:
    var v = axis[p](i)
    v[i + 4] = Fp[p](1) / Fp[p](2)
    return v^


def check_fields[p: Int64]() raises:
    var x = norm_one[p](0)
    var y = norm_one[p](1)
    var z = add8[FpField[p]](x, y)
    assert_true(norm8[FpField[p]](x) == Fp[p](1))
    assert_true(norm8[FpField[p]](y) == Fp[p](1))
    assert_true(polar8[FpField[p]](x, y) == Fp[p](0))
    assert_true(spread8[FpField[p]](x, y) == Fp[p](1))
    assert_true(spread8[FpField[p]](scale8[FpField[p]](Fp[p](2), x), y) == Fp[p](1))
    assert_true(not spread8[FpField[p]](axis[p](0), x).accepted())
    assert_false(norm_shell_transport8[FpField[p]](axis[p](0), x)[0].accepted())
    assert_false(reflection8[FpField[p]](x, axis[p](0))[0].accepted())
    assert_true(norm8[FpField[p]](reflection8[FpField[p]](x, y)) == Fp[p](1))
    var sxy = spread8[FpField[p]](x, y)
    var syz = spread8[FpField[p]](y, z)
    var szx = spread8[FpField[p]](z, x)
    assert_true(triple_spread_defect[FpField[p]](sxy, syz, szx).is_zero())
    var w = norm_one[p](2)
    assert_true(spread8[FpField[p]](y, w) == Fp[p](1))
    assert_false(triple_spread_defect[FpField[p]](
        spread8[FpField[p]](x, y),
        spread8[FpField[p]](y, w),
        spread8[FpField[p]](w, x)
    ).is_zero())
    var target = norm_one[p](0)
    # Two-reflection exceptional case: x != target and N(x-target) = 0.
    var special = add8[FpField[p]](target, axis[p](1))
    assert_true(norm8[FpField[p]](special) == Fp[p](1))
    assert_true(equal8[FpField[p]](
        norm_shell_transport8[FpField[p]](special, target), target
    ))


def test_shared_rt_contract() raises:
    check_fields[3]()
    check_fields[5]()
    check_fields[7]()


def test_complete_f3_norm_one_shell() raises:
    var target = norm_one[3](0)
    var count = 0
    for index in range(6561):
        var n = index
        var x = List[Fp[3]]()
        for _ in range(8):
            x.append(Fp[3](Int64(n % 3)))
            n //= 3
        if norm8[FpField[3]](x) != Fp[3](1):
            continue
        assert_true(equal8[FpField[3]](
            norm_shell_transport8[FpField[3]](x, target), target
        ))
        count += 1
    assert_true(count > 0)


def main() raises:
    test_shared_rt_contract()
    print("[PASS] field-generic RT over F3/F5/F7")
    test_complete_f3_norm_one_shell()
    print("[PASS] complete F3^8 norm-one shell")
