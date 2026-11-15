"""Behavioural tests of the reference against docs/fibonacci-hamiltonian-band-edges-spec.md.

Every pinned constant here is also asserted by the Mojo test
``tests/fibonacci_hamiltonian/test_band_edges.mojo``, so the kernel and this
oracle agree on values rather than merely on shapes. The reference also runs
levels the Mojo suite does not, up to ``k = 8``.
"""

from __future__ import annotations

import sys
from fractions import Fraction as F
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "reference"))

import fibonacci_hamiltonian_reference as fh  # noqa: E402
import qpoly_reference as qp  # noqa: E402

WIDTH = F(1, 1 << 20)
STEPS = 1 << 16
FIBONACCI = (1, 1, 2, 3, 5, 8, 13, 21, 34)
COUPLINGS = (F(1), F(1, 2), F(5), F(-3, 2))


def fibonacci_word(k: int) -> tuple[int, ...]:
    """`W_0 = 0`, `W_1 = 1`, `W_(k+1) = W_(k-1) W_k`: where the coupling sits."""
    before, here = (0,), (1,)
    for _ in range(k):
        before, here = here, before + here
    return before


def jacobi(word: tuple[int, ...], lam: F, corner: int) -> tuple[tuple[F, ...], ...]:
    """The cyclic tridiagonal matrix of one period, with `corner` closing the cycle."""
    size = len(word)
    rows = [[F(0)] * size for _ in range(size)]
    for i, letter in enumerate(word):
        rows[i][i] = lam * letter
        rows[i][(i + 1) % size] = rows[(i + 1) % size][i] = F(corner if i == size - 1 else 1)
    return tuple(tuple(row) for row in rows)


@pytest.fixture(scope="module")
def levels() -> dict[tuple[int, F], fh.Approximant]:
    return {(k, lam): fh.approximant(k, lam, WIDTH, STEPS) for lam in COUPLINGS for k in range(9)}


# --- section 1: the trace polynomials -------------------------------------------


def test_the_first_trace_polynomials():
    assert fh.trace_polynomials(3, 1) == (qp.of(0, 1), qp.of(-1, 1), qp.of(-2, -1, 1), qp.of(2, -2, -2, 1))
    assert fh.trace_polynomial(2, F(1, 2)) == qp.of(-2, F(-1, 2), 1)


def test_the_degree_is_fibonacci_and_the_polynomial_is_monic():
    for lam in COUPLINGS + (F(0),):
        for k, size in enumerate(FIBONACCI):
            trace = fh.trace_polynomial(k, lam)
            assert qp.degree(trace) == size
            assert trace[-1] == 1


def test_three_consecutive_traces_have_invariant_the_squared_coupling():
    for lam in COUPLINGS + (F(0),):
        traces = fh.trace_polynomials(8, lam)
        assert fh.invariant(qp.of(2), traces[0], traces[1]) == qp.of(lam * lam)
        for a, b, c in zip(traces, traces[1:], traces[2:]):
            assert fh.invariant(a, b, c) == qp.of(lam * lam)


def test_the_scalar_recurrence_agrees_with_the_polynomial():
    for lam in COUPLINGS:
        for k in range(9):
            for energy in (F(-7, 3), F(0), F(1, 2), F(13, 5)):
                assert fh.trace_value(k, lam, energy) == qp.evaluate(fh.trace_polynomial(k, lam), energy)


def test_the_trace_is_the_characteristic_polynomial_of_one_period_up_to_two():
    """Stated levels only: `3 <= F_k <= 13`. The corner sign selects `-2` or `+2`."""
    for lam in COUPLINGS:
        for k in range(3, 7):
            trace, word = fh.trace_polynomial(k, lam), fibonacci_word(k)
            assert len(word) == FIBONACCI[k]
            assert qp.charpoly(jacobi(word, lam, 1)) == qp.sub(trace, qp.of(2))
            assert qp.charpoly(jacobi(word, lam, -1)) == qp.add(trace, qp.of(2))


def test_a_negative_level_is_refused():
    with pytest.raises(ValueError):
        fh.trace_polynomial(-1, 1)


# --- sections 2 to 4: edges, segments, bands ------------------------------------


def test_level_two_at_unit_coupling_is_pinned():
    level = fh.approximant(2, 1, WIDTH, STEPS)
    assert level.edges == (
        fh.Edge(F(-13099255, 8388608), F(-6549625, 4194304), 2),
        fh.Edge(F(-2, 4782969), F(2, 4782969), -2),
        fh.Edge(F(4782968, 4782969), F(1594324, 1594323), -2),
        fh.Edge(F(5371965, 2097152), F(21487865, 8388608), 2),
    )
    assert level.bands == ((0, 1), (2, 3))
    lower, upper = level.gap_bounds()[0]
    assert lower < 1 < upper


def test_level_five_at_unit_coupling_is_pinned():
    level = fh.approximant(5, 1, WIDTH, STEPS)
    assert level.edges[0] == fh.Edge(F(-12251603, 8388608), F(-24503193, 16777216), 2)
    assert level.edges[-1] == fh.Edge(F(22646117, 8388608), F(45292247, 16777216), 2)
    assert [edge.level for edge in level.edges] == [2, -2, -2, 2] * 4
    assert level.bands == tuple((2 * i, 2 * i + 1) for i in range(8))
    assert sum(hi - lo for lo, hi in level.inner()) == F(17912141, 8388608)
    assert sum(hi - lo for lo, hi in level.outer()) == F(17912245, 8388608)
    assert level.gap_bounds()[0] == (F(1665339, 16777216), F(1665365, 16777216))


def test_level_four_at_half_coupling_is_pinned():
    level = fh.approximant(4, F(1, 2), WIDTH, STEPS)
    assert level.edges[0] == fh.Edge(F(-57722899, 33554432), F(-115445755, 67108864), -2)
    assert sum(hi - lo for lo, hi in level.outer()) == F(52917047, 16777216)
    assert level.gap_bounds()[1] == (F(23153049, 67108864), F(23153135, 67108864))


def test_every_level_has_fibonacci_many_bands_and_no_closed_gap(levels):
    for (k, _), level in levels.items():
        assert len(level.bands) == FIBONACCI[k]
        assert len(level.edges) == 2 * FIBONACCI[k]
        assert level.closed_gaps() == 0


def test_edges_are_ordered_narrow_and_carry_their_sign_change(levels):
    for (k, lam), level in levels.items():
        trace = fh.trace_polynomial(k, lam)
        for edge in level.edges:
            assert F(0) < edge.hi - edge.lo <= WIDTH
            shifted = qp.sub(trace, qp.of(edge.level))
            assert qp.evaluate(shifted, edge.lo) * qp.evaluate(shifted, edge.hi) < 0
        for left, right in zip(level.edges, level.edges[1:]):
            assert left.hi <= right.lo


def test_the_trace_is_inside_on_inner_bands_and_outside_in_gaps(levels):
    for (k, lam), level in levels.items():
        for lo, hi in level.inner():
            assert lo <= hi
            for point in (lo, (lo + hi) / 2, hi):
                assert abs(fh.trace_value(k, lam, point)) < 2
        for (_, a), (b, _) in zip(level.bands, level.bands[1:]):
            point = (level.edges[a].hi + level.edges[b].lo) / 2
            assert abs(fh.trace_value(k, lam, point)) > 2
        for lower, upper in level.gap_bounds():
            assert F(0) <= lower <= upper <= lower + 2 * WIDTH


def test_zero_coupling_is_one_band_with_every_inner_gap_closed():
    for k in range(9):
        level = fh.approximant(k, 0, WIDTH, STEPS)
        assert level.bands == ((0, len(level.edges) - 1),)
        assert level.closed_gaps() == FIBONACCI[k] - 1
        (lo, hi), = level.outer()
        assert lo < -2 < lo + WIDTH and hi - WIDTH < 2 < hi


def test_an_exhausted_budget_is_a_refusal():
    assert fh.approximant(5, 1, WIDTH, 16) is None
    assert fh.approximant(5, 1, WIDTH, 256) is not None


# --- section 5: the cover by two consecutive levels ------------------------------


def test_the_cover_of_levels_four_and_five_is_pinned():
    cover = fh.cover(fh.approximant(4, 1, WIDTH, STEPS), fh.approximant(5, 1, WIDTH, STEPS))
    assert len(cover) == 4
    assert cover[0] == (F(-24850323, 16777216), F(-3474675, 8388608))
    assert cover[-1] == (F(18849025, 8388608), F(45292247, 16777216))
    assert sum(hi - lo for lo, hi in cover) == F(52998523, 16777216)


def test_both_traces_exceed_two_in_every_gap_of_the_cover_and_so_does_the_next(levels):
    for lam in COUPLINGS:
        for k in range(7):
            cover = fh.cover(levels[k, lam], levels[k + 1, lam])
            for (_, hi), (lo, _) in zip(cover, cover[1:]):
                assert hi < lo
                for level in (k, k + 1, k + 2):
                    assert abs(fh.trace_value(level, lam, (hi + lo) / 2)) > 2


def test_the_inner_bands_two_levels_on_lie_in_the_cover(levels):
    """Suto's nesting, observed at stated levels: never asserted beyond them."""
    for lam in COUPLINGS:
        for k in range(7):
            cover = fh.cover(levels[k, lam], levels[k + 1, lam])
            for lo, hi in levels[k + 2, lam].inner():
                assert any(a <= lo and hi <= b for a, b in cover)
            later = fh.cover(levels[k + 1, lam], levels[k + 2, lam])
            assert sum(hi - lo for lo, hi in later) < sum(hi - lo for lo, hi in cover)
