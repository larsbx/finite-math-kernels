"""Regressions for the fibonacci_hamiltonian package.

Specification: docs/fibonacci-hamiltonian-band-edges-spec.md. Every constant
pinned here is also pinned by
tests/fibonacci_hamiltonian/test_band_edges_reference.py, which runs further
levels than this suite does.
"""

from std.testing import assert_equal, assert_false, assert_true

from fibonacci_hamiltonian import (
    Approximant,
    Edge,
    approximant,
    closed_gaps,
    cover,
    gap_bounds,
    inner_bands,
    invariant,
    outer_bands,
    trace_polynomial,
    trace_polynomials,
    trace_value,
)
from finite_exact.closed_interval import IQ
from finite_exact.rat_q import Q, q_abs
from finite_linear_algebra.qpoly import add, charpoly, degree, evaluate, sub
from finite_linear_algebra.scalar import q_int

comptime STEPS = 65536
comptime TOP = 5


def width() -> Q:
    return Q(1, 1 << 20)


def fibonacci(k: Int) -> Int:
    var before = 1
    var here = 1
    for _ in range(k):
        var next = before + here
        before = here
        here = next
    return before


def couplings() -> List[Q]:
    var out = List[Q]()
    out.append(Q(1, 1))
    out.append(Q(1, 2))
    out.append(Q(5, 1))
    out.append(Q(-3, 2))
    return out^


def constant(n: Int) -> List[Q]:
    var out = List[Q]()
    out.append(q_int(n))
    return out^


def same(a: List[Q], b: List[Q]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if not a[i].eq(b[i]):
            return False
    return True


def total(intervals: List[IQ]) -> Q:
    var out = Q.zero()
    for i in range(len(intervals)):
        out = out.add(intervals[i].hi.sub(intervals[i].lo))
    return out^


def assert_poly(p: List[Q], expected: List[Int]) raises:
    assert_equal(len(p), len(expected))
    for i in range(len(expected)):
        assert_true(p[i].eq(q_int(expected[i])))


def assert_edge(edge: Edge, lo: Q, hi: Q, level: Int) raises:
    assert_true(edge.lo.eq(lo))
    assert_true(edge.hi.eq(hi))
    assert_equal(edge.level, level)


def fibonacci_word(k: Int) -> List[Int]:
    """`W_0 = 0`, `W_1 = 1`, `W_(k+1) = W_(k-1) W_k`: where the coupling sits."""
    var before: List[Int] = [0]
    var here: List[Int] = [1]
    for _ in range(k):
        var next = before.copy()
        for i in range(len(here)):
            next.append(here[i])
        before = here^
        here = next^
    return before^


def jacobi(word: List[Int], lam: Q, corner: Int) -> List[List[Q]]:
    """The cyclic tridiagonal matrix of one period, with `corner` closing the cycle."""
    var size = len(word)
    var rows = List[List[Q]]()
    for i in range(size):
        var row = List[Q]()
        for j in range(size):
            var entry = Q.zero()
            if i == j:
                entry = lam.mul(q_int(word[i]))
            elif (i + 1) % size == j or (j + 1) % size == i:
                var wraps = (i == size - 1 and j == 0) or (j == size - 1 and i == 0)
                entry = q_int(corner if wraps else 1)
            row.append(entry^)
        rows.append(row^)
    return rows^


def test_the_first_trace_polynomials() raises:
    var levels = trace_polynomials(3, Q(1, 1))
    assert_equal(len(levels), 4)
    var t0: List[Int] = [0, 1]
    var t1: List[Int] = [-1, 1]
    var t2: List[Int] = [-2, -1, 1]
    var t3: List[Int] = [2, -2, -2, 1]
    assert_poly(levels[0], t0)
    assert_poly(levels[1], t1)
    assert_poly(levels[2], t2)
    assert_poly(levels[3], t3)
    var half = trace_polynomial(2, Q(1, 2))
    assert_true(half[0].eq(q_int(-2)) and half[1].eq(Q(-1, 2)) and half[2].eq(q_int(1)))
    assert_equal(len(trace_polynomial(-1, Q(1, 1))), 0)


def test_degree_invariant_and_the_scalar_recurrence() raises:
    var lams = couplings()
    for c in range(len(lams)):
        var lam = lams[c].copy()
        var levels = trace_polynomials(7, lam)
        var square = constant(0)
        square[0] = lam.mul(lam)
        assert_true(same(invariant(constant(2), levels[0], levels[1]), square))
        for k in range(8):
            assert_equal(degree(levels[k]), fibonacci(k))
            assert_true(levels[k][len(levels[k]) - 1].eq(Q.one()))
            assert_true(trace_value(k, lam, Q(13, 5)).eq(evaluate(levels[k], Q(13, 5))))
            if k >= 2:
                assert_true(same(invariant(levels[k - 2], levels[k - 1], levels[k]), square))


def test_the_trace_is_the_characteristic_polynomial_of_one_period_up_to_two() raises:
    """Stated levels only: `k = 3, 4, 5`. The corner sign selects `-2` or `+2`."""
    var lams = couplings()
    for c in range(len(lams)):
        for k in range(3, 6):
            var trace = trace_polynomial(k, lams[c])
            var word = fibonacci_word(k)
            assert_equal(len(word), fibonacci(k))
            assert_true(same(charpoly(jacobi(word, lams[c], 1)), sub(trace, constant(2))))
            assert_true(same(charpoly(jacobi(word, lams[c], -1)), add(trace, constant(2))))


def test_level_two_at_unit_coupling_is_pinned() raises:
    var level = approximant(2, Q(1, 1), width(), STEPS)
    assert_false(level.rejected)
    assert_equal(len(level.edges), 4)
    assert_edge(level.edges[0], Q(-13099255, 8388608), Q(-6549625, 4194304), 2)
    assert_edge(level.edges[1], Q(-2, 4782969), Q(2, 4782969), -2)
    assert_edge(level.edges[2], Q(4782968, 4782969), Q(1594324, 1594323), -2)
    assert_edge(level.edges[3], Q(5371965, 2097152), Q(21487865, 8388608), 2)
    assert_equal(len(level.bands), 2)
    assert_true(level.bands[0].left == 0 and level.bands[0].right == 1)
    assert_true(level.bands[1].left == 2 and level.bands[1].right == 3)
    var gaps = gap_bounds(level)
    assert_true(gaps[0].lo.lt(Q.one()) and Q.one().lt(gaps[0].hi))


def test_level_five_at_unit_coupling_is_pinned() raises:
    var level = approximant(5, Q(1, 1), width(), STEPS)
    assert_false(level.rejected)
    assert_equal(len(level.edges), 16)
    assert_edge(level.edges[0], Q(-12251603, 8388608), Q(-24503193, 16777216), 2)
    assert_edge(level.edges[15], Q(22646117, 8388608), Q(45292247, 16777216), 2)
    var pattern: List[Int] = [2, -2, -2, 2]
    for i in range(16):
        assert_equal(level.edges[i].level, pattern[i % 4])
    assert_equal(len(level.bands), 8)
    for i in range(8):
        assert_true(level.bands[i].left == 2 * i and level.bands[i].right == 2 * i + 1)
    assert_true(total(inner_bands(level)).eq(Q(17912141, 8388608)))
    assert_true(total(outer_bands(level)).eq(Q(17912245, 8388608)))
    var gaps = gap_bounds(level)
    assert_true(gaps[0].lo.eq(Q(1665339, 16777216)) and gaps[0].hi.eq(Q(1665365, 16777216)))


def test_level_four_at_half_coupling_is_pinned() raises:
    var level = approximant(4, Q(1, 2), width(), STEPS)
    assert_false(level.rejected)
    assert_edge(level.edges[0], Q(-57722899, 33554432), Q(-115445755, 67108864), -2)
    assert_true(total(outer_bands(level)).eq(Q(52917047, 16777216)))
    var gaps = gap_bounds(level)
    assert_true(gaps[1].lo.eq(Q(23153049, 67108864)) and gaps[1].hi.eq(Q(23153135, 67108864)))


def assert_certified(level: Approximant, k: Int, lam: Q) raises:
    """The finite facts of specification sections 2 to 4 at one level."""
    assert_false(level.rejected)
    assert_equal(len(level.bands), fibonacci(k))
    assert_equal(len(level.edges), 2 * fibonacci(k))
    assert_equal(closed_gaps(level), 0)
    var trace = trace_polynomial(k, lam)
    var two = q_int(2)
    for i in range(len(level.edges)):
        var edge = level.edges[i].copy()
        assert_true(edge.lo.lt(edge.hi) and edge.hi.sub(edge.lo).le(width()))
        var shifted = sub(trace, constant(edge.level))
        assert_true(evaluate(shifted, edge.lo).mul(evaluate(shifted, edge.hi)).lt(Q.zero()))
        if i > 0:
            assert_true(level.edges[i - 1].hi.le(edge.lo))
    var inner = inner_bands(level)
    for i in range(len(inner)):
        assert_true(inner[i].accepted())
        assert_true(q_abs(trace_value(k, lam, inner[i].lo)).lt(two))
        assert_true(q_abs(trace_value(k, lam, inner[i].lo.add(inner[i].hi).div(two))).lt(two))
        assert_true(q_abs(trace_value(k, lam, inner[i].hi)).lt(two))
    for i in range(len(level.bands) - 1):
        var point = level.edges[level.bands[i].right].hi.add(level.edges[level.bands[i + 1].left].lo).div(two)
        assert_true(two.lt(q_abs(trace_value(k, lam, point))))
    var gaps = gap_bounds(level)
    for i in range(len(gaps)):
        assert_true(Q.zero().le(gaps[i].lo) and gaps[i].hi.le(gaps[i].lo.add(two.mul(width()))))


def assert_cover(first: Approximant, second: Approximant, third: Approximant, k: Int, lam: Q) raises:
    """Section 5 at one pair of levels, and the next level against it."""
    var two = q_int(2)
    var joined = cover(first, second)
    for i in range(len(joined) - 1):
        assert_true(joined[i].hi.lt(joined[i + 1].lo))
        var point = joined[i].hi.add(joined[i + 1].lo).div(two)
        for level in range(k, k + 3):
            assert_true(two.lt(q_abs(trace_value(level, lam, point))))
    var inner = inner_bands(third)
    for i in range(len(inner)):
        var held = False
        for j in range(len(joined)):
            held = held or (joined[j].lo.le(inner[i].lo) and inner[i].hi.le(joined[j].hi))
        assert_true(held)


def test_every_level_is_certified_and_consecutive_levels_cover_the_next() raises:
    var lams = couplings()
    for c in range(len(lams)):
        var lam = lams[c].copy()
        var levels = List[Approximant]()
        for k in range(TOP + 1):
            levels.append(approximant(k, lam, width(), STEPS))
            assert_certified(levels[k], k, lam)
        for k in range(TOP - 1):
            assert_cover(levels[k], levels[k + 1], levels[k + 2], k, lam)


def test_the_cover_of_levels_four_and_five_is_pinned() raises:
    var joined = cover(approximant(4, Q(1, 1), width(), STEPS), approximant(5, Q(1, 1), width(), STEPS))
    assert_equal(len(joined), 4)
    assert_true(joined[0].lo.eq(Q(-24850323, 16777216)) and joined[0].hi.eq(Q(-3474675, 8388608)))
    assert_true(joined[3].lo.eq(Q(18849025, 8388608)) and joined[3].hi.eq(Q(45292247, 16777216)))
    assert_true(total(joined).eq(Q(52998523, 16777216)))


def test_zero_coupling_is_one_band_with_every_inner_gap_closed() raises:
    for k in range(TOP + 1):
        var level = approximant(k, Q.zero(), width(), STEPS)
        assert_false(level.rejected)
        assert_equal(len(level.bands), 1)
        assert_true(level.bands[0].left == 0 and level.bands[0].right == len(level.edges) - 1)
        assert_equal(closed_gaps(level), fibonacci(k) - 1)
        var outer = outer_bands(level)
        assert_true(outer[0].lo.lt(q_int(-2)) and q_int(-2).lt(outer[0].lo.add(width())))
        assert_true(outer[0].hi.sub(width()).lt(q_int(2)) and q_int(2).lt(outer[0].hi))


def test_refusals() raises:
    assert_true(approximant(-1, Q(1, 1), width(), STEPS).rejected)
    assert_true(approximant(5, Q(1, 1), width(), 16).rejected)
    assert_false(approximant(5, Q(1, 1), width(), 256).rejected)


def main() raises:
    test_the_first_trace_polynomials()
    print("[PASS]", "test_the_first_trace_polynomials")
    test_degree_invariant_and_the_scalar_recurrence()
    print("[PASS]", "test_degree_invariant_and_the_scalar_recurrence")
    test_the_trace_is_the_characteristic_polynomial_of_one_period_up_to_two()
    print("[PASS]", "test_the_trace_is_the_characteristic_polynomial_of_one_period_up_to_two")
    test_level_two_at_unit_coupling_is_pinned()
    print("[PASS]", "test_level_two_at_unit_coupling_is_pinned")
    test_level_five_at_unit_coupling_is_pinned()
    print("[PASS]", "test_level_five_at_unit_coupling_is_pinned")
    test_level_four_at_half_coupling_is_pinned()
    print("[PASS]", "test_level_four_at_half_coupling_is_pinned")
    test_every_level_is_certified_and_consecutive_levels_cover_the_next()
    print("[PASS]", "test_every_level_is_certified_and_consecutive_levels_cover_the_next")
    test_the_cover_of_levels_four_and_five_is_pinned()
    print("[PASS]", "test_the_cover_of_levels_four_and_five_is_pinned")
    test_zero_coupling_is_one_band_with_every_inner_gap_closed()
    print("[PASS]", "test_zero_coupling_is_one_band_with_every_inner_gap_closed")
    test_refusals()
    print("[PASS]", "test_refusals")
    print("10 fibonacci hamiltonian tests passed.")
