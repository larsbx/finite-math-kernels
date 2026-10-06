"""Finite F2 signing diagnostics for directed graphs.

This module encodes a Perron-compatibility test for signed irreducible graphs
(first written for the signed minimal-defect obstruction programme of
`larsbx/pisot-substitution-conjecture-research`).  It is finite and exact:
edge signs are bits in F2, the directed period is computed by a gcd of cycle
length obstructions, and Perron compatibility is tested by solving a coboundary
system over F2.

Mathematical contract
---------------------
For an irreducible directed graph with no orientation cancellation, encode the
sign of every support edge by b(e)=0 for + and b(e)=1 for -.  Let h be the graph
period and let lambda(e) be the wrap cochain for a cyclic decomposition.  The
signing is Perron-compatible exactly when, for q in {0,1}, there is a vertex
potential x with

    b(e) = x(src(e)) + x(dst(e)) + q*lambda(e)  mod 2.

If neither q works, the signing is Perron-strict.  This is a graph/signing
classifier only: what a consumer concludes from it is the consumer's import.

References: the period and cyclic classes of an irreducible non-negative
matrix (its imprimitivity index and Frobenius normal form) are G. Frobenius,
"Ueber Matrizen aus nicht negativen Elementen", Sitzungsber. Preuss. Akad.
Wiss. (1912) 456-477; see R. A. Brualdi and H. J. Ryser, *Combinatorial Matrix
Theory* (Cambridge, 1991), section 3.4, and E. Seneta, *Non-negative Matrices
and Markov Chains* (2nd ed., Springer, 1981), section 1.3. The F2 coboundary
test for signings is authored here for the consumer named above.
"""

from std.os import abort


struct SignedEdge(Copyable, Movable):
    """A directed support edge with sign bit: 0 = positive, 1 = negative."""

    var src: Int
    var dst: Int
    var bit: Int

    def __init__(out self, src: Int, dst: Int, bit: Int):
        if bit != 0 and bit != 1:
            abort("signed edge bit must be 0 or 1")
        self.src = src
        self.dst = dst
        self.bit = bit


def positive_edge(src: Int, dst: Int) -> SignedEdge:
    return SignedEdge(src, dst, 0)


def negative_edge(src: Int, dst: Int) -> SignedEdge:
    return SignedEdge(src, dst, 1)


def _abs(x: Int) -> Int:
    if x < 0:
        return -x
    return x


def _gcd(a: Int, b: Int) -> Int:
    var x = _abs(a)
    var y = _abs(b)
    while y != 0:
        var r = x % y
        x = y
        y = r
    return x


def _mod2(x: Int) -> Int:
    var r = x % 2
    if r < 0:
        return r + 2
    return r


def _check_vertices(n: Int, edges: List[SignedEdge]) raises:
    if n <= 0:
        abort("graph must have at least one vertex")
    for i in range(len(edges)):
        if edges[i].src < 0 or edges[i].src >= n or edges[i].dst < 0 or edges[i].dst >= n:
            abort("edge endpoint out of range")


def _distances_from_zero(n: Int, edges: List[SignedEdge]) raises -> List[Int]:
    """Breadth-first directed distances from vertex 0.

    The Perron-compatibility routines are intended for SCC support graphs, so
    every vertex should be reachable from 0.  Fail closed if not.
    """
    _check_vertices(n, edges)
    var dist = List[Int]()
    for _ in range(n):
        dist.append(-1)
    var queue = List[Int]()
    dist[0] = 0
    queue.append(0)
    var head = 0
    while head < len(queue):
        var v = queue[head]
        head += 1
        for i in range(len(edges)):
            if edges[i].src == v:
                var w = edges[i].dst
                if dist[w] == -1:
                    dist[w] = dist[v] + 1
                    queue.append(w)
    for v in range(n):
        if dist[v] == -1:
            abort("graph is not reachable from vertex 0; pass one SCC at a time")
    return dist^


def directed_period(n: Int, edges: List[SignedEdge]) raises -> Int:
    """Return gcd of directed cycle lengths for a strongly connected graph.

    Uses the standard exact formula gcd(dist(src)+1-dist(dst)) over all edges.
    For an edgeless singleton, return 1.
    """
    if len(edges) == 0:
        if n == 1:
            return 1
        abort("non-singleton graph has no edges")
    var dist = _distances_from_zero(n, edges)
    var g = 0
    for i in range(len(edges)):
        var delta = dist[edges[i].src] + 1 - dist[edges[i].dst]
        g = _gcd(g, delta)
    if g == 0:
        return 1
    return g


def cyclic_classes(n: Int, edges: List[SignedEdge], h: Int) raises -> List[Int]:
    """Return cyclic class labels 0..h-1 from directed distances modulo h."""
    if h <= 0:
        abort("period must be positive")
    var dist = _distances_from_zero(n, edges)
    var out = List[Int]()
    for v in range(n):
        out.append(_mod2(0))
    for v in range(n):
        var c = dist[v] % h
        if c < 0:
            c += h
        out[v] = c
    return out^


def wrap_bit(edge: SignedEdge, classes: List[Int], h: Int) -> Int:
    """lambda(e): one exactly on cyclic wrap edges C_{h-1}->C_0.

    For h=1 every edge is a wrap edge, which recovers the aperiodic real
    half-phase option S=-N.
    """
    if classes[edge.src] == h - 1 and classes[edge.dst] == 0:
        return 1
    return 0


def compatibility_potential(n: Int, edges: List[SignedEdge], q: Int) raises -> List[Int]:
    """Solve x(src)+x(dst)=b(e)+q*lambda(e) over F2.

    Returns an empty list if inconsistent.  Otherwise returns one potential.
    """
    if q != 0 and q != 1:
        abort("phase q must be 0 or 1")
    var h = directed_period(n, edges)
    var classes = cyclic_classes(n, edges, h)
    var x = List[Int]()
    for _ in range(n):
        x.append(-1)
    x[0] = 0

    var changed = True
    while changed:
        changed = False
        for i in range(len(edges)):
            var rhs = _mod2(edges[i].bit + q * wrap_bit(edges[i], classes, h))
            var s = edges[i].src
            var t = edges[i].dst
            if x[s] != -1 and x[t] == -1:
                x[t] = _mod2(rhs + x[s])
                changed = True
            elif x[s] == -1 and x[t] != -1:
                x[s] = _mod2(rhs + x[t])
                changed = True
            elif x[s] != -1 and x[t] != -1:
                if _mod2(x[s] + x[t]) != rhs:
                    return List[Int]()^
    for v in range(n):
        if x[v] == -1:
            abort("unassigned vertex in compatibility solve; graph is not connected as supplied")
    return x^


def perron_phase(n: Int, edges: List[SignedEdge]) raises -> Int:
    """Return compatible phase q in {0,1}, or -1 when Perron-strict."""
    if len(compatibility_potential(n, edges, 0)) > 0:
        return 0
    if len(compatibility_potential(n, edges, 1)) > 0:
        return 1
    return -1


def is_perron_compatible(n: Int, edges: List[SignedEdge]) raises -> Bool:
    return perron_phase(n, edges) >= 0


def is_perron_strict(n: Int, edges: List[SignedEdge]) raises -> Bool:
    return perron_phase(n, edges) == -1
