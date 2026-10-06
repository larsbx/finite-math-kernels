"""The lattice of return vectors of length-`n` patches, exactly.

Return words: F. Durand, "A characterization of substitutive sequences using
return words", Discrete Mathematics 179 (1998) 89-101. This module computes
the lattice their Parikh vectors span, per factor length.

For a primitive `sigma` on `{0, ..., d-1}`, the return lattice `Lambda_n` is
the subgroup of `Z^d` spanned by the Parikh vectors `p(x[i, j))` over every
pair of occurrences `i < j` of one length-`n` factor of the language, and
`[Z^d : Lambda_n]` measures how far the return vectors of radius-`n` patches
fall short of spanning `Z^d`.

**Exact route.** `Lambda_n` is the image of the cycle space of the order-`n`
Rauzy graph `G_n` under the edge cocycle `f(w) = e_{w[0]}`: vertices are the
length-`n` factors, edges the length-`n+1` factors `w : w[0, n) -> w[1, n+1)`.
A character `chi` of `Z^d` kills `Lambda_n` iff the position map
`i -> chi(p(x[0, i)))` factors through the length-`n` window at `i`, iff
`chi . f` is a coboundary on `G_n` (every vertex and every edge occurs in the
fixed point), iff `chi . f` kills `H_1(G_n)`. So the two lattices have the same
characters and are equal. `H_1` is spanned by one fundamental cycle per
non-tree edge of a spanning tree; the factor sets are closed exactly under
`sigma`, with no sampling anywhere.

**Independent route.** `sampled_return_index` reads the returns off a prefix of
`sigma^k(0)` and shares no step with the Rauzy graph. Every displacement it
sees is a genuine return, so it spans a sublattice of `Lambda_n` and its index
is a multiple of the exact one.

Integer arithmetic is checked: a run that would overflow raises rather than
reporting a wrapped index, and a rank-deficient lattice -- impossible for a
primitive substitution with a nonsingular incidence matrix -- raises rather
than reporting index `0`. Factors are keyed as base-`d` integers, so the
factor length is capped at `max_factor_length(d)`.
"""

from finite_exact.checked_int import checked_add, checked_mul, checked_sub
from substitution_dynamics.substitution import Substitution


def max_factor_length(size: Int) -> Int:
    """The longest factor whose base-`size` key fits a machine integer: the
    largest `L` with `size^L - 1 <= Int.MAX` (`39` on three letters, `63` on
    two). On one letter every key is `0`, so no length is refused for its key.

    Accumulating a key as `k * size + letter` never passes its final value, so
    no step of `_key` overflows at a length this admits."""
    if size < 2:
        return Int.MAX
    var length = 0
    var largest = 0  # size^length - 1, the largest key of that length
    while largest <= (Int.MAX - (size - 1)) // size:
        largest = largest * size + (size - 1)
        length += 1
    return length


struct TriangularLattice(Copyable, Movable):
    """A sublattice of `Z^size` in Hermite normal form: `rows[c]` is empty or
    has its positive pivot in column `c`, zeros before it, and entries after it
    reduced into `[0, pivot)` of the row that owns that column."""

    var rows: List[List[Int]]
    var size: Int

    def __init__(out self, size: Int):
        self.size = size
        self.rows = List[List[Int]](length=size, fill=List[Int]())

    def insert(mut self, v: List[Int]) raises:
        """Add one generator, by the extended Euclidean step per column."""
        if len(v) != self.size:
            raise Error("a lattice generator has one coordinate per letter")
        var w = v.copy()
        for c in range(self.size):
            if w[c] == 0:
                continue
            if len(self.rows[c]) == 0:
                self.rows[c] = _positive(w)
                self._reduce()
                return
            var p = self.rows[c].copy()
            while w[c] != 0:
                var q = p[c] // w[c]
                var r = List[Int]()
                for i in range(self.size):
                    r.append(checked_sub(p[i], checked_mul(q, w[i])))
                p = w^
                w = r^
            self.rows[c] = _positive(p)
        self._reduce()

    def _reduce(mut self) raises:
        for c in range(self.size):
            if len(self.rows[c]) == 0:
                continue
            for r in range(c):
                if len(self.rows[r]) == 0:
                    continue
                var q = self.rows[r][c] // self.rows[c][c]
                for i in range(self.size):
                    self.rows[r][i] = checked_sub(
                        self.rows[r][i], checked_mul(q, self.rows[c][i])
                    )

    def rank(self) -> Int:
        var n = 0
        for c in range(self.size):
            if len(self.rows[c]) > 0:
                n += 1
        return n

    def index(self) raises -> Int:
        """`[Z^size : L]`, the product of the pivots. Raises on deficient rank."""
        if self.rank() < self.size:
            raise Error("return lattice of rank " + String(self.rank()) + " < " + String(self.size))
        var out = 1
        for c in range(self.size):
            out = checked_mul(out, self.rows[c][c])
        return out


def _positive(v: List[Int]) -> List[Int]:
    var out = v.copy()
    var first = 0
    while first < len(out) and out[first] == 0:
        first += 1
    if first < len(out) and out[first] < 0:
        for i in range(len(out)):
            out[i] = -out[i]
    return out^


def _key(w: List[Int], start: Int, length: Int, size: Int) -> Int:
    var k = 0
    for i in range(start, start + length):
        k = k * size + w[i]
    return k


def _window(w: List[Int], start: Int, length: Int) -> List[Int]:
    var out = List[Int]()
    for i in range(start, start + length):
        out.append(w[i])
    return out^


def _letters_of_images(sigma: Substitution, letters: List[Bool]) -> List[Bool]:
    """The letters of `sigma(w)`, from the letters of `w`."""
    var out = List[Bool](length=sigma.size, fill=False)
    for a in range(sigma.size):
        if letters[a]:
            ref image = sigma.images[a]
            for i in range(len(image)):
                out[image[i]] = True
    return out^


def _letters_key(letters: List[Bool]) -> String:
    var key = String("")
    for a in range(len(letters)):
        key += "1" if letters[a] else "0"
    return key


def _require_seed(sigma: Substitution, min_length: Int) raises:
    """Refuse when no `sigma^k(0)` is both `min_length` long and carries every
    letter, so `_seed_word` never loops.

    The letter sets of `sigma^k(0)` follow a map on subsets of the alphabet, so
    they enter a cycle. A seed exists exactly when the full alphabet lies on
    that cycle and, unless one letter suffices, some image is longer than one
    letter: a word carrying every letter then grows at its next application,
    and the full alphabet recurs."""
    var letters = List[Bool](length=sigma.size, fill=False)
    letters[0] = True
    var at = Dict[String, Int]()
    var path = List[List[Bool]]()
    while _letters_key(letters) not in at:
        at[_letters_key(letters)] = len(path)
        path.append(letters.copy())
        letters = _letters_of_images(sigma, letters)
    var covers = False
    for k in range(at[_letters_key(letters)], len(path)):
        var full = True
        for a in range(sigma.size):
            full = full and path[k][a]
        covers = covers or full
    if not covers:
        raise Error("no power of the substitution at 0 carries every letter: no seed word")
    var grows = False
    for a in range(sigma.size):
        grows = grows or len(sigma.images[a]) > 1
    if not grows and min_length > 1:
        raise Error("every image is one letter: the language has no factor of length " + String(min_length))


def _seed_word(sigma: Substitution, min_length: Int) raises -> List[Int]:
    """`sigma^k(0)` for the least `k` at which it is at least `min_length` long
    and carries every letter; refused where no such `k` exists."""
    _require_seed(sigma, min_length)
    var w: List[Int] = [0]
    while True:
        var seen = List[Bool](length=sigma.size, fill=False)
        for i in range(len(w)):
            seen[w[i]] = True
        var all_letters = True
        for a in range(sigma.size):
            if not seen[a]:
                all_letters = False
        if all_letters and len(w) >= min_length:
            return w^
        w = sigma.apply(w)


def factor_set(sigma: Substitution, m: Int) raises -> List[List[Int]]:
    """Every length-`m` factor of the language of the primitive `sigma`.

    A length-`m` factor of `sigma(x)` lies inside `sigma(u)` for a length-`m`
    factor `u` of `x` (images are non-empty), so the set is the closure of the
    windows of a seed word under `u -> windows of sigma(u)`; the seed carries
    every letter, so the closure reaches every factor."""
    var cap = max_factor_length(sigma.size)
    if m < 1 or m > cap:
        raise Error("factor length " + String(m) + " outside 1.." + String(cap))
    var index = Dict[Int, Int]()
    var out = List[List[Int]]()
    var seed = _seed_word(sigma, m)
    for s in range(len(seed) - m + 1):
        var k = _key(seed, s, m, sigma.size)
        if k not in index:
            index[k] = len(out)
            out.append(_window(seed, s, m))
    var done = 0
    while done < len(out):
        var image = sigma.apply(out[done])
        done += 1
        for s in range(len(image) - m + 1):
            var k = _key(image, s, m, sigma.size)
            if k not in index:
                index[k] = len(out)
                out.append(_window(image, s, m))
    return out^


def _lattice_from_rauzy(
    vertices: List[List[Int]], edges: List[List[Int]], size: Int
) raises -> TriangularLattice:
    """The image of `H_1` of the Rauzy graph under `w -> e_{w[0]}`."""
    var n = len(vertices[0])
    var index = Dict[Int, Int]()
    for v in range(len(vertices)):
        index[_key(vertices[v], 0, n, size)] = v
    var tails = List[Int]()
    var heads = List[Int]()
    var adjacent = List[List[Int]](length=len(vertices), fill=List[Int]())
    for e in range(len(edges)):
        var t = _key(edges[e], 0, n, size)
        var h = _key(edges[e], 1, n, size)
        if t not in index or h not in index:
            raise Error("a length-" + String(n + 1) + " factor has an end that is not a factor")
        tails.append(index[t])
        heads.append(index[h])
        adjacent[index[t]].append(e)
        adjacent[index[h]].append(e)

    # Potentials along an undirected spanning tree, rooted at vertex 0.
    var potential = List[List[Int]](length=len(vertices), fill=List[Int]())
    var tree_edge = List[Bool](length=len(edges), fill=False)
    potential[0] = List[Int](length=size, fill=0)
    var queue: List[Int] = [0]
    var head = 0
    while head < len(queue):
        var v = queue[head]
        head += 1
        for i in range(len(adjacent[v])):
            var e = adjacent[v][i]
            var forward = tails[e] == v
            var other = heads[e] if forward else tails[e]
            if len(potential[other]) > 0:
                continue
            var step = potential[v].copy()
            var letter = edges[e][0]
            step[letter] = checked_add(step[letter], 1) if forward else checked_sub(step[letter], 1)
            potential[other] = step^
            tree_edge[e] = True
            queue.append(other)
    if len(queue) != len(vertices):
        raise Error("the Rauzy graph of order " + String(n) + " is disconnected")

    var lattice = TriangularLattice(size)
    for e in range(len(edges)):
        if tree_edge[e]:
            continue
        var cycle = List[Int]()
        for a in range(size):
            var through = potential[tails[e]][a] + (1 if edges[e][0] == a else 0)
            cycle.append(checked_sub(through, potential[heads[e]][a]))
        lattice.insert(cycle)
    return lattice^


def return_lattice(sigma: Substitution, n: Int) raises -> TriangularLattice:
    """`Lambda_n`, exactly, in Hermite normal form."""
    return _lattice_from_rauzy(factor_set(sigma, n), factor_set(sigma, n + 1), sigma.size)


def return_index_profile(sigma: Substitution, max_n: Int) raises -> List[Int]:
    """`[Z^d : Lambda_n]` for `n = 1..max_n`, at index `n - 1`; each factor set
    is built once and serves as edges of one order and vertices of the next."""
    var out = List[Int]()
    var vertices = factor_set(sigma, 1)
    for n in range(1, max_n + 1):
        var edges = factor_set(sigma, n + 1)
        out.append(_lattice_from_rauzy(vertices, edges, sigma.size).index())
        vertices = edges^
    return out^


def sampled_return_index(sigma: Substitution, n: Int, min_length: Int) raises -> Int:
    """The index of the lattice spanned by the returns seen in a prefix of
    `sigma^k(0)` of length at least `min_length`: a multiple of the exact
    `[Z^d : Lambda_n]`, and an independent route to it."""
    var cap = max_factor_length(sigma.size)
    if n < 1 or n > cap:
        raise Error("factor length " + String(n) + " outside 1.." + String(cap))
    var w = _seed_word(sigma, min_length)
    var prefix = List[List[Int]]()
    prefix.append(List[Int](length=sigma.size, fill=0))
    for i in range(len(w)):
        var p = prefix[i].copy()
        p[w[i]] += 1
        prefix.append(p^)
    var last = Dict[Int, Int]()
    var lattice = TriangularLattice(sigma.size)
    for i in range(len(w) - n + 1):
        var k = _key(w, i, n, sigma.size)
        if k in last:
            var j = last[k]
            var d = List[Int]()
            for a in range(sigma.size):
                d.append(prefix[i][a] - prefix[j][a])
            lattice.insert(d)
        last[k] = i
    return lattice.index()


def verify_index_profile(sigma: Substitution, det: Int, profile: List[Int]) raises:
    """Refuse an index profile that breaks either structural invariant.

    `profile[n - 1] = [Z^d : Lambda_n]`. A return of a length-`n+1` factor
    returns its prefix, so each index divides the next; and the index at
    order `n` divides `|det M|^K [Z^d : Lambda_1]` for the covering level `K`
    of `n`. Either failure is a defect in the construction, never a result."""
    for n in range(1, len(profile) + 1):
        var index = profile[n - 1]
        if n > 1 and index % profile[n - 2] != 0:
            raise Error(
                "return-lattice chain broken at order " + String(n) + ": "
                + String(profile[n - 2]) + " does not divide " + String(index)
            )
        var level = covering_level(sigma, n)
        if level < 0:
            raise Error("no power of the substitution covers order " + String(n) + ": some image stops growing")
        var bound = profile[0]
        for _ in range(level):
            bound = checked_mul(bound, det)
        if bound % index != 0:
            raise Error(
                "covering bound broken at order " + String(n) + ": "
                + String(index) + " does not divide " + String(bound)
            )


def covering_level(sigma: Substitution, n: Int) -> Int:
    """The least `K` with `|sigma^K(a)| >= n` for every letter `a`, or `-1`
    when some letter's image stops short of `n` for ever.

    Returns of a length-`n` factor contain `M^K` times every return of a
    letter, so `M^K Lambda_1 <= Lambda_n` and `[Z^d : Lambda_n]` divides
    `|det M|^K [Z^d : Lambda_1]`. Lengths are counted saturated at `n`: they
    never decrease, so the saturated vector stops changing after finitely many
    steps, and a step that leaves it unchanged leaves it unchanged for ever --
    no loop and no overflow."""
    var lengths = List[Int](length=sigma.size, fill=1)
    var level = 0
    while True:
        var shortest = lengths[0]
        for a in range(sigma.size):
            if lengths[a] < shortest:
                shortest = lengths[a]
        if shortest >= n:
            return level
        var longer = List[Int]()
        var changed = False
        for a in range(sigma.size):
            var s = 0
            ref image = sigma.images[a]
            for i in range(len(image)):
                if lengths[image[i]] >= n - s:
                    s = n
                    break
                s += lengths[image[i]]
            changed = changed or s != lengths[a]
            longer.append(s)
        if not changed:
            return -1
        lengths = longer^
        level += 1
