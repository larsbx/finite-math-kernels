"""Replay 18 independently generated Gram/exterior RT vectors in Mojo.

The source corpus is independently computed by Python from coordinate
3-minors. It covers planar, independent, isotropic-radical, tangent,
null-ray and proportional configurations at p=3,5,7.
"""
from std.testing import assert_true, assert_false, assert_equal
from finite_exact.fp import Fp, FpField
from projective_limits.gram_geometry import (
    gram2_determinant8, gram3_determinant8,
    normalized_gram3_determinant8, rank_le_two8,
    planar_triple_spread_defect8
)

comptime FIXTURE = "conformance/gram_geometry_v1.txt"


def vector[p: Int64](s: String) raises -> List[Fp[p]]:
    var out = List[Fp[p]]()
    for item in s.split(","):
        out.append(Fp[p](Int64(Int(item))))
    assert_equal(len(out), 8)
    return out^


def expected[p: Int64](value: Fp[p], want: String) raises:
    if want == "rejected":
        assert_false(value.accepted())
    else:
        assert_true(value == Fp[p](Int64(Int(want))))


def replay[p: Int64](cols: List[String]) raises:
    var x = vector[p](cols[3])
    var y = vector[p](cols[4])
    var z = vector[p](cols[5])
    expected[p](gram2_determinant8[FpField[p]](x, y), cols[6])
    expected[p](gram3_determinant8[FpField[p]](x, y, z), cols[7])
    expected[p](rank_le_two8[FpField[p]](x, y, z), cols[8])
    expected[p](normalized_gram3_determinant8[FpField[p]](x, y, z), cols[9])
    expected[p](planar_triple_spread_defect8[FpField[p]](x, y, z), cols[10])


def main() raises:
    var count = 0
    for raw in open(FIXTURE, "r").read().split("\n"):
        var line = String(raw)
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        var cols = List[String]()
        for col in line.split("\t"):
            cols.append(String(col))
        assert_equal(len(cols), 11)
        assert_true(cols[0] == "case")
        var p = Int(cols[1])
        if p == 3:
            replay[3](cols)
        elif p == 5:
            replay[5](cols)
        elif p == 7:
            replay[7](cols)
        else:
            raise Error("unrecognized field modulus in Gram vector fixture")
        count += 1
    assert_equal(count, 18)
    print("[PASS] 18 exact independent Gram/rank conformance vectors")
