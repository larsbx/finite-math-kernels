"""Regression tests for finite F2 Perron-compatible signings."""

from std.testing import assert_equal, assert_false, assert_true
from finite_graph.signing import SignedEdge, positive_edge, negative_edge, directed_period, cyclic_classes, wrap_bit, compatibility_potential, perron_phase, is_perron_compatible, is_perron_strict

def test_positive_loop_is_trivial_phase() raises:
    var edges = List[SignedEdge]()
    edges.append(positive_edge(0, 0))
    assert_equal(directed_period(1, edges), 1)
    assert_equal(perron_phase(1, edges), 0)
    assert_true(is_perron_compatible(1, edges))
    assert_false(is_perron_strict(1, edges))


def test_negative_loop_is_half_phase() raises:
    var edges = List[SignedEdge]()
    edges.append(negative_edge(0, 0))
    assert_equal(directed_period(1, edges), 1)
    assert_equal(perron_phase(1, edges), 1)
    assert_true(is_perron_compatible(1, edges))


def test_two_cycle_with_one_negative_edge_is_half_phase() raises:
    var edges = List[SignedEdge]()
    edges.append(positive_edge(0, 1))
    edges.append(negative_edge(1, 0))
    assert_equal(directed_period(2, edges), 2)
    var classes = cyclic_classes(2, edges, 2)
    assert_equal(classes[0], 0)
    assert_equal(classes[1], 1)
    assert_equal(wrap_bit(edges[0], classes, 2), 0)
    assert_equal(wrap_bit(edges[1], classes, 2), 1)
    assert_equal(perron_phase(2, edges), 1)


def test_two_cycle_with_two_negative_edges_switches_to_positive() raises:
    var edges = List[SignedEdge]()
    edges.append(negative_edge(0, 1))
    edges.append(negative_edge(1, 0))
    assert_equal(directed_period(2, edges), 2)
    assert_equal(perron_phase(2, edges), 0)
    var potential = compatibility_potential(2, edges, 0)
    assert_equal(len(potential), 2)
    assert_equal(potential[0] + potential[1], 1)


def test_mixed_self_loop_signs_are_perron_strict() raises:
    var edges = List[SignedEdge]()
    edges.append(positive_edge(0, 0))
    edges.append(negative_edge(1, 1))
    edges.append(positive_edge(0, 1))
    edges.append(positive_edge(1, 0))
    assert_equal(directed_period(2, edges), 1)
    assert_equal(perron_phase(2, edges), -1)
    assert_false(is_perron_compatible(2, edges))
    assert_true(is_perron_strict(2, edges))


def main() raises:
    test_positive_loop_is_trivial_phase()
    print("[PASS] test_positive_loop_is_trivial_phase")
    test_negative_loop_is_half_phase()
    print("[PASS] test_negative_loop_is_half_phase")
    test_two_cycle_with_one_negative_edge_is_half_phase()
    print("[PASS] test_two_cycle_with_one_negative_edge_is_half_phase")
    test_two_cycle_with_two_negative_edges_switches_to_positive()
    print("[PASS] test_two_cycle_with_two_negative_edges_switches_to_positive")
    test_mixed_self_loop_signs_are_perron_strict()
    print("[PASS] test_mixed_self_loop_signs_are_perron_strict")
    print("5 finite_graph signing tests passed.")
