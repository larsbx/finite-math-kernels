"""Balanced-pair mechanics: coincidence boundaries, irreducible blocks,
inflation, normalisation, seeds, and boundary lineage.

Everything here is exact finite combinatorics over one validated
`Substitution`. Nothing asserts finiteness of the automaton or any
conjecture; those belong to the consumer.
"""

from std.os import abort

from substitution_dynamics.substitution import Substitution
from substitution_dynamics.words import Pair


def coincidence_boundaries(u: List[Int], v: List[Int], size: Int) -> List[Int]:
    """Positions `0 = k_0 < ... < k_m = |u|` where the Parikh prefixes agree."""
    var out: List[Int] = [0]
    var pu = List[Int]()
    var pv = List[Int]()
    for _ in range(size):
        pu.append(0)
        pv.append(0)
    for i in range(len(u)):
        pu[u[i]] += 1
        pv[v[i]] += 1
        if pu == pv:
            out.append(i + 1)
    return out^


def _slice(w: List[Int], lo: Int, hi: Int) -> List[Int]:
    var out = List[Int]()
    for i in range(lo, hi):
        out.append(w[i])
    return out^


def decompose(u: List[Int], v: List[Int], size: Int) -> List[Pair]:
    """Cut a balanced pair into its irreducible balanced blocks."""
    var bd = coincidence_boundaries(u, v, size)
    var out = List[Pair]()
    for i in range(len(bd) - 1):
        out.append(Pair(_slice(u, bd[i], bd[i + 1]), _slice(v, bd[i], bd[i + 1])))
    return out^


def normalise(p: Pair) -> Pair:
    """Order the two sides so that `(u, v)` and `(v, u)` are the same state."""
    for i in range(len(p.u)):
        if p.u[i] < p.v[i]:
            return p.copy()
        if p.u[i] > p.v[i]:
            return Pair(p.v, p.u)
    return p.copy()


def inflate_pair(sigma: Substitution, p: Pair) -> Pair:
    """Inflate both sides without cutting into irreducible balanced blocks."""
    return Pair(sigma.apply(p.u), sigma.apply(p.v))


def children(sigma: Substitution, p: Pair) -> List[Pair]:
    """Inflate, cut at every coincidence boundary, normalise each block."""
    var raw = decompose(sigma.apply(p.u), sigma.apply(p.v), sigma.size)
    var out = List[Pair]()
    for i in range(len(raw)):
        out.append(normalise(raw[i]))
    return out^


def seed_states(size: Int) -> List[Pair]:
    """The length-2 swap pairs `(ab, ba)`, `a < b`."""
    var out = List[Pair]()
    for a in range(size):
        for b in range(a + 1, size):
            var u: List[Int] = [a, b]
            var v: List[Int] = [b, a]
            out.append(Pair(u, v))
    return out^


def _contains_int(xs: List[Int], x: Int) -> Bool:
    for i in range(len(xs)):
        if xs[i] == x:
            return True
    return False


def inherited_boundary_positions(sigma: Substitution, u: List[Int], v: List[Int]) -> List[Int]:
    """Next-step zero-return positions inherited from current zero-return cuts."""
    var old = coincidence_boundaries(u, v, sigma.size)
    var upos = sigma.image_prefix_lengths(u)
    var vpos = sigma.image_prefix_lengths(v)
    var out = List[Int]()
    for i in range(len(old)):
        var k = old[i]
        # Balanced prefixes have the same Parikh vector, hence equal image
        # length. A disagreement is an internal invariant violation, not a
        # negative answer: returning an empty list would relabel inherited
        # cuts as newborn.
        if upos[k] != vpos[k]:
            abort("inherited boundary image lengths disagree")
        out.append(upos[k])
    return out^


def newborn_boundary_positions(sigma: Substitution, p: Pair) -> List[Int]:
    """Zero-return cuts created by one inflation rather than inherited."""
    var q = inflate_pair(sigma, p)
    var current = coincidence_boundaries(q.u, q.v, sigma.size)
    var inherited = inherited_boundary_positions(sigma, p.u, p.v)
    var out = List[Int]()
    for i in range(len(current)):
        if not _contains_int(inherited, current[i]):
            out.append(current[i])
    return out^


def sync_after(h: List[Int], a: Int, b: Int) -> Int:
    """Least endpoint-map iterate at which `a,b` coalesce, or -1 if never.

    For a finite map on `n` letters, `2n+1` transitions decide whether two
    forward orbits ever meet.
    """
    var x = a
    var y = b
    var bound = 2 * len(h) + 1
    for m in range(bound + 1):
        if x == y:
            return m
        x = h[x]
        y = h[y]
    return -1


def synchronizing_boundary_positions(
    sigma: Substitution, u: List[Int], v: List[Int], positions: List[Int]
) -> List[Int]:
    """Subset of zero-return positions caught by prefix/suffix synchronization."""
    var plus = sigma.prefix_endpoint_map()
    var minus = sigma.suffix_endpoint_map()
    var out = List[Int]()
    for i in range(len(positions)):
        var k = positions[i]
        var hit = False
        if k < len(u) and sync_after(plus, u[k], v[k]) >= 0:
            hit = True
        if k > 0 and sync_after(minus, u[k - 1], v[k - 1]) >= 0:
            hit = True
        if hit:
            out.append(k)
    return out^


def newborn_sync_positions(sigma: Substitution, p: Pair) -> List[Int]:
    """Newborn zero-return cuts whose adjacent endpoint pair synchronizes."""
    var q = inflate_pair(sigma, p)
    var newborn = newborn_boundary_positions(sigma, p)
    return synchronizing_boundary_positions(sigma, q.u, q.v, newborn)


def inherited_sync_positions(sigma: Substitution, p: Pair) -> List[Int]:
    """Inherited zero-return cuts whose adjacent endpoint pair synchronizes."""
    var q = inflate_pair(sigma, p)
    var current = coincidence_boundaries(q.u, q.v, sigma.size)
    var inherited = inherited_boundary_positions(sigma, p.u, p.v)
    var inherited_current = List[Int]()
    for i in range(len(current)):
        if _contains_int(inherited, current[i]):
            inherited_current.append(current[i])
    return synchronizing_boundary_positions(sigma, q.u, q.v, inherited_current)
