"""Regressions for finite_linear_algebra/real_root_isolation.mojo.

Specification: docs/exact-polynomial-root-isolation-spec.md, section 6a.
Every constant pinned here is also pinned by
tests/finite_linear_algebra/test_qpoly_reference.py.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.rat_q import Q
from finite_linear_algebra.qpoly import evaluate, normalize, squarefree_part
from finite_linear_algebra.real_root_isolation import halve_bracket, real_root_brackets, split_point
from finite_linear_algebra.scalar import q_int, q_vec
from finite_linear_algebra.sturm_sequence import RootBracket

comptime STEPS = 256


def width() -> Q:
    return Q(1, 1 << 20)


def poly(c: List[Int]) -> List[Q]:
    return normalize(q_vec(c))


def assert_bracket(p: List[Q], bracket: RootBracket, lo: Q, hi: Q) raises:
    """A pinned bracket, plus the sign change it is required to carry."""
    assert_true(bracket.found)
    assert_false(bracket.exact)
    assert_true(bracket.lo.eq(lo))
    assert_true(bracket.hi.eq(hi))
    assert_true(hi.sub(lo).le(width()))
    var square_free = squarefree_part(p)
    assert_true(evaluate(square_free, lo).mul(evaluate(square_free, hi)).lt(Q.zero()))


def test_both_square_roots_of_two() raises:
    var c: List[Int] = [-2, 0, 1]
    var found = real_root_brackets(poly(c), width(), STEPS)
    assert_false(found.rejected)
    assert_equal(len(found.brackets), 2)
    assert_bracket(poly(c), found.brackets[0], Q(-2965821, 2097152), Q(-5931639, 4194304))
    assert_bracket(poly(c), found.brackets[1], Q(5931639, 4194304), Q(2965821, 2097152))


def test_repeated_and_rational_roots_among_complex_ones() raises:
    # (x - 1)^2 (x - 2) (x^2 + 1) (2x + 1)
    var c: List[Int] = [-2, 1, 4, -6, 8, -7, 2]
    var found = real_root_brackets(poly(c), width(), STEPS)
    assert_false(found.rejected)
    assert_equal(len(found.brackets), 3)
    assert_bracket(poly(c), found.brackets[0], Q(-4194305, 8388608), Q(-1048575, 2097152))
    assert_bracket(poly(c), found.brackets[1], Q(8388605, 8388608), Q(4194305, 4194304))
    assert_bracket(poly(c), found.brackets[2], Q(16777215, 8388608), Q(4194305, 2097152))
    assert_true(found.brackets[0].hi.le(found.brackets[1].lo))
    assert_true(found.brackets[1].hi.le(found.brackets[2].lo))


def test_a_root_at_every_midpoint_is_bracketed_not_returned() raises:
    # x^3 - 3x: the root 0 is the midpoint of every symmetric interval.
    var c: List[Int] = [0, -3, 0, 1]
    var found = real_root_brackets(poly(c), width(), STEPS)
    assert_false(found.rejected)
    assert_equal(len(found.brackets), 3)
    assert_bracket(poly(c), found.brackets[1], Q(-4, 14348907), Q(4, 14348907))
    assert_true(split_point(poly(c), q_int(-1), q_int(1)).eq(Q(-1, 3)))
    var half = halve_bracket(poly(c), q_int(-1), q_int(1))
    assert_true(half.lo.eq(Q(-1, 3)) and half.hi.eq(q_int(1)))


def test_refusals_and_empty_answers() raises:
    assert_true(real_root_brackets(List[Q](), width(), STEPS).rejected)
    var seven: List[Int] = [7]
    var constant = real_root_brackets(poly(seven), width(), STEPS)
    assert_false(constant.rejected)
    assert_equal(len(constant.brackets), 0)
    var definite: List[Int] = [1, 0, 1]
    var none = real_root_brackets(poly(definite), width(), STEPS)
    assert_false(none.rejected)
    assert_equal(len(none.brackets), 0)
    var two: List[Int] = [-2, 0, 1]
    assert_true(real_root_brackets(poly(two), width(), 8).rejected)


def main() raises:
    test_both_square_roots_of_two()
    print("[PASS]", "test_both_square_roots_of_two")
    test_repeated_and_rational_roots_among_complex_ones()
    print("[PASS]", "test_repeated_and_rational_roots_among_complex_ones")
    test_a_root_at_every_midpoint_is_bracketed_not_returned()
    print("[PASS]", "test_a_root_at_every_midpoint_is_bracketed_not_returned")
    test_refusals_and_empty_answers()
    print("[PASS]", "test_refusals_and_empty_answers")
    print("4 real root isolation tests passed.")
