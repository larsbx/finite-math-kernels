"""Exact tests of the domain-neutral chromogeometry kernel.

Run: mojo run -I kernel tests/chromogeometry/test_chromogeometry.mojo.
Verified here over F_7 and F_13, with denominator rejection.
"""

from std.testing import assert_false, assert_true

from finite_exact.fp import Fp, FpField
from finite_exact.field import QField
from finite_exact.rat_q import Q
from chromogeometry.chromatic import (
    ChromoVec2, chromo_blue, chromo_red, chromo_green,
    chromo_blue_spread, chromo_red_spread, chromo_green_spread,
    chromo_pythagoras, chromo_harmonic_spread,
    chromo_gram_identity, chromo_det,
)


def finite_vectors[p: Int64]() raises:
    for a in range(Int(p)):
        for b in range(Int(p)):
            var u = ChromoVec2[FpField[p]](Fp[p](Int64(a)), Fp[p](Int64(b)))
            assert_true(chromo_pythagoras(u))
            for c in range(Int(p)):
                for d in range(Int(p)):
                    var v = ChromoVec2[FpField[p]](Fp[p](Int64(c)), Fp[p](Int64(d)))
                    assert_true(chromo_gram_identity(u, v, 0))
                    assert_true(chromo_gram_identity(u, v, 1))
                    assert_true(chromo_gram_identity(u, v, 2))
                    assert_false(chromo_gram_identity(u, v, 3))
                    var sb = chromo_blue_spread(u, v)
                    var sr = chromo_red_spread(u, v)
                    var sg = chromo_green_spread(u, v)
                    assert_equal_guard(sb.accepted(), (chromo_blue(u)*chromo_blue(v)).v != 0)
                    assert_equal_guard(sr.accepted(), (chromo_red(u)*chromo_red(v)).v != 0)
                    assert_equal_guard(sg.accepted(), (chromo_green(u)*chromo_green(v)).v != 0)
                    if sb.accepted() and sr.accepted() and sg.accepted() and (
                        not sb.is_zero() and not sr.is_zero() and not sg.is_zero()
                    ):
                        assert_true(chromo_harmonic_spread(u, v))


def assert_equal_guard(x: Bool, y: Bool) raises:
    assert_true(x == y)


def test_rational_field() raises:
    var u = ChromoVec2[QField](Q(1, 1), Q(2, 1))
    var v = ChromoVec2[QField](Q(2, 1), Q(1, 1))
    assert_true(chromo_pythagoras(u))
    assert_true(chromo_gram_identity(u, v, 0))
    assert_true(chromo_gram_identity(u, v, 1))
    assert_true(chromo_gram_identity(u, v, 2))
    assert_true(chromo_harmonic_spread(u, v))
    var null_green = ChromoVec2[QField](Q.one(), Q.zero())
    assert_false(chromo_green_spread(u, null_green).accepted())
    var null_red = ChromoVec2[QField](Q.one(), Q.one())
    assert_false(chromo_red_spread(u, null_red).accepted())


def main() raises:
    finite_vectors[7]()
    finite_vectors[13]()
    test_rational_field()
    print("Chromogeometry field-generic laws passed: F_7, F_13, Q.")
