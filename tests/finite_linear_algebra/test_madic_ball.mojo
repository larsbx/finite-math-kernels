"""Regressions for the M-adic ball carrier.

Run with `pixi run test-madic` (`mojo run -I . tests/finite_linear_algebra/test_madic_ball.mojo`).
Every pinned number here is also asserted, independently, by
`tests/finite_linear_algebra/test_madic_oracle.py` against `tools/madic_oracle.py`,
which was written from the definitions rather than transliterated from this
module. The specification is `docs/madic-ball-arithmetic-spec.md`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_eq, bigz_from_i64
from finite_linear_algebra.madic_ball import (
    carrier_is_scalar_padic,
    contains,
    index_subsets,
    quotient_invariants,
    quotient_order,
    same_coset,
    same_coset_means_equal,
    separated,
)


def canonical() -> List[Int]:
    """The determinant-two substitution `0 -> 1`, `1 -> 021`, `2 -> 001`."""
    var e: List[Int] = [0, 1, 2, 1, 1, 1, 0, 1, 0]
    return e^


def unimodular() -> List[Int]:
    """A unit-branch incidence matrix: `det = 1`, so every finite place is trivial."""
    var e: List[Int] = [1, 1, 0, 0, 1, 1, 1, 0, 0]
    return e^


def two_by_two() -> List[Int]:
    """`diag(2, 2)`: the smallest non-cyclic quotient, `Z/2 x Z/2`."""
    var e: List[Int] = [2, 0, 0, 2]
    return e^


def coprime_diagonal() -> List[Int]:
    """`diag(2, 3)`: order six and *cyclic*, since `gcd(2, 3) = 1`."""
    var e: List[Int] = [2, 0, 0, 3]
    return e^


def is_int(value: BigZ, expected: Int) -> Bool:
    return bigz_eq(value, bigz_from_i64(Int64(expected)))


def assert_invariants(got: List[BigZ], expected: List[Int]) raises:
    assert_equal(len(got), len(expected))
    for i in range(len(expected)):
        assert_true(is_int(got[i], expected[i]))


def test_quotient_order_is_the_absolute_determinant() raises:
    for k in range(0, 5):
        assert_true(is_int(quotient_order(canonical(), 3, k), 1 << k))
        assert_true(is_int(quotient_order(unimodular(), 3, k), 1))


def test_the_quotient_need_not_be_cyclic() raises:
    """The whole reason the carrier is `M`-adic and not scalar `p`-adic.

    A scalar `Z_p` ball at precision `k` is always cyclic. `Z^3 / M^2 Z^3` here
    is `Z/2 x Z/2`, of the same order as `Z/4` and a different group.
    """
    assert_invariants(quotient_invariants(canonical(), 3, 2), [1, 2, 2])
    assert_invariants(quotient_invariants(two_by_two(), 2, 1), [2, 2])
    # Non-cyclicity is not automatic: coprime elementary divisors recombine.
    assert_invariants(quotient_invariants(coprime_diagonal(), 2, 1), [1, 6])


def test_the_invariant_factors_change_shape_with_the_level() raises:
    """No single exponent `p^(-k)` can record this sequence."""
    assert_invariants(quotient_invariants(canonical(), 3, 0), [1, 1, 1])
    assert_invariants(quotient_invariants(canonical(), 3, 1), [1, 1, 2])
    assert_invariants(quotient_invariants(canonical(), 3, 2), [1, 2, 2])
    assert_invariants(quotient_invariants(canonical(), 3, 3), [1, 2, 4])
    assert_invariants(quotient_invariants(canonical(), 3, 4), [1, 4, 4])


def test_the_unit_branch_has_a_trivial_filtration() raises:
    # det = 1, so M^k Z^3 = Z^3 at every level and there is nothing p-adic to model.
    for k in range(0, 5):
        assert_invariants(quotient_invariants(unimodular(), 3, k), [1, 1, 1])
    var a: List[Int] = [3, -7, 11]
    var b: List[Int] = [0, 0, 0]
    assert_true(same_coset(unimodular(), 3, 2, a, b))


def test_membership_of_the_lattice() raises:
    var member: List[Int] = [3, 3, 1]          # the first column of M^3
    var outsider: List[Int] = [1, 0, 0]
    var origin: List[Int] = [0, 0, 0]
    assert_true(contains(canonical(), 3, 3, member))
    assert_false(contains(canonical(), 3, 3, outsider))
    assert_true(contains(canonical(), 3, 3, origin))


def test_same_coset_is_the_unknown_answer_and_refinement_can_separate() raises:
    """The conservative-filter contract, and the reason for the non-claim.

    These two points differ, and agree modulo `M Z^3`. Level one therefore says
    nothing about them, and level two separates them.
    """
    var a: List[Int] = [-1, -2, 4]
    var b: List[Int] = [2, -4, -3]
    assert_true(same_coset(canonical(), 3, 1, a, b))
    assert_true(separated(canonical(), 3, 2, a, b))
    assert_false(same_coset_means_equal())


def test_separation_is_the_only_certificate() raises:
    var a: List[Int] = [1, 0, 0]
    var b: List[Int] = [0, 0, 0]
    assert_true(separated(canonical(), 3, 1, a, b))
    assert_false(same_coset(canonical(), 3, 1, a, b))
    assert_false(carrier_is_scalar_padic())


def test_far_apart_coordinates_do_not_wrap() raises:
    """Review found this: the difference was formed in `Int` before the lift.

    With `M = [3]`, `a = 2^63 - 1` and `b = -2` the true difference is `2^63 + 1`
    and divisible by three, so the points share a coset. The wrapped 64-bit
    difference is not divisible by three, so the carrier used to issue a false
    separation certificate here -- the one thing it claims to be able to certify.
    """
    var m: List[Int] = [3]
    var a: List[Int] = [9223372036854775807]
    var b: List[Int] = [-2]
    assert_true(same_coset(m, 1, 1, a, b))
    assert_false(separated(m, 1, 1, a, b))


def test_index_subsets_enumerates_each_subset_once() raises:
    assert_equal(len(index_subsets(3, 0)), 1)
    assert_equal(len(index_subsets(3, 1)), 3)
    assert_equal(len(index_subsets(3, 2)), 3)
    assert_equal(len(index_subsets(3, 3)), 1)
    assert_equal(len(index_subsets(4, 2)), 6)
    var pairs = index_subsets(3, 2)
    assert_equal(pairs[0][0], 0)
    assert_equal(pairs[0][1], 1)


def main() raises:
    test_quotient_order_is_the_absolute_determinant()
    print("[PASS] test_quotient_order_is_the_absolute_determinant")
    test_the_quotient_need_not_be_cyclic()
    print("[PASS] test_the_quotient_need_not_be_cyclic")
    test_the_invariant_factors_change_shape_with_the_level()
    print("[PASS] test_the_invariant_factors_change_shape_with_the_level")
    test_the_unit_branch_has_a_trivial_filtration()
    print("[PASS] test_the_unit_branch_has_a_trivial_filtration")
    test_membership_of_the_lattice()
    print("[PASS] test_membership_of_the_lattice")
    test_same_coset_is_the_unknown_answer_and_refinement_can_separate()
    print("[PASS] test_same_coset_is_the_unknown_answer_and_refinement_can_separate")
    test_separation_is_the_only_certificate()
    print("[PASS] test_separation_is_the_only_certificate")
    test_far_apart_coordinates_do_not_wrap()
    print("[PASS] test_far_apart_coordinates_do_not_wrap")
    test_index_subsets_enumerates_each_subset_once()
    print("[PASS] test_index_subsets_enumerates_each_subset_once")
    print("9 M-adic ball Mojo tests passed.")
