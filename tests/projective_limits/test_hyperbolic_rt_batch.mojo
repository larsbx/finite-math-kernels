"""Exact batch inverses and spreads against scalar oracle over F3/F5/F7."""
from std.testing import assert_true, assert_false, assert_equal
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import spread8
from projective_limits.hyperbolic_rt_batch import invert_batch_nonzero, spreads_batched


def basis[p: Int64](i: Int, partner: Int64) -> List[Fp[p]]:
    var v = List[Fp[p]]()
    for j in range(8):
        v.append(Fp[p](1 if j == i else (partner if j == i + 4 else 0)))
    return v^


def check[p: Int64]() raises:
    var nums = List[Fp[p]]()
    for v in range(1, 5):
        nums.append(Fp[p](Int64(v % Int(p) if v % Int(p) != 0 else 1)))
    var invs = invert_batch_nonzero[FpField[p]](nums)
    for i in range(len(nums)):
        assert_true(nums[i] * invs[i] == Fp[p](1))
    var bad = List[Fp[p]]()
    bad.append(Fp[p](1))
    bad.append(Fp[p](0))
    assert_false(invert_batch_nonzero[FpField[p]](bad)[0].accepted())
    assert_equal(len(invert_batch_nonzero[FpField[p]](List[Fp[p]]())), 0)

    var xs = List[List[Fp[p]]]()
    var ys = List[List[Fp[p]]]()
    var one = Fp[p](1) / Fp[p](2)
    xs.append(basis[p](0, one.v))
    ys.append(basis[p](1, one.v))
    xs.append(basis[p](0, one.v))
    ys.append(basis[p](0, one.v))
    xs.append(basis[p](0, one.v))
    ys.append(basis[p](0, 0))  # Null: independent rejected result.
    xs.append(basis[p](2, one.v))
    ys.append(basis[p](3, one.v))
    var out = spreads_batched[FpField[p]](xs, ys)
    assert_equal(len(out), 4)
    for i in range(4):
        var baseline = spread8[FpField[p]](xs[i], ys[i])
        assert_equal(out[i].accepted(), baseline.accepted())
        if baseline.accepted():
            assert_true(out[i] == baseline)
    var ys_short = List[List[Fp[p]]]()
    ys_short.append(basis[p](1, one.v))
    var mismatch = spreads_batched[FpField[p]](xs, ys_short)
    assert_equal(len(mismatch), 4)
    assert_false(mismatch[0].accepted())


def main() raises:
    check[3]()
    check[5]()
    check[7]()
    print("[PASS] exact batch spread equals independent scalar, including null guards")
