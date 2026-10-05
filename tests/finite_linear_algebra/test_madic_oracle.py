"""The Python oracle of the M-adic ball carrier, and the values it shares with Mojo.

`oracles/madic_oracle.py` is written from the definitions; `kernel/finite_linear_algebra/madic_ball.mojo`
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
sys.path.insert(0, str(ROOT / "kernel"))
sys.path.insert(0, str(ROOT / "tools"))

import madic_oracle as oracle  # noqa: E402
from oracle_refinement import Class, Refinement  # noqa: E402

CANONICAL = [[0, 1, 2], [1, 1, 1], [0, 1, 0]]   # det 2, the standing regression
UNIMODULAR = [[1, 1, 0], [0, 1, 1], [1, 0, 0]]  # det 1, the unit branch
TWO_BY_TWO = [[2, 0], [0, 2]]                   # Z/2 x Z/2, smallest non-cyclic
COPRIME_DIAGONAL = [[2, 0], [0, 3]]             # Z/6, cyclic despite two factors
SINGULAR = [[1, 2], [2, 4]]                     # det 0, no filtration of finite index
SHEAR = [[2, 1], [0, 1]]                        # rows and columns span different lattices
WRAP = 1 << 63                                  # where Int subtraction used to wrap


# --- phi_G: the corpus this file draws, declared -----------------------------------
#
# `docs/generator-refinement-spec.md`. Both defects this oracle has caught were
# hidden by the corpus rather than by the model: the 64-bit wrap in the Mojo
# carrier survived 1200 differential checks because every coordinate generated
# lay in [-9, 9], and a singular lattice survived level zero because no matrix
# in the corpus was singular. Neither gap was visible, because neither corpus
# said what it contained. These declarations say it, and `test_the_corpus_meets
# _its_declared_refinement` refuses a corpus that stops meeting them.

COORDINATE = Refinement(
    "madic coordinate",
    "an integer coordinate of a lattice point",
    lambda v: isinstance(v, int),
    (
        Class("small", lambda v: abs(v) <= 8),
        Class("negative", lambda v: v < 0),
        Class("zero", lambda v: v == 0),
        Class("beyond 64 bits", lambda v: abs(v) >= WRAP),
    ),
)

LATTICE = Refinement(
    "madic lattice",
    f"a square integer matrix of dimension at most {oracle.MAX_DIMENSION}",
    lambda m: bool(m) and all(len(row) == len(m) for row in m) and len(m) <= oracle.MAX_DIMENSION,
    (
        Class("unimodular", lambda m: abs(oracle.determinant(m)) == 1),
        Class("proper non-unit", lambda m: abs(oracle.determinant(m)) > 1),
        Class("singular", lambda m: oracle.determinant(m) == 0),
        Class("dimension one", lambda m: len(m) == 1),
        Class("rows span another lattice", lambda m: oracle.determinant(m) != 0
              and rows_and_columns_differ(m, 1)),
    ),
)


def coordinates(draws: int = 300, seed: int = 17) -> list[int]:
    """Lattice coordinates, drawn so the corpus reaches the wrap boundary rather
    than stopping short of it. One draw in six is placed within a small window of
    plus or minus 2^63, because that is where the defect this corpus missed
    lived, and nothing smaller would have found it."""
    rng = random.Random(seed)
    drawn = []
    for index in range(draws):
        if index % 6 == 0:
            drawn.append(rng.choice((1, -1)) * (WRAP + rng.randint(-4, 4)))
        else:
            drawn.append(rng.randint(-8, 8))
    return drawn


def lattices() -> list[list[list[int]]]:
    """Every matrix this file reasons about, singular ones included."""
    return [CANONICAL, UNIMODULAR, TWO_BY_TWO, COPRIME_DIAGONAL, SINGULAR, SHEAR, [[3]]]


def transpose(m: list[list[int]]) -> list[list[int]]:
    return [list(row) for row in zip(*m)]


def rows_and_columns_differ(m: list[list[int]], level: int) -> bool:
    """Whether some row of `M^k` lies outside `M^k Z^n`, the lattice its columns span.

    Both lattices have index `|det M|^k`, so one row outside is enough to make
    them different lattices. Where every row is inside, they coincide and no
    membership test over `m` can tell a row-convention carrier from this one.
    """
    return not all(oracle.contains(m, level, row) for row in oracle.power(m, level))


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


# Where the row and column lattices of `M^k` differ, so a membership test can
# tell which of them the carrier means.
GENERATOR_WITNESSES = ((SHEAR, 1), (SHEAR, 2), (SHEAR, 3), (CANONICAL, 4))


def generator_contract_violations(contains) -> list[str]:
    """Where `contains` departs from the column contract: `M^k Z^n` is spanned by
    the columns of `M^k`, and at a witness level its first row lies outside it."""
    problems = []
    for m, level in GENERATOR_WITNESSES:
        lattice = oracle.power(m, level)
        for j in range(len(m)):
            if not contains(m, level, [row[j] for row in lattice]):
                problems.append(f"column {j} of {m}^{level} is not a member")
        if contains(m, level, lattice[0]):
            problems.append(f"row 0 of {m}^{level} reads as a member")
    return problems


def test_the_generators_are_the_columns_not_the_rows():
    assert generator_contract_violations(oracle.contains) == []
    assert oracle.contains(SHEAR, 1, [2, 0])
    assert not oracle.contains(SHEAR, 1, [2, 1])


def test_a_row_convention_carrier_is_refused():
    """The mutant that reads the generators off the rows, `Z^n M^k`, which is
    `(M^T)^k Z^n` transposed. The contract must fail it, or it pins nothing."""
    def rows_generate(m, level, delta):
        return oracle.contains(transpose(m), level, delta)

    assert generator_contract_violations(rows_generate) != []


def test_the_canonical_regression_tells_rows_from_columns_only_from_level_four():
    """Why the convention went unpinned: for the standing regression the row and
    column lattices coincide up to level three, where every other membership pin
    stops, so those pins hold under either convention."""
    assert [rows_and_columns_differ(CANONICAL, k) for k in range(6)] == [False] * 4 + [True] * 2
    assert oracle.contains(CANONICAL, 4, [5, 7, 3])         # first column of M^4
    assert not oracle.contains(CANONICAL, 4, [5, 13, 11])   # first row of M^4


def test_the_corpus_meets_its_declared_refinement():
    """The declaration above, checked. It is two-sided: a class declared reached
    and never drawn fails, and so would a class declared missed and then drawn."""
    assert COORDINATE.audit(coordinates()) == ()
    assert LATTICE.audit(lattices()) == ()


def test_a_corpus_that_stops_short_of_the_wrap_is_refused():
    """The negative control, and it is the corpus that hid the defect: the run
    that missed the 64-bit wrap drew every coordinate from a small window, and
    the declaration now names exactly that."""
    narrow = [v for v in coordinates() if abs(v) <= 8]
    problems = COORDINATE.audit(narrow)
    assert problems and "beyond 64 bits" in problems[0]
    assert LATTICE.audit([m for m in lattices() if oracle.determinant(m) != 0]) != ()


def test_refinement_only_ever_separates_more():
    """Membership is monotone in the level: `M^(k+1) Z^n` is inside `M^k Z^n`, so
    a pair separated at level `k` stays separated at every deeper level.

    Drawn from `coordinates()`, so the pairs reach across the wrap boundary as
    well as around the origin."""
    drawn = coordinates(draws=1800)
    separated_deeper = 0
    for start in range(0, len(drawn) - 5, 6):
        a, b = drawn[start:start + 3], drawn[start + 3:start + 6]
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


def test_a_singular_lattice_is_refused_at_level_zero_too():
    """Review found this hole: `power(m, 0)` is the identity whatever `m` was, so
    the singular matrix used to go undetected and every delta read as a member."""
    singular = [[1, 2], [2, 4]]
    with pytest.raises(ValueError):
        oracle.contains(singular, 0, [1, 0])
    with pytest.raises(ValueError):
        oracle.same_coset(singular, 0, [5, 7], [1, 0])


def test_far_apart_coordinates_do_not_wrap():
    """The Mojo carrier formed `a[i] - b[i]` in `Int` before lifting, which wraps.

    With `M = [3]`, `a = 2^63 - 1` and `b = -2`, the true difference is
    `2^63 + 1` and divisible by three, so the points share a coset. The wrapped
    64-bit difference is not divisible by three, which would have made the
    carrier issue a false separation certificate. Python is unbounded and so was
    always right here, which is exactly why the earlier differential run missed
    it: every generated coordinate was small.
    """
    m = [[3]]
    a, b = [2**63 - 1], [-2]
    assert (a[0] - b[0]) % 3 == 0
    assert oracle.same_coset(m, 1, a, b)
    assert not oracle.separated(m, 1, a, b)


def test_the_dimension_is_bounded_and_a_larger_one_is_refused():
    big = oracle.identity(oracle.MAX_DIMENSION + 1)
    with pytest.raises(ValueError):
        oracle.smith_invariants(big)


def test_a_negative_level_is_refused():
    with pytest.raises(ValueError):
        oracle.power(CANONICAL, -1)
