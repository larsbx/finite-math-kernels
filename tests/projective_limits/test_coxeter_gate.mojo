"""Finite-field Coxeter 2-face gates: all boundary swaps use current source."""
from std.testing import assert_true, assert_false
from finite_exact.fp import Fp, FpField
from projective_limits.coxeter_gate import (
    valid_ordering, adjacent_swap, same_ordering,
    swap_gate_at_source8, coxeter_square_gate8, coxeter_hexagon_gate8
)


def hyperbolic_direction[p: Int64](i: Int) -> List[Fp[p]]:
    var d = List[Fp[p]]()
    for k in range(8):
        d.append(Fp[p](Int64(1 if k == i else 0)))
    d[i + 4] = Fp[p](1) / Fp[p](2)
    return d^


def order3() -> List[Int]:
    var a = List[Int]()
    a.append(0)
    a.append(1)
    a.append(2)
    return a^


def order4() -> List[Int]:
    var a = List[Int]()
    for i in range(4):
        a.append(i)
    return a^


def test_hexagon_f5() raises:
    var ds = List[List[Fp[5]]]()
    ds.append(hyperbolic_direction[5](0))
    ds.append(hyperbolic_direction[5](1))
    ds.append(hyperbolic_direction[5](2))
    var ones = List[Fp[5]]()
    ones.append(Fp[5](1))
    var zeros = List[Fp[5]]()
    zeros.append(Fp[5](0))
    var both = List[Fp[5]]()
    both.append(Fp[5](0))
    both.append(Fp[5](1))
    var p = order3()
    assert_true(coxeter_hexagon_gate8[FpField[5]](ds, p, 0, ones))
    assert_false(coxeter_hexagon_gate8[FpField[5]](ds, p, 0, zeros))
    assert_false(coxeter_hexagon_gate8[FpField[5]](ds, p, 1, ones))
    assert_true(swap_gate_at_source8[FpField[5]](ds, p, 0, ones))
    assert_false(swap_gate_at_source8[FpField[5]](ds, p, 3, ones))
    assert_true(valid_ordering(p, 3))
    var invalid = List[Int]()
    invalid.append(0)
    invalid.append(0)
    invalid.append(2)
    assert_false(valid_ordering(invalid, 3))
    assert_false(coxeter_hexagon_gate8[FpField[5]](ds, invalid, 0, both))
    var switched = adjacent_swap(p, 0)
    assert_true(switched[0] == 1 and switched[1] == 0)
    assert_false(same_ordering(switched, p))

    # One admitted pair (0,1) is insufficient: hexagon also swaps (0,2),(1,2).
    var partial = List[List[Fp[5]]]()
    partial.append(hyperbolic_direction[5](0))
    partial.append(hyperbolic_direction[5](0))
    partial.append(hyperbolic_direction[5](2))
    assert_false(coxeter_hexagon_gate8[FpField[5]](partial, p, 0, zeros))
    assert_true(coxeter_hexagon_gate8[FpField[5]](partial, p, 0, both))


def test_square_f7() raises:
    var ds = List[List[Fp[7]]]()
    for i in range(4):
        ds.append(hyperbolic_direction[7](i))
    var gate = List[Fp[7]]()
    gate.append(Fp[7](1))
    var p = order4()
    assert_true(coxeter_square_gate8[FpField[7]](ds, p, 0, 2, gate))
    assert_false(coxeter_square_gate8[FpField[7]](ds, p, 0, 1, gate))
    assert_false(coxeter_square_gate8[FpField[7]](ds, p, 2, 0, gate))
    var no = List[Fp[7]]()
    no.append(Fp[7](0))
    assert_false(coxeter_square_gate8[FpField[7]](ds, p, 0, 2, no))


def main() raises:
    test_hexagon_f5()
    print("[PASS] F5 hexagon source-state gating and negative controls")
    test_square_f7()
    print("[PASS] F7 square/far-commutativity gating")
