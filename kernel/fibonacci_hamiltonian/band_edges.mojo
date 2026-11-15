"""Certified band edges of `{E : |t_k(E)| <= 2}` for the Fibonacci traces.

Specification: docs/fibonacci-hamiltonian-band-edges-spec.md, sections 2-5.
The executable reference is `reference/fibonacci_hamiltonian_reference.py`.

An edge is a bracket of `finite_linear_algebra/real_root_isolation.mojo` for
`t_k - 2` or `t_k + 2`; the brackets of both are halved until they are
ordered, the sign of `|t_k| - 2` is read at one rational between each
consecutive pair, and a band is a maximal run of pairs where it is negative.
Nothing is a root and nothing is a spectrum: a band is two edge indices, and
its enclosures are intervals of `finite_exact.closed_interval`. What the list
of edges is complete for, and what the sublevel set means for an operator,
are the imports of specification section 6.
"""

from finite_exact.closed_interval import IQ
from finite_exact.rat_q import Q, q_abs, q_max
from finite_linear_algebra.qpoly import add, squarefree_part, sub
from finite_linear_algebra.real_root_isolation import halve_bracket, real_root_brackets
from finite_linear_algebra.scalar import q_int
from finite_linear_algebra.sturm_sequence import RootBracket

from .trace_polynomial import constant, trace_polynomial, trace_value


struct Edge(Copyable, Movable):
    """A bracket `lo < hi` holding one point where `t_k` equals `level`, `2` or `-2`."""

    var lo: Q
    var hi: Q
    var level: Int

    def __init__(out self, lo: Q, hi: Q, level: Int):
        self.lo = lo.copy()
        self.hi = hi.copy()
        self.level = level


struct Band(Copyable, Movable):
    """Indices into the edges of an approximant: the band's two ends."""

    var left: Int
    var right: Int

    def __init__(out self, left: Int, right: Int):
        self.left = left
        self.right = right


struct Approximant(Copyable, Movable):
    """The edges of level `k`, ascending, and its bands; or a refusal."""

    var rejected: Bool
    var k: Int
    var edges: List[Edge]
    var bands: List[Band]

    def __init__(out self, rejected: Bool, k: Int, var edges: List[Edge], var bands: List[Band]):
        self.rejected = rejected
        self.k = k
        self.edges = edges^
        self.bands = bands^


def rejected_approximant() -> Approximant:
    return Approximant(True, -1, List[Edge](), List[Band]())


struct Placed(Copyable, Movable):
    """One entry of the merged order: which side, and where in it."""

    var side: Int
    var index: Int

    def __init__(out self, side: Int, index: Int):
        self.side = side
        self.index = index


def merged(upper: List[RootBracket], lower: List[RootBracket]) -> List[Placed]:
    """Both sides in ascending `lo`; the `+2` side goes first on a tie."""
    var out = List[Placed]()
    var i = 0
    var j = 0
    while i < len(upper) or j < len(lower):
        if j == len(lower) or (i < len(upper) and upper[i].lo.le(lower[j].lo)):
            out.append(Placed(0, i))
            i += 1
        else:
            out.append(Placed(1, j))
            j += 1
    return out^


def separated_edges(k: Int, lam: Q, width: Q, max_steps: Int) -> Approximant:
    """The brackets of `t_k - 2` and `t_k + 2`, merged and halved until ordered.

    Returned as an approximant with no bands. On acceptance consecutive edges
    satisfy `hi <= lo`.
    """
    var trace = trace_polynomial(k, lam)
    if len(trace) == 0:
        return rejected_approximant()
    var parts = List[List[Q]]()
    parts.append(squarefree_part(sub(trace, constant(2))))
    parts.append(squarefree_part(add(trace, constant(2))))
    var sides = List[List[RootBracket]]()
    for side in range(2):
        var found = real_root_brackets(parts[side], width, max_steps)
        if found.rejected:
            return rejected_approximant()
        sides.append(found.brackets.copy())
    var steps = 0
    while True:
        var order = merged(sides[0], sides[1])
        var edges = List[Edge]()
        for i in range(len(order)):
            var bracket = sides[order[i].side][order[i].index].copy()
            edges.append(Edge(bracket.lo, bracket.hi, 2 - 4 * order[i].side))
        var clash = -1
        for i in range(len(edges) - 1):
            if edges[i + 1].lo.lt(edges[i].hi):
                clash = i
                break
        if clash < 0:
            return Approximant(False, k, edges^, List[Band]())
        for i in range(clash, clash + 2):
            if steps >= max_steps:
                return rejected_approximant()
            steps += 1
            var side = order[i].side
            var index = order[i].index
            sides[side][index] = halve_bracket(parts[side], edges[i].lo, edges[i].hi)


def approximant(k: Int, lam: Q, width: Q, max_steps: Int) -> Approximant:
    """The bands of `{E : |t_k(E)| <= 2}` between certified edges, or a refusal.

    A level below zero, an exhausted `max_steps`, a value of exactly `2` in
    modulus between two edges, and an edge with `|t_k| > 2` on both sides are
    refused.
    """
    var separated = separated_edges(k, lam, width, max_steps)
    if separated.rejected or len(separated.edges) == 0:
        return rejected_approximant()
    var edges = separated.edges.copy()
    var two = q_int(2)
    var inside = List[Bool]()
    for i in range(len(edges) - 1):
        var point = edges[i].hi.add(edges[i + 1].lo).div(two)
        var modulus = q_abs(trace_value(k, lam, point))
        if modulus.eq(two):
            return rejected_approximant()
        inside.append(modulus.lt(two))
    var bands = List[Band]()
    var start = 0
    for i in range(len(edges)):
        var before = i > 0 and inside[i - 1]
        var after = i < len(inside) and inside[i]
        if not before and not after:
            return rejected_approximant()
        if after and not before:
            start = i
        if before and not after:
            bands.append(Band(start, i))
    return Approximant(False, k, edges^, bands^)


def outer_bands(a: Approximant) -> List[IQ]:
    """`[left.lo, right.hi]` per band: each contains its band."""
    var out = List[IQ]()
    for i in range(len(a.bands)):
        out.append(IQ(a.edges[a.bands[i].left].lo, a.edges[a.bands[i].right].hi))
    return out^


def inner_bands(a: Approximant) -> List[IQ]:
    """`[left.hi, right.lo]` per band: each is contained in its band."""
    var out = List[IQ]()
    for i in range(len(a.bands)):
        out.append(IQ(a.edges[a.bands[i].left].hi, a.edges[a.bands[i].right].lo))
    return out^


def gap_bounds(a: Approximant) -> List[IQ]:
    """`[lower, upper]` for the length of each gap between consecutive bands."""
    var out = List[IQ]()
    for i in range(len(a.bands) - 1):
        var left = a.edges[a.bands[i].right].copy()
        var right = a.edges[a.bands[i + 1].left].copy()
        out.append(IQ(right.lo.sub(left.hi), right.hi.sub(left.lo)))
    return out^


def closed_gaps(a: Approximant) -> Int:
    """Edges interior to a band: `|t_k| < 2` on both sides."""
    return len(a.edges) - 2 * len(a.bands)


def cover(first: Approximant, second: Approximant) -> List[IQ]:
    """The outer band enclosures of both levels, merged into ascending disjoint intervals."""
    var a = outer_bands(first)
    var b = outer_bands(second)
    var out = List[IQ]()
    var i = 0
    var j = 0
    while i < len(a) or j < len(b):
        var from_first = j == len(b) or (i < len(a) and a[i].lo.le(b[j].lo))
        var next = a[i].copy() if from_first else b[j].copy()
        if from_first:
            i += 1
        else:
            j += 1
        if len(out) > 0 and next.lo.le(out[len(out) - 1].hi):
            var last = out.pop()
            out.append(IQ(last.lo, q_max(last.hi, next.hi)))
        else:
            out.append(next^)
    return out^
