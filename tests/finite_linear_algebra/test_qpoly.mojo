"""Regressions for finite_linear_algebra/qpoly.mojo and the general charpoly.

Specification: docs/exact-polynomial-root-isolation-spec.md. Every constant
pinned here is also pinned by tests/finite_linear_algebra/test_qpoly_reference.py,
so the kernel and its oracle agree on every value rather than merely on a
shape.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.rat_q import Q
from finite_linear_algebra.mat3 import Mat3
from finite_linear_algebra.qpoly import (
    charpoly,
    degree,
    derivative,
    divide,
    evaluate,
    gcd,
    largest_root_bracket,
    mul,
    normalize,
    root_bound,
    sign_variations,
    squarefree_part,
    sturm_chain,
    sub,
    variation_difference,
)
from finite_linear_algebra.scalar import q_int, q_vec

comptime BRACKET_STEPS = 256


def width() -> Q:
    return Q(1, 1 << 20)


def poly(c: List[Int]) -> List[Q]:
    return normalize(q_vec(c))


def matrix(rows: List[List[Int]]) -> List[List[Q]]:
    var out = List[List[Q]]()
    for i in range(len(rows)):
        out.append(q_vec(rows[i]))
    return out^


def fibonacci_matrix() -> List[List[Q]]:
    var rows: List[List[Int]] = [[1, 1], [1, 0]]
    return matrix(rows)


def tribonacci_matrix() -> List[List[Q]]:
    var rows: List[List[Int]] = [[1, 1, 1], [1, 0, 0], [0, 1, 0]]
    return matrix(rows)


def all_ones_two() -> List[List[Q]]:
    var rows: List[List[Int]] = [[1, 1], [1, 1]]
    return matrix(rows)


def assert_poly(p: List[Q], expected: List[Int]) raises:
    assert_equal(len(p), len(expected))
    for i in range(len(expected)):
        assert_true(p[i].eq(q_int(expected[i])))


def test_normalization_and_degree() raises:
    var trailing: List[Int] = [1, 2, 0, 0]
    assert_equal(degree(poly(trailing)), 1)
    var zero: List[Int] = [0, 0]
    assert_equal(degree(poly(zero)), -1)
    var constant: List[Int] = [7]
    assert_equal(len(derivative(poly(constant))), 0)


def test_division_is_exact_over_the_field() raises:
    var cube: List[Int] = [-1, 0, 0, 1]
    var linear: List[Int] = [-1, 1]
    var result = divide(poly(cube), poly(linear))
    assert_false(result.rejected)
    var expected: List[Int] = [1, 1, 1]
    assert_poly(result.quotient, expected)
    assert_equal(len(result.remainder), 0)
    assert_poly(mul(result.quotient, poly(linear)), cube)


def test_division_by_zero_refuses() raises:
    var cube: List[Int] = [-1, 0, 0, 1]
    var nothing = List[Q]()
    assert_true(divide(poly(cube), nothing).rejected)


def test_gcd_is_monic_and_the_squarefree_part_simplifies() raises:
    var difference: List[Int] = [-1, 0, 1]
    var linear: List[Int] = [-1, 1]
    assert_poly(gcd(poly(difference), poly(linear)), linear)
    var square: List[Int] = [1, -2, 1]
    assert_poly(squarefree_part(poly(square)), linear)


def test_the_root_bound_is_rational_and_above_every_root() raises:
    var golden: List[Int] = [-1, -1, 1]
    var tribonacci: List[Int] = [-1, -1, -1, 1]
    assert_true(root_bound(poly(golden)).eq(q_int(2)))
    assert_true(root_bound(poly(tribonacci)).eq(q_int(2)))


def test_the_sturm_chain_and_its_variations() raises:
    var golden: List[Int] = [-1, -1, 1]
    var chain = sturm_chain(poly(golden))
    assert_equal(len(chain), 3)
    var last = chain[2].copy()
    assert_equal(len(last), 1)
    assert_true(last[0].eq(Q(5, 4)))
    assert_equal(sign_variations(chain, q_int(-2)), 2)
    assert_equal(sign_variations(chain, q_int(2)), 0)
    assert_equal(variation_difference(chain, q_int(-2), q_int(2)), 2)


def assert_bracket(p: List[Q], lo: Q, hi: Q) raises:
    """A pinned bracket, plus the sign change it is required to carry."""
    var bracket = largest_root_bracket(p, width(), BRACKET_STEPS)
    assert_true(bracket.found)
    assert_false(bracket.exact)
    assert_true(bracket.lo.eq(lo))
    assert_true(bracket.hi.eq(hi))
    var square_free = squarefree_part(p)
    var left = evaluate(square_free, bracket.lo)
    var right = evaluate(square_free, bracket.hi)
    assert_true(left.mul(right).lt(Q.zero()))


def test_the_golden_and_tribonacci_brackets() raises:
    var golden: List[Int] = [-1, -1, 1]
    assert_bracket(poly(golden), Q(1696631, 1048576), Q(212079, 131072))
    var tribonacci: List[Int] = [-1, -1, -1, 1]
    assert_bracket(poly(tribonacci), Q(1928631, 1048576), Q(241079, 131072))


def test_the_chebyshev_transition_matrix_brackets_two() raises:
    var characteristic = charpoly(all_ones_two())
    var expected: List[Int] = [0, -2, 1]
    assert_poly(characteristic, expected)
    assert_bracket(characteristic, Q(4194303, 2097152), Q(8388609, 4194304))


def test_an_exact_rational_root_is_returned_as_itself() raises:
    var linear: List[Int] = [-1, 1]
    var bracket = largest_root_bracket(poly(linear), width(), BRACKET_STEPS)
    assert_true(bracket.found)
    assert_true(bracket.exact)
    assert_true(bracket.lo.eq(Q.one()))
    assert_true(bracket.hi.eq(Q.one()))


def test_a_repeated_root_still_isolates() raises:
    var square: List[Int] = [1, -2, 1]
    assert_bracket(poly(square), Q(4194303, 4194304), Q(2097153, 2097152))


def test_no_real_root_is_a_refusal_not_a_bracket() raises:
    var irreducible: List[Int] = [1, 0, 1]
    assert_false(largest_root_bracket(poly(irreducible), width(), BRACKET_STEPS).found)
    var constant: List[Int] = [5]
    assert_false(largest_root_bracket(poly(constant), width(), BRACKET_STEPS).found)


def test_a_capped_bisection_refuses() raises:
    """Fail closed: too few steps is inconclusive, never "no root"."""
    var golden: List[Int] = [-1, -1, 1]
    assert_false(largest_root_bracket(poly(golden), width(), 3).found)


def test_the_general_charpoly_agrees_with_the_three_by_three_closed_form() raises:
    var entries: List[Int] = [1, 1, 1, 1, 0, 0, 0, 1, 0]
    var closed = Mat3(entries).charpoly()
    var general = charpoly(tribonacci_matrix())
    assert_equal(len(general), len(closed))
    for i in range(len(closed)):
        assert_true(general[i].eq(q_int(closed[i])))


def test_the_general_charpoly_in_other_dimensions() raises:
    var fibonacci: List[Int] = [-1, -1, 1]
    assert_poly(charpoly(fibonacci_matrix()), fibonacci)
    var identity: List[List[Int]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    var expected: List[Int] = [-1, 3, -3, 1]
    assert_poly(charpoly(matrix(identity)), expected)
    var empty = List[List[Q]]()
    var one: List[Int] = [1]
    assert_poly(charpoly(empty), one)


def test_the_matrix_satisfies_its_own_characteristic_polynomial_at_its_root() raises:
    """The bracket's endpoints straddle a root, so the polynomial changes sign."""
    var characteristic = charpoly(fibonacci_matrix())
    var bracket = largest_root_bracket(characteristic, width(), BRACKET_STEPS)
    var left = evaluate(characteristic, bracket.lo)
    var right = evaluate(characteristic, bracket.hi)
    assert_true(left.mul(right).lt(Q.zero()))
    assert_equal(len(sub(characteristic, characteristic)), 0)


def main() raises:
    test_normalization_and_degree()
    print("[PASS]", "test_normalization_and_degree")
    test_division_is_exact_over_the_field()
    print("[PASS]", "test_division_is_exact_over_the_field")
    test_division_by_zero_refuses()
    print("[PASS]", "test_division_by_zero_refuses")
    test_gcd_is_monic_and_the_squarefree_part_simplifies()
    print("[PASS]", "test_gcd_is_monic_and_the_squarefree_part_simplifies")
    test_the_root_bound_is_rational_and_above_every_root()
    print("[PASS]", "test_the_root_bound_is_rational_and_above_every_root")
    test_the_sturm_chain_and_its_variations()
    print("[PASS]", "test_the_sturm_chain_and_its_variations")
    test_the_golden_and_tribonacci_brackets()
    print("[PASS]", "test_the_golden_and_tribonacci_brackets")
    test_the_chebyshev_transition_matrix_brackets_two()
    print("[PASS]", "test_the_chebyshev_transition_matrix_brackets_two")
    test_an_exact_rational_root_is_returned_as_itself()
    print("[PASS]", "test_an_exact_rational_root_is_returned_as_itself")
    test_a_repeated_root_still_isolates()
    print("[PASS]", "test_a_repeated_root_still_isolates")
    test_no_real_root_is_a_refusal_not_a_bracket()
    print("[PASS]", "test_no_real_root_is_a_refusal_not_a_bracket")
    test_a_capped_bisection_refuses()
    print("[PASS]", "test_a_capped_bisection_refuses")
    test_the_general_charpoly_agrees_with_the_three_by_three_closed_form()
    print("[PASS]", "test_the_general_charpoly_agrees_with_the_three_by_three_closed_form")
    test_the_general_charpoly_in_other_dimensions()
    print("[PASS]", "test_the_general_charpoly_in_other_dimensions")
    test_the_matrix_satisfies_its_own_characteristic_polynomial_at_its_root()
    print("[PASS]", "test_the_matrix_satisfies_its_own_characteristic_polynomial_at_its_root")
    print("15 qpoly tests passed.")
