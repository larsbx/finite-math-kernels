# finite_graph: domain-neutral finite directed graphs on vertices 0..n-1.
#
#   scc         strongly connected components (iterative Tarjan) of an
#               adjacency list, and whether a component carries a cycle.
#   union_find  disjoint-set forest: find and union on a parent array.
#   signing     F2 edge signings: directed period, cyclic classes, wrap
#               cochain, and the Perron-compatibility coboundary test.
#
# The package computes finite graph facts. It assigns no meaning to a vertex,
# an edge, or a component; that is the consumer's.
