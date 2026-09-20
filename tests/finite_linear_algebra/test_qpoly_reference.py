"""Behavioural tests of the qpoly reference against docs/exact-polynomial-root-isolation-spec.md.

Every pinned constant here is also asserted by the Mojo test
``tests/finite_linear_algebra/test_qpoly.mojo``, so the kernels and this oracle
agree on values rather than merely on shapes.
"""

from __future__ import annotations

import random
import sys
from fractions import Fraction as F
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import qpoly_reference as qp  # noqa: E402

WIDTH = F(1, 1 << 20)
STEPS = 256

GOLDEN = qp.of(-1, -1, 1)
TRIBONACCI = qp.of(-1, -1, -1, 1)

FIBONACCI_MATRIX = ((F(1), F(1)), (F(1), F(0)))
TRIBONACCI_MATRIX = ((F(1), F(1), F(1)), (F(1), F(0), F(0)), (F(0), F(1), F(0)))
ALL_ONES_TWO = ((F(1), F(1)), (F(1), F(1)))
IDENTITY_THREE = tuple(tuple(F(1) if i == j else F(0) for j in range(3)) for i in range(3))


# --- section 1: objects and the ring operations --------------------------------


def test_normalization_and_degree():
    assert qp.of(1, 2, 0, 0) == (F(1), F(2))
    assert qp.degree(qp.of(0, 0)) == -1
    assert qp.degree(qp.of(1, 2, 0, 0)) == 1
    assert qp.derivative(qp.of(7)) == ()
    assert qp.derivative(GOLDEN) == (F(-1), F(2))


def test_evaluation_is_horner_and_agrees_with_the_definition():
    generator = random.Random(20260920)
    for _ in range(64):
        coefficients = qp.of(*(generator.randint(-5, 5) for _ in range(5)))
        x = F(generator.randint(-6, 6), generator.randint(1, 4))
        assert qp.evaluate(coefficients, x) == sum(c * x ** k for k, c in enumerate(coefficients))


def test_the_ring_operations():
    assert qp.mul(qp.of(-1, 1), qp.of(1, 1, 1)) == qp.of(-1, 0, 0, 1)
    assert qp.sub(GOLDEN, GOLDEN) == ()
    assert qp.add(qp.of(1, 1), qp.of(-1, -1)) == ()
    assert qp.scale(GOLDEN, 2) == (F(-2), F(-2), F(2))


# --- section 2: division, gcd, squarefree part ---------------------------------


def test_division_is_exact_over_the_field():
    quotient, rest = qp.divide(qp.of(-1, 0, 0, 1), qp.of(-1, 1))
    assert quotient == qp.of(1, 1, 1)
    assert rest == ()
    assert qp.mul(quotient, qp.of(-1, 1)) == qp.of(-1, 0, 0, 1)


def test_division_by_zero_refuses():
    with pytest.raises(ZeroDivisionError):
        qp.divide(qp.of(-1, 0, 0, 1), ())


def test_the_division_identity_holds_on_random_pairs():
    generator = random.Random(4422)
    for _ in range(64):
        a = qp.of(*(generator.randint(-4, 4) for _ in range(generator.randint(1, 6))))
        b = qp.of(*(generator.randint(-4, 4) for _ in range(generator.randint(1, 4))))
        if not b:
            continue
        quotient, rest = qp.divide(a, b)
        assert qp.add(qp.mul(quotient, b), rest) == a
        assert qp.degree(rest) < qp.degree(b)


def test_gcd_is_monic_and_the_squarefree_part_simplifies():
    assert qp.gcd(qp.of(-1, 0, 1), qp.of(-1, 1)) == qp.of(-1, 1)
    assert qp.gcd(qp.of(-2, 0, 2), qp.of(-3, 3)) == qp.of(-1, 1)
    assert qp.squarefree_part(qp.of(1, -2, 1)) == qp.of(-1, 1)
    assert qp.squarefree_part(GOLDEN) == GOLDEN


# --- section 3: the root bound -------------------------------------------------


def test_the_root_bound_is_rational_and_above_every_root():
    assert qp.root_bound(GOLDEN) == 2
    assert qp.root_bound(TRIBONACCI) == 2
    with pytest.raises(ValueError):
        qp.root_bound(qp.of(5))


def test_no_root_reaches_the_bound():
    for polynomial in (GOLDEN, TRIBONACCI, qp.charpoly(ALL_ONES_TWO)):
        bound = qp.root_bound(polynomial)
        assert qp.evaluate(polynomial, bound) != 0
        bracket = qp.largest_root_bracket(polynomial, WIDTH, STEPS)
        assert bracket.hi < bound


# --- sections 4 and 5: the chain and its variations ----------------------------


def test_the_sturm_chain_and_its_variations():
    chain = qp.sturm_chain(GOLDEN)
    assert len(chain) == 3
    assert chain[0] == GOLDEN
    assert chain[1] == (F(-1), F(2))
    assert chain[2] == (F(5, 4),)
    assert qp.sign_variations(chain, -2) == 2
    assert qp.sign_variations(chain, 2) == 0
    assert qp.variation_difference(chain, -2, 2) == 2


def test_the_variation_difference_over_the_bound_matches_the_known_root_counts():
    """Sturm's theorem is the consumer's import; these are the numbers it reads."""
    for polynomial, expected in ((GOLDEN, 2), (TRIBONACCI, 1), (qp.of(1, 0, 1), 0), (qp.of(1, -2, 1), 1)):
        chain = qp.sturm_chain(polynomial)
        bound = qp.root_bound(polynomial)
        assert qp.variation_difference(chain, -bound, bound) == expected


# --- section 6: the bracket ----------------------------------------------------


def assert_bracket(polynomial, lo, hi):
    bracket = qp.largest_root_bracket(polynomial, WIDTH, STEPS)
    assert bracket.found and not bracket.exact
    assert (bracket.lo, bracket.hi) == (lo, hi)
    square_free = qp.squarefree_part(polynomial)
    assert qp.evaluate(square_free, lo) * qp.evaluate(square_free, hi) < 0
    assert bracket.width() <= WIDTH


def test_the_golden_and_tribonacci_brackets():
    assert_bracket(GOLDEN, F(1696631, 1048576), F(212079, 131072))
    assert_bracket(TRIBONACCI, F(1928631, 1048576), F(241079, 131072))


def test_the_chebyshev_transition_matrix_brackets_two():
    characteristic = qp.charpoly(ALL_ONES_TWO)
    assert characteristic == qp.of(0, -2, 1)
    assert_bracket(characteristic, F(4194303, 2097152), F(8388609, 4194304))


def test_an_exact_rational_root_is_returned_as_itself():
    bracket = qp.largest_root_bracket(qp.of(-1, 1), WIDTH, STEPS)
    assert bracket.found and bracket.exact
    assert (bracket.lo, bracket.hi) == (F(1), F(1))


def test_a_repeated_root_still_isolates():
    assert_bracket(qp.of(1, -2, 1), F(4194303, 4194304), F(2097153, 2097152))


def test_no_real_root_is_a_refusal_not_a_bracket():
    assert qp.largest_root_bracket(qp.of(1, 0, 1), WIDTH, STEPS) == qp.REFUSED
    assert qp.largest_root_bracket(qp.of(5), WIDTH, STEPS) == qp.REFUSED
    assert qp.largest_root_bracket((), WIDTH, STEPS) == qp.REFUSED


def test_a_capped_bisection_refuses():
    """Fail closed: too few steps is inconclusive, never "no root"."""
    assert qp.largest_root_bracket(GOLDEN, WIDTH, 3) == qp.REFUSED


def test_the_bracket_is_the_largest_root_and_not_merely_a_root():
    """`(x+3)(x-1)` has two roots; the bracket must land on the upper one."""
    bracket = qp.largest_root_bracket(qp.mul(qp.of(3, 1), qp.of(-1, 1)), WIDTH, STEPS)
    assert bracket.found and bracket.exact
    assert bracket.lo == 1


def test_a_narrower_width_narrows_the_bracket():
    wide = qp.largest_root_bracket(GOLDEN, F(1, 4), STEPS)
    narrow = qp.largest_root_bracket(GOLDEN, F(1, 1 << 30), STEPS)
    assert narrow.width() < wide.width()
    assert wide.lo <= narrow.lo and narrow.hi <= wide.hi


# --- section 7: the characteristic polynomial ----------------------------------


def test_the_general_charpoly_in_several_dimensions():
    assert qp.charpoly(FIBONACCI_MATRIX) == GOLDEN
    assert qp.charpoly(TRIBONACCI_MATRIX) == TRIBONACCI
    assert qp.charpoly(IDENTITY_THREE) == qp.of(-1, 3, -3, 1)
    assert qp.charpoly(()) == qp.of(1)


def cubic_by_traces(matrix) -> qp.Poly:
    """The closed form `finite_linear_algebra/mat3.mojo` uses, independently."""
    trace = sum(matrix[i][i] for i in range(3))
    squared = sum(matrix[i][k] * matrix[k][i] for i in range(3) for k in range(3))
    determinant = sum(
        matrix[0][i]
        * (matrix[1][(i + 1) % 3] * matrix[2][(i + 2) % 3] - matrix[1][(i + 2) % 3] * matrix[2][(i + 1) % 3])
        for i in range(3)
    )
    return qp.of(-determinant, (trace * trace - squared) / 2, -trace, 1)


def test_the_recurrence_agrees_with_the_closed_form_on_cubics():
    generator = random.Random(1337)
    for _ in range(64):
        matrix = tuple(tuple(F(generator.randint(-3, 3)) for _ in range(3)) for _ in range(3))
        assert qp.charpoly(matrix) == cubic_by_traces(matrix)


@pytest.mark.parametrize("size", [1, 2, 3, 4, 5])
def test_the_charpoly_is_monic_and_integral_on_an_integer_matrix(size):
    generator = random.Random(size)
    matrix = tuple(tuple(F(generator.randint(0, 3)) for _ in range(size)) for _ in range(size))
    coefficients = qp.charpoly(matrix)
    assert len(coefficients) == size + 1
    assert coefficients[-1] == 1
    assert all(c.denominator == 1 for c in coefficients)


@pytest.mark.parametrize("size", [1, 2, 3, 4])
def test_a_constant_row_sum_is_a_root_of_the_charpoly(size):
    matrix = tuple(tuple(F(1) for _ in range(size)) for _ in range(size))
    assert qp.evaluate(qp.charpoly(matrix), size) == 0
