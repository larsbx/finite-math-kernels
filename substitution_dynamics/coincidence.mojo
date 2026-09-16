"""Column coincidence for constant-length substitutions.

Specification: `docs/tuning-substitutions-spec.md`, section 3. For a
substitution of constant length `q`, `column_coincidence` finds the least
`k` such that some column `j` of `sigma^k` is constant over the alphabet,
together with the base-`q` digits of `j` (one column choice per level), or
reports that no such column exists. The search is breadth-first over subsets
of the alphabet and therefore exact and complete.

The predicate is finite combinatorics. Whether it decides pure discrete
spectrum (Dekking's theorem, with its height hypothesis) is the consumer's
imported theorem, not this module's claim.

Reference oracle: `tools/tuning_reference.py`.
"""

from substitution_dynamics.substitution import Substitution


struct CoincidenceWitness(Copyable, Movable):
    """`found` with the least depth and its column digits, or `found == False`
    with `depth == -1` and no digits."""

    var found: Bool
    var depth: Int
    var columns: List[Int]

    def __init__(out self, found: Bool, depth: Int, columns: List[Int]):
        self.found = found
        self.depth = depth
        self.columns = columns.copy()


def constant_length(sigma: Substitution) raises -> Int:
    """The common image length, or an error when the lengths differ."""
    var q = len(sigma.images[0])
    for a in range(1, sigma.size):
        if len(sigma.images[a]) != q:
            raise Error("column coincidence is defined for constant-length substitutions only")
    return q


def is_constant_length(sigma: Substitution) -> Bool:
    var q = len(sigma.images[0])
    for a in range(1, sigma.size):
        if len(sigma.images[a]) != q:
            return False
    return True


def _popcount(mask: Int) -> Int:
    var m = mask
    var c = 0
    while m != 0:
        m = m & (m - 1)
        c += 1
    return c


def column_coincidence(sigma: Substitution) raises -> CoincidenceWitness:
    var q = constant_length(sigma)
    var n = sigma.size
    # Subsets are machine-word bitmasks; 60 letters keep 2^n comfortably inside Int.
    if n > 60:
        raise Error("alphabet too large for the subset search")
    var start = (1 << n) - 1
    if n == 1:
        return CoincidenceWitness(True, 0, List[Int]())

    # Parent tables are filled lazily, as in the reference model: only the
    # subsets the search reaches are stored, never all 2^n of them.
    var parent_mask = Dict[Int, Int]()
    var parent_col = Dict[Int, Int]()
    parent_mask[start] = -1
    parent_col[start] = -1

    var queue = List[Int]()
    queue.append(start)
    var head = 0
    while head < len(queue):
        var s = queue[head]
        head += 1
        for c in range(q):
            var t = 0
            for a in range(n):
                if (s & (1 << a)) != 0:
                    t = t | (1 << sigma.images[a][c])
            if t in parent_mask:
                continue
            parent_mask[t] = s
            parent_col[t] = c
            if _popcount(t) == 1:
                var path = List[Int]()
                var cur = t
                while parent_mask[cur] != -1:
                    path.append(parent_col[cur])
                    cur = parent_mask[cur]
                var columns = List[Int]()
                for i in range(len(path) - 1, -1, -1):
                    columns.append(path[i])
                return CoincidenceWitness(True, len(columns), columns)
            queue.append(t)
    return CoincidenceWitness(False, -1, List[Int]())
