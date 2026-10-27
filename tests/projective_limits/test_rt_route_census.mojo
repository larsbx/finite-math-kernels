"""Independent Mojo reconstruction of the bounded six-event F5 route experiment.

720 permutations, 1800 adjacent-swap contexts, 3 exact update models.
Only RT geometry and local exact effects are compiled in Mojo here; P6
cellular topology and JSON receipts remain consumer-specific. No floats.
"""
from std.testing import assert_equal, assert_true
from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import add8, sub8, norm8, equal8
from projective_limits.rt_route import (
    affine_step8, guarded_spread8, guarded_gram2_spread8
)


def zero8() -> List[Fp[5]]:
    var out = List[Fp[5]]()
    for _ in range(8):
        out.append(Fp[5](0))
    return out^


def direction6(label: Int) -> List[Fp[5]]:
    var v = zero8()
    var half = Fp[5](1) / Fp[5](2)
    if label < 4:
        v[label] = Fp[5](1)
        v[label + 4] = half.copy()
    elif label == 4:
        v[0] = Fp[5](1)
        v[4] = Fp[5](-3)  # -1/2 over F5 = 2
    else:
        v[2] = Fp[5](1)
        v[3] = Fp[5](1)
        v[6] = half.copy()
        v[7] = half.copy()
    return v^


def factorial(n: Int) -> Int:
    var result = 1
    for k in range(2, n + 1):
        result *= k
    return result


def route6(index: Int) -> List[Int]:
    """Unrank one permutation of 0..5, in deterministic lex order."""
    var used = List[Bool]()
    var result = List[Int]()
    for _ in range(6):
        used.append(False)
    var remaining = index
    for position in range(6):
        var place = factorial(5 - position)
        var ordinal = remaining // place
        remaining %= place
        var available = 0
        var chosen = -1
        for label in range(6):
            if not used[label]:
                if available == ordinal:
                    chosen = label
                    break
                available += 1
        if chosen < 0:
            return List[Int]()
        result.append(chosen)
        used[chosen] = True
    return result^


def apply(state: List[Fp[5]], label: Int, mode: Int) -> List[Fp[5]]:
    var offset = direction6(label)
    var shear = zero8()
    var gain = Fp[5](0)
    if label == 0 and mode == 1:
        gain = Fp[5](1)
    if label == 0 and mode == 2:
        shear[0] = Fp[5](1)
    return affine_step8[FpField[5]](state, offset, gain, 1, shear)


def run_mode(mode: Int, geometry_rank: Int) raises -> List[Int]:
    var count = 0
    var geometric = 0
    var effect = 0
    var null_nonzero = 0
    var gate = List[Fp[5]]()
    gate.append(Fp[5](0))
    if mode == 2:
        gate.append(Fp[5](3))
    for index in range(720):
        var route = route6(index)
        assert_equal(len(route), 6)
        for position in range(5):
            # Keep only the lexicographically oriented adjacent-swap edge.
            if route[position] > route[position + 1]:
                continue
            count += 1
            var state = zero8()
            for i in range(position):
                state = apply(state, route[i], mode)
            var a = route[position]
            var b = route[position + 1]
            var after_a = apply(state, a, mode)
            var after_b = apply(state, b, mode)
            var after_ab = apply(after_a, b, mode)
            var after_ba = apply(after_b, a, mode)
            var da = sub8[FpField[5]](after_a, state)
            var da_after = sub8[FpField[5]](after_ba, after_b)
            var db = sub8[FpField[5]](after_b, state)
            var db_after = sub8[FpField[5]](after_ab, after_a)
            var passed = False
            if geometry_rank == 1:
                passed = guarded_spread8[FpField[5]](
                    da, da_after, gate
                ) and guarded_spread8[FpField[5]](db, db_after, gate)
            else:
                var aprobe = direction6((a + 1) % 6)
                var bprobe = direction6((b + 1) % 6)
                passed = guarded_gram2_spread8[FpField[5]](
                    da, aprobe, da_after, aprobe, gate
                ) and guarded_gram2_spread8[FpField[5]](
                    db, bprobe, db_after, bprobe, gate
                )
            if passed:
                geometric += 1
            var delta = sub8[FpField[5]](after_ab, after_ba)
            var same = equal8[FpField[5]](after_ab, after_ba)
            if same:
                effect += 1
            elif norm8[FpField[5]](delta).is_zero():
                null_nonzero += 1
    var out = List[Int]()
    out.append(count)
    out.append(geometric)
    out.append(effect)
    out.append(null_nonzero)
    return out^


def main() raises:
    var frozen = run_mode(0, 1)
    assert_equal(frozen[0], 1800)
    assert_equal(frozen[1], 1800)
    assert_equal(frozen[2], 1800)
    assert_equal(frozen[3], 0)
    var coupled = run_mode(1, 1)
    assert_equal(coupled[0], 1800)
    assert_equal(coupled[1], 1800)
    assert_equal(coupled[2], 1680)
    assert_equal(coupled[3], 0)
    var null_defect = run_mode(2, 1)
    assert_equal(null_defect[0], 1800)
    assert_equal(null_defect[1], 1800)
    assert_equal(null_defect[2], 1680)
    assert_equal(null_defect[3], 120)
    var rank_two = run_mode(0, 2)
    assert_equal(rank_two[0], 1800)
    assert_equal(rank_two[1], 1800)
    assert_equal(rank_two[2], 1800)
    print("[PASS] Mojo F5 720 routes / 1800 swaps: frozen, coupled, null residual")
    print("[PASS] Mojo guarded rank-two geometry on all 1800 frozen swaps")
