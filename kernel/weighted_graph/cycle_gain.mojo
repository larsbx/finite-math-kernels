"""Exact additive gains on the integer cycle lattice of a finite directed graph.

The graph is directed, but the cycle lattice is the kernel over Z of its signed
vertex-edge incidence map. A deterministic spanning forest of the underlying
multigraph gives one fundamental signed cycle for each non-tree edge. Traversing
an edge against its stored direction contributes coefficient -1 and therefore
the negative of its exact gain.

This package deliberately stops at an exact generator presentation. Canonical
normalization of the generated Z-module is a separate layer: rational-span
equality is not subgroup equality and must not be substituted for it.

Incomplete/capped graphs are rejected rather than interpreted.

References: the fundamental cycles of a spanning forest, one per non-tree
edge, form a basis of the integer cycle lattice: G. Kirchhoff, "Ueber die
Aufloesung der Gleichungen, auf welche man bei der Untersuchung der linearen
Vertheilung galvanischer Stroeme gefuehrt wird", Ann. Phys. Chem. 72 (1847)
497-508; T. Kavitha, C. Liebchen, K. Mehlhorn, D. Michail, R. Rizzi, T.
Ueckerdt and K. A. Zweig, "Cycle bases in graphs: characterization,
algorithms, complexity, and applications", Computer Science Review 3 (2009)
199-243, section 2. This is not Karp's minimum mean cycle: no cycle is
optimised here.
"""

from finite_exact.rat_q import Q


struct WeightedEdge(Copyable, Movable):
    var source: Int
    var target: Int
    var gain: List[Q]

    def __init__(out self, source: Int, target: Int, gain: List[Q]):
        self.source = source
        self.target = target
        self.gain = gain.copy()


struct WeightedDigraph(Copyable, Movable):
    var vertex_count: Int
    var edges: List[WeightedEdge]
    var gain_dimension: Int
    var complete: Bool

    def __init__(
        out self,
        vertex_count: Int,
        edges: List[WeightedEdge],
        gain_dimension: Int,
        complete: Bool,
    ):
        self.vertex_count = vertex_count
        self.edges = edges.copy()
        self.gain_dimension = gain_dimension
        self.complete = complete


struct SignedCycle(Copyable, Movable):
    """A signed edge vector in the integer cycle lattice."""

    var edge_indices: List[Int]
    var coefficients: List[Int]

    def __init__(
        out self, edge_indices: List[Int], coefficients: List[Int]
    ):
        self.edge_indices = edge_indices.copy()
        self.coefficients = coefficients.copy()


struct CycleGainPresentation(Copyable, Movable):
    """Deterministic fundamental cycles and their exact additive gains."""

    var cycles: List[SignedCycle]
    var gains: List[List[Q]]

    def __init__(
        out self, cycles: List[SignedCycle], gains: List[List[Q]]
    ):
        self.cycles = cycles.copy()
        self.gains = gains.copy()


def checked_graph(
    vertex_count: Int,
    edges: List[WeightedEdge],
    complete: Bool = True,
) raises -> WeightedDigraph:
    if vertex_count <= 0:
        raise Error("weighted graph requires at least one vertex")
    if len(edges) == 0:
        return WeightedDigraph(vertex_count, edges, 0, complete)

    var dimension = len(edges[0].gain)
    if dimension <= 0:
        raise Error("weighted graph gains require a positive coordinate dimension")

    for i in range(len(edges)):
        var e = edges[i].copy()
        if e.source < 0 or e.source >= vertex_count:
            raise Error("weighted edge source is outside the vertex range")
        if e.target < 0 or e.target >= vertex_count:
            raise Error("weighted edge target is outside the vertex range")
        if len(e.gain) != dimension:
            raise Error("weighted edge gains disagree on coordinate dimension")
        for j in range(dimension):
            if e.gain[j].rejected:
                raise Error("weighted edge contains a rejected exact gain")
    return WeightedDigraph(vertex_count, edges, dimension, complete)


def _require_complete(g: WeightedDigraph) raises:
    if not g.complete:
        raise Error("cycle gains are undefined for an incomplete graph")


def _find(parent: List[Int], x: Int) -> Int:
    var r = x
    while parent[r] != r:
        r = parent[r]
    return r


def _tree_path(
    g: WeightedDigraph,
    tree_adj: List[List[Int]],
    start: Int,
    goal: Int,
) raises -> SignedCycle:
    """Signed tree path from start to goal, stored as edge/coefficient pairs."""
    if start == goal:
        return SignedCycle(List[Int](), List[Int]())

    var previous_vertex = List[Int]()
    var previous_edge = List[Int]()
    for _ in range(g.vertex_count):
        previous_vertex.append(-2)
        previous_edge.append(-1)
    previous_vertex[start] = -1

    var queue = List[Int]()
    queue.append(start)
    var head = 0
    while head < len(queue) and previous_vertex[goal] == -2:
        var v = queue[head]
        head += 1
        for j in range(len(tree_adj[v])):
            var ei = tree_adj[v][j]
            var e = g.edges[ei].copy()
            var w = e.target if e.source == v else e.source
            if previous_vertex[w] != -2:
                continue
            previous_vertex[w] = v
            previous_edge[w] = ei
            queue.append(w)

    if previous_vertex[goal] == -2:
        raise Error("non-tree edge endpoints are disconnected in the spanning forest")

    # Reconstruct backwards. Edge order is irrelevant to the additive gain, but
    # each coefficient records the forward traversal orientation start -> goal.
    var edges = List[Int]()
    var coefficients = List[Int]()
    var current = goal
    while current != start:
        var parent_vertex = previous_vertex[current]
        var ei = previous_edge[current]
        if parent_vertex < 0 or ei < 0:
            raise Error("broken spanning-tree predecessor chain")
        var e = g.edges[ei].copy()
        var coefficient = 1 if e.source == parent_vertex and e.target == current else -1
        edges.append(ei)
        coefficients.append(coefficient)
        current = parent_vertex
    return SignedCycle(edges, coefficients)


def signed_cycle_is_closed(g: WeightedDigraph, c: SignedCycle) -> Bool:
    if len(c.edge_indices) != len(c.coefficients):
        return False
    var boundary = List[Int]()
    for _ in range(g.vertex_count):
        boundary.append(0)
    for k in range(len(c.edge_indices)):
        var ei = c.edge_indices[k]
        var coefficient = c.coefficients[k]
        if ei < 0 or ei >= len(g.edges):
            return False
        if coefficient != 1 and coefficient != -1:
            return False
        var e = g.edges[ei].copy()
        boundary[e.source] -= coefficient
        boundary[e.target] += coefficient
    for v in range(g.vertex_count):
        if boundary[v] != 0:
            return False
    return True


def fundamental_cycles(g: WeightedDigraph) raises -> List[SignedCycle]:
    """Deterministic Z-basis of the signed cycle lattice of the multigraph."""
    _require_complete(g)

    var parent = List[Int]()
    for i in range(g.vertex_count):
        parent.append(i)

    var is_tree_edge = List[Bool]()
    for _ in range(len(g.edges)):
        is_tree_edge.append(False)

    var tree_adj = List[List[Int]]()
    for _ in range(g.vertex_count):
        tree_adj.append(List[Int]())

    # Kruskal without weights: scan edge order and keep exactly the edges that
    # join distinct underlying components. Parallel edges and self-loops then
    # become non-tree generators, as they must in the multigraph cycle lattice.
    for i in range(len(g.edges)):
        var e = g.edges[i].copy()
        if e.source == e.target:
            continue
        var a = _find(parent, e.source)
        var b = _find(parent, e.target)
        if a == b:
            continue
        parent[a] = b
        is_tree_edge[i] = True
        tree_adj[e.source].append(i)
        tree_adj[e.target].append(i)

    var out = List[SignedCycle]()
    for i in range(len(g.edges)):
        if is_tree_edge[i]:
            continue
        var e = g.edges[i].copy()
        var path = _tree_path(g, tree_adj, e.target, e.source)
        var edge_indices = List[Int]()
        var coefficients = List[Int]()
        edge_indices.append(i)
        coefficients.append(1)
        for k in range(len(path.edge_indices)):
            edge_indices.append(path.edge_indices[k])
            coefficients.append(path.coefficients[k])
        var cycle = SignedCycle(edge_indices, coefficients)
        if not signed_cycle_is_closed(g, cycle):
            raise Error("fundamental-cycle construction produced a non-closed signed chain")
        out.append(cycle.copy())
    return out^


def cycle_gain(g: WeightedDigraph, c: SignedCycle) raises -> List[Q]:
    _require_complete(g)
    if not signed_cycle_is_closed(g, c):
        raise Error("cycle gain requires a valid closed signed cycle")
    var out = List[Q]()
    for _ in range(g.gain_dimension):
        out.append(Q.zero())
    for k in range(len(c.edge_indices)):
        var e = g.edges[c.edge_indices[k]].copy()
        var coefficient = c.coefficients[k]
        for j in range(g.gain_dimension):
            if coefficient == 1:
                out[j] = out[j].add(e.gain[j])
            else:
                out[j] = out[j].sub(e.gain[j])
            if out[j].rejected:
                raise Error("exact cycle-gain arithmetic rejected")
    return out^


def fundamental_cycle_gains(g: WeightedDigraph) raises -> CycleGainPresentation:
    var cycles = fundamental_cycles(g)
    var gains = List[List[Q]]()
    for i in range(len(cycles)):
        gains.append(cycle_gain(g, cycles[i]))
    return CycleGainPresentation(cycles, gains)


def gain_equal(a: List[Q], b: List[Q]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if not a[i].eq(b[i]):
            return False
    return True
