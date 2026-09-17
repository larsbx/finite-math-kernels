"""The Python oracle of the M-adic ball carrier, and the values it shares with Mojo.

`tools/madic_oracle.py` is written from the definitions; `finite_linear_algebra/madic_ball.mojo`
is written over `Q` and `BigZ`. Every pinned number below is asserted by both, so
agreement is evidence rather than an echo. The structural properties in the second
half are checked only here, because they need enumeration that the Mojo
regressions deliberately do not carry.

The specification is `docs/madic-ball-arithmetic-spec.md`.
"""

from __future__ import annotations

import itertools
import random
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import madic_oracle as oracle  # noqa: E402

CANONICAL = [[0, 1, 2], [1, 1, 1], [0, 1, 0]]   # det 2, the standing regression
UNIMODULAR = [[1, 1, 0], [0, 1, 1], [1, 0, 0]]  # det 1, the unit branch
TWO_BY_TWO = [[2, 0], [0, 2]]                   # Z/2 x Z/2, smallest non-cyclic
COPRIME_DIAGONAL = [[2, 0], [0, 3]]             # Z/6, cyclic despite two factors


# --- the values the Mojo regressions pin as well ---------------------------------


def test_quotient_order_is_the_absolute_determinant():
    for k in range(5):
        assert oracle.quotient_order(CANONICAL, k) == 2**k
        assert oracle.quotient_order(UNIMODULAR, k) == 1


def test_the_quotient_need_not_be_cyclic():
    # A scalar Z_p ball at precision k is always cyclic; these are not, which is
    # the whole reason the carrier is M-adic rather than scalar p-adic.
    assert oracle.quotient_invariants(CANONICAL, 2) == [1, 2, 2]
    assert oracle.quotient_invariants(TWO_BY_TWO, 1) == [2, 2]
    # And non-cyclicity is not automatic: coprime elementary divisors recombine.
    assert oracle.quotient_invariants(COPRIME_DIAGONAL, 1) == [1, 6]


def test_the_invariant_factors_change_shape_with_the_level():
    expected = [[1, 1, 1], [1, 1, 2], [1, 2, 2], [1, 2, 4], [1, 4, 4]]
    assert [oracle.quotient_invariants(CANONICAL, k) for k in range(5)] == expected


def test_the_unit_branch_has_a_trivial_filtration():
    for k in range(5):
        assert oracle.quotient_invariants(UNIMODULAR, k) == [1, 1, 1]
    assert oracle.same_coset(UNIMODULAR, 2, [3, -7, 11], [0, 0, 0])


def test_membership_of_the_lattice():
    assert oracle.contains(CANONICAL, 3, [3, 3, 1])      # first column of M^3
    assert not oracle.contains(CANONICAL, 3, [1, 0, 0])
    assert oracle.contains(CANONICAL, 3, [0, 0, 0])


def test_same_coset_is_the_unknown_answer_and_refinement_can_separate():
    a, b = [-1, -2, 4], [2, -4, -3]
    assert oracle.same_coset(CANONICAL, 1, a, b)
    assert oracle.separated(CANONICAL, 2, a, b)
    assert not oracle.same_coset_means_equal()


def test_separation_is_the_only_certificate():
    assert oracle.separated(CANONICAL, 1, [1, 0, 0], [0, 0, 0])
    assert not oracle.carrier_is_scalar_padic()


# --- properties checked only here ------------------------------------------------


def test_the_number_of_cosets_equals_the_quotient_order():
    """Enumeration, against the determinant. The two are computed by different
    routes: cosets by the membership solve, the order by the determinant."""
    for level in (1, 2, 3):
        representatives: list[list[int]] = []
        for point in itertools.product(range(-6, 7), repeat=3):
            candidate = list(point)
            if not any(oracle.same_coset(CANONICAL, level, candidate, r) for r in representatives):
                representatives.append(candidate)
        assert len(representatives) == oracle.quotient_order(CANONICAL, level)


def test_the_lattice_columns_are_members_at_their_own_level():
    for level in (1, 2, 3):
        lattice = oracle.power(CANONICAL, level)
        for column in range(3):
            assert oracle.contains(CANONICAL, level, [lattice[i][column] for i in range(3)])


def test_refinement_only_ever_separates_more():
    """Membership is monotone in the level: `M^(k+1) Z^n` is inside `M^k Z^n`, so
    a pair separated at level `k` stays separated at every deeper level."""
    random.seed(17)
    separated_deeper = 0
    for _ in range(300):
        a = [random.randint(-8, 8) for _ in range(3)]
        b = [random.randint(-8, 8) for _ in range(3)]
        for level in range(1, 5):
            if oracle.separated(CANONICAL, level, a, b):
                assert oracle.separated(CANONICAL, level + 1, a, b)
                separated_deeper += 1
                break
    assert separated_deeper > 100


def test_a_singular_lattice_is_refused_rather_than_answered():
    singular = [[1, 2], [2, 4]]
    with pytest.raises(ValueError):
        oracle.contains(singular, 1, [1, 0])


def test_the_dimension_is_bounded_and_a_larger_one_is_refused():
    big = oracle.identity(oracle.MAX_DIMENSION + 1)
    with pytest.raises(ValueError):
        oracle.smith_invariants(big)


def test_a_negative_level_is_refused():
    with pytest.raises(ValueError):
        oracle.power(CANONICAL, -1)
