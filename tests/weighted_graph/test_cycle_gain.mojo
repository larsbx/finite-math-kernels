"""Regressions for exact weighted cycle-lattice gains."""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.rat_q import Q
from weighted_graph.cycle_gain import (
    WeightedEdge,
    checked_graph,
    cycle_gain,
    fundamental_cycle_gains,
    fundamental_cycles,
    gain_equal,
    signed_cycle_is_closed,
)


def qvec1(a: Int) -> List[Q]:
    return [Q(Int64(a), 1)]


def qvec2(a: Int, b: Int) -> List[Q]:
    return [Q(Int64(a), 1), Q(Int64(b), 1)]


def test_triangle_gain() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 1, qvec2(1, 0)))
    edges.append(WeightedEdge(1, 2, qvec2(0, 1)))
    edges.append(WeightedEdge(2, 0, qvec2(1, 1)))
    var g = checked_graph(3, edges)
    var p = fundamental_cycle_gains(g)
    assert_equal(len(p.cycles), 1)
    assert_true(signed_cycle_is_closed(g, p.cycles[0]))
    assert_true(gain_equal(p.gains[0], qvec2(2, 2)))


def test_parallel_edges_preserve_multiplicity() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 1, qvec1(1)))
    edges.append(WeightedEdge(0, 1, qvec1(3)))
    var g = checked_graph(2, edges)
    var p = fundamental_cycle_gains(g)
    assert_equal(len(p.cycles), 1)
    # second edge forward plus first edge backwards
    assert_true(gain_equal(p.gains[0], qvec1(2)))


def test_self_loop_is_its_own_cycle() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 0, qvec1(7)))
    var g = checked_graph(1, edges)
    var p = fundamental_cycle_gains(g)
    assert_equal(len(p.cycles), 1)
    assert_true(gain_equal(p.gains[0], qvec1(7)))


def test_tree_has_no_cycle_generators() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 1, qvec1(2)))
    edges.append(WeightedEdge(1, 2, qvec1(5)))
    var g = checked_graph(3, edges)
    assert_equal(len(fundamental_cycles(g)), 0)


def test_two_cycle_multigraph_is_deterministic() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 1, qvec1(1)))
    edges.append(WeightedEdge(1, 2, qvec1(2)))
    edges.append(WeightedEdge(2, 0, qvec1(3)))
    edges.append(WeightedEdge(0, 2, qvec1(10)))
    var g = checked_graph(3, edges)
    var p = fundamental_cycle_gains(g)
    assert_equal(len(p.cycles), 2)
    assert_true(gain_equal(p.gains[0], qvec1(6)))
    # edge 0->2 closes against tree path 2->1->0, hence 10 - 2 - 1.
    assert_true(gain_equal(p.gains[1], qvec1(7)))


def test_rejects_incomplete_and_malformed_inputs() raises:
    var edges = List[WeightedEdge]()
    edges.append(WeightedEdge(0, 1, qvec1(1)))
    edges.append(WeightedEdge(1, 0, qvec1(1)))
    var incomplete = checked_graph(2, edges, False)
    var caught = False
    try:
        _ = fundamental_cycles(incomplete)
    except:
        caught = True
    assert_true(caught)

    var bad_dimension = List[WeightedEdge]()
    bad_dimension.append(WeightedEdge(0, 1, qvec1(1)))
    bad_dimension.append(WeightedEdge(1, 0, qvec2(1, 2)))
    caught = False
    try:
        _ = checked_graph(2, bad_dimension)
    except:
        caught = True
    assert_true(caught)

    var bad_vertex = List[WeightedEdge]()
    bad_vertex.append(WeightedEdge(0, 2, qvec1(1)))
    caught = False
    try:
        _ = checked_graph(2, bad_vertex)
    except:
        caught = True
    assert_true(caught)


def main() raises:
    test_triangle_gain()
    print("[PASS] test_triangle_gain")
    test_parallel_edges_preserve_multiplicity()
    print("[PASS] test_parallel_edges_preserve_multiplicity")
    test_self_loop_is_its_own_cycle()
    print("[PASS] test_self_loop_is_its_own_cycle")
    test_tree_has_no_cycle_generators()
    print("[PASS] test_tree_has_no_cycle_generators")
    test_two_cycle_multigraph_is_deterministic()
    print("[PASS] test_two_cycle_multigraph_is_deterministic")
    test_rejects_incomplete_and_malformed_inputs()
    print("[PASS] test_rejects_incomplete_and_malformed_inputs")
    print("6 weighted cycle-gain Mojo tests passed.")
