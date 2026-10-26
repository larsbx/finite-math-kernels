"""Finite permutohedral CW topology is in exact Mojo, not a Python reimplementation.

The expected P3/P4/P5/P6 cell vectors and incidence signs come from the
classical ordered-partition face poset. No new theorem or model-training
coherence is claimed by this bounded test.
"""
from std.testing import assert_equal, assert_true, assert_false
from finite_graph.permutohedral_cells import (
    valid_face, face_dimension, facets, doubled_center, same_face,
    signed_incidence, boundary_squared_zero, face_vector
)


def face(values: List[Int]) -> List[Int]:
    return values.copy()


def test_expected_cell_vectors() raises:
    var a = face_vector(3)
    assert_equal(len(a), 3)
    assert_equal(a[0], 6)
    assert_equal(a[1], 6)
    assert_equal(a[2], 1)
    var b = face_vector(4)
    assert_equal(b[0], 24)
    assert_equal(b[1], 36)
    assert_equal(b[2], 14)
    assert_equal(b[3], 1)
    var c = face_vector(5)
    assert_equal(c[0], 120)
    assert_equal(c[1], 240)
    assert_equal(c[2], 150)
    assert_equal(c[3], 30)
    assert_equal(c[4], 1)
    var d = face_vector(6)
    assert_equal(d[0], 720)
    assert_equal(d[1], 1800)
    assert_equal(d[2], 1560)
    assert_equal(d[3], 540)
    assert_equal(d[4], 62)
    assert_equal(d[5], 1)
    assert_equal(len(face_vector(7)), 0)


def test_square_hexagon_and_top_boundaries() raises:
    var square: List[Int] = [0, 0, 1, 1, 2, 3]
    var hexagon: List[Int] = [0, 0, 0, 1, 2, 3]
    var p5_facet: List[Int] = [0, 0, 0, 0, 0, 1]
    var p6_top: List[Int] = [0, 0, 0, 0, 0, 0]
    assert_true(valid_face(square, 6))
    assert_equal(face_dimension(square, 6), 2)
    assert_equal(len(facets(square, 6)), 4)
    assert_equal(face_dimension(hexagon, 6), 2)
    assert_equal(len(facets(hexagon, 6)), 6)
    assert_equal(len(facets(p5_facet, 6)), 30)
    assert_equal(len(facets(p6_top, 6)), 62)
    assert_true(boundary_squared_zero(square, 6))
    assert_true(boundary_squared_zero(hexagon, 6))
    assert_true(boundary_squared_zero(p5_facet, 6))
    assert_true(boundary_squared_zero(p6_top, 6))
    var bary = doubled_center(square, 6)
    assert_equal(bary[0], 3)
    assert_equal(bary[2], 7)
    assert_equal(bary[4], 10)
    assert_equal(bary[5], 12)


def test_orientations_with_lower_rank_crosscheck() raises:
    var p5_parent: List[Int] = [0, 0, 0, 0, 0]
    var p6_parent: List[Int] = [0, 0, 0, 0, 0, 1]
    var p5_child: List[Int] = [0, 0, 1, 1, 1]
    var p6_child: List[Int] = [0, 0, 1, 1, 1, 2]
    var p5_sign = signed_incidence(p5_parent, p5_child, 5)
    var p6_sign = signed_incidence(p6_parent, p6_child, 6)
    assert_true(p5_sign == 1 or p5_sign == -1)
    assert_equal(p5_sign, p6_sign)
    # Every supplied signed facet must be an actual one-step refinement.
    assert_equal(signed_incidence(p6_child, p6_parent, 6), 0)
    assert_equal(signed_incidence(p6_parent, p6_parent, 6), 0)
    var bad: List[Int] = [0, 0, 2, 2, 3, 4]  # skipped block 1
    assert_false(valid_face(bad, 6))
    assert_false(boundary_squared_zero(bad, 6))
    assert_equal(len(facets(bad, 6)), 0)


def main() raises:
    test_expected_cell_vectors()
    print("[PASS] Mojo P3-P6 exact face vectors")
    test_square_hexagon_and_top_boundaries()
    print("[PASS] Mojo square/hexagon/P5 facet/P6 top integer d^2=0")
    test_orientations_with_lower_rank_crosscheck()
    print("[PASS] oriented P5 facet compatibility and malformed face rejection")
