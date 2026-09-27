"""Regressions for canonical embedded integer-module normal form."""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_eq, bigz_from_i64
from finite_linear_algebra.integer_module import (
    i64_row,
    row_hnf,
    row_hnf_equal,
)


def rows_x_even() -> List[List[BigZ]]:
    var out = List[List[BigZ]]()
    var r0: List[Int64] = [2, 0]
    var r1: List[Int64] = [0, 1]
    out.append(i64_row(r0))
    out.append(i64_row(r1))
    return out^


def rows_x_even_changed() -> List[List[BigZ]]:
    var out = List[List[BigZ]]()
    var r0: List[Int64] = [0, 1]
    var r1: List[Int64] = [2, 0]
    var r2: List[Int64] = [2, 1]
    var r3: List[Int64] = [-2, 0]
    out.append(i64_row(r0))
    out.append(i64_row(r1))
    out.append(i64_row(r2))
    out.append(i64_row(r3))
    return out^


def rows_y_even() -> List[List[BigZ]]:
    var out = List[List[BigZ]]()
    var r0: List[Int64] = [1, 0]
    var r1: List[Int64] = [0, 2]
    out.append(i64_row(r0))
    out.append(i64_row(r1))
    return out^


def assert_row2(row: List[BigZ], a: Int64, b: Int64):
    assert_equal(len(row), 2)
    assert_true(bigz_eq(row[0], bigz_from_i64(a)))
    assert_true(bigz_eq(row[1], bigz_from_i64(b)))


def test_generator_changes_do_not_change_embedded_lattice() raises:
    var canonical = rows_x_even()
    var changed = rows_x_even_changed()
    assert_true(row_hnf_equal(canonical, changed, 2))
    var h = row_hnf(changed, 2)
    assert_equal(len(h), 2)
    assert_row2(h[0], 2, 0)
    assert_row2(h[1], 0, 1)


def test_equal_smith_shape_can_be_different_embedded_lattice() raises:
    var x_even = rows_x_even()
    var y_even = rows_y_even()
    assert_false(row_hnf_equal(x_even, y_even, 2))


def test_rank_deficient_and_zero_generators() raises:
    var rank_one = List[List[BigZ]]()
    var r0: List[Int64] = [2, 4]
    var r1: List[Int64] = [4, 8]
    var r2: List[Int64] = [0, 0]
    rank_one.append(i64_row(r0))
    rank_one.append(i64_row(r1))
    rank_one.append(i64_row(r2))
    var h = row_hnf(rank_one, 2)
    assert_equal(len(h), 1)
    assert_row2(h[0], 2, 4)

    var zero = List[List[BigZ]]()
    zero.append(i64_row(r2))
    zero.append(i64_row(r2))
    assert_equal(len(row_hnf(zero, 2)), 0)


def test_negative_entries_reduce_canonically() raises:
    var rows = List[List[BigZ]]()
    var r0: List[Int64] = [2, 0]
    var r1: List[Int64] = [-1, 1]
    rows.append(i64_row(r0))
    rows.append(i64_row(r1))
    var h = row_hnf(rows, 2)
    assert_equal(len(h), 2)
    assert_row2(h[0], 1, 1)
    assert_row2(h[1], 0, 2)


def main() raises:
    test_generator_changes_do_not_change_embedded_lattice()
    print("[PASS] test_generator_changes_do_not_change_embedded_lattice")
    test_equal_smith_shape_can_be_different_embedded_lattice()
    print("[PASS] test_equal_smith_shape_can_be_different_embedded_lattice")
    test_rank_deficient_and_zero_generators()
    print("[PASS] test_rank_deficient_and_zero_generators")
    test_negative_entries_reduce_canonically()
    print("[PASS] test_negative_entries_reduce_canonically")
    print("4 embedded integer-module Mojo tests passed.")
