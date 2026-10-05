"""Strongly connected components, cycles, and the disjoint-set forest.

Run with `pixi run test-finite-graph`.

Components are compared as sets of vertices, which is what Tarjan's algorithm
promises; the emission order is pinned only where it is the contract: a sink
component is emitted before anything that reaches it.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_graph.scc import has_cycle, sccs
from finite_graph.union_find import find_root, singletons, union


def component_of(comps: List[List[Int]], v: Int) -> Int:
    for c in range(len(comps)):
        for i in range(len(comps[c])):
            if comps[c][i] == v:
                return c
    return -1


def test_components_partition_the_vertices() raises:
    # 0 <-> 1 -> 2 -> 3 -> 2, 4 alone with a loop, 5 alone without one.
    var adj: List[List[Int]] = [[1], [0, 2], [3], [2], [4], [0]]
    var comps = sccs(adj)
    assert_equal(len(comps), 4)
    assert_equal(component_of(comps, 0), component_of(comps, 1))
    assert_equal(component_of(comps, 2), component_of(comps, 3))
    assert_true(component_of(comps, 0) != component_of(comps, 2))
    # Reverse topological order: the sink {2, 3} before {0, 1}, and {0, 1}
    # before 5, which reaches it.
    assert_true(component_of(comps, 2) < component_of(comps, 0))
    assert_true(component_of(comps, 0) < component_of(comps, 5))
    assert_true(has_cycle(adj, comps[component_of(comps, 0)]))
    assert_true(has_cycle(adj, comps[component_of(comps, 4)]))
    assert_false(has_cycle(adj, comps[component_of(comps, 5)]))


def test_a_long_path_does_not_recurse() raises:
    var n = 200000
    var adj = List[List[Int]]()
    for v in range(n):
        var out = List[Int]()
        if v + 1 < n:
            out.append(v + 1)
        adj.append(out^)
    adj[n - 1].append(0)
    var comps = sccs(adj)
    assert_equal(len(comps), 1)
    assert_equal(len(comps[0]), n)


def test_union_find_merges_classes() raises:
    var parent = singletons(6)
    union(parent, 0, 1)
    union(parent, 2, 3)
    union(parent, 1, 3)
    assert_equal(find_root(parent, 3), find_root(parent, 0))
    assert_equal(find_root(parent, 0), 0)
    assert_true(find_root(parent, 4) != find_root(parent, 5))
    assert_equal(find_root(parent, 5), 5)


def main() raises:
    test_components_partition_the_vertices()
    print("[PASS] test_components_partition_the_vertices")
    test_a_long_path_does_not_recurse()
    print("[PASS] test_a_long_path_does_not_recurse")
    test_union_find_merges_classes()
    print("[PASS] test_union_find_merges_classes")
    print("3 finite_graph tests passed.")
