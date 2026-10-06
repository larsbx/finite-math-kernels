"""Finite self-maps of an alphabet, classified up to relabelling.

The endpoint maps of a substitution -- `sigma_+(a)`, the first letter of
`sigma(a)`, and `sigma_-(a)`, the last (`Substitution.prefix_endpoint_map`,
`suffix_endpoint_map`) -- are self-maps of its alphabet, and boundary
synchronization of balanced pairs depends on them alone. This module
classifies self-maps of any finite alphabet up to relabelling, computing both
the synchronization quotient and the recurrent off-diagonal core of the
product map `h x h`.

The central quotient is defined by `a ~ b` iff the forward orbits of `a` and
`b` eventually coalesce *at the same iterate*. This is an equivalence relation
and `h` induces a permutation on its classes, so a nonsynchronizing pair is
simply a pair in two distinct classes.

The alphabet is `len(h)`; `classify_maps(size)` enumerates all `size^size`
maps, so it is meant for small alphabets. No floating point, no substitution-
specific assumption, and no names for particular classes: a consumer that
names the classes of one alphabet does so in its own vocabulary.
"""

from std.collections import Set

from substitution_dynamics.balanced_pairs import sync_after
from substitution_dynamics.symmetry import inverse_permutation, permutations, sort_words, word_key


def fixed_points(h: List[Int]) -> Int:
    var n = 0
    for a in range(len(h)):
        if h[a] == a:
            n += 1
    return n


def has_two_cycle(h: List[Int]) -> Bool:
    for a in range(len(h)):
        for b in range(a + 1, len(h)):
            if h[a] == b and h[b] == a:
                return True
    return False


def image_size(h: List[Int]) -> Int:
    var seen = Set[Int]()
    for a in range(len(h)):
        seen.add(h[a])
    return len(seen)


struct LetterPair(Copyable, Movable, Equatable, Writable):
    """An ordered pair of letters, the state space of the product map `h x h`."""

    var a: Int
    var b: Int

    def __init__(out self, a: Int, b: Int):
        self.a = a
        self.b = b

    def __eq__(self, other: LetterPair) -> Bool:
        return self.a == other.a and self.b == other.b

    def __ne__(self, other: LetterPair) -> Bool:
        return not (self == other)

    def is_diagonal(self) -> Bool:
        return self.a == self.b

    def step(self, h: List[Int]) -> LetterPair:
        return LetterPair(h[self.a], h[self.b])

    def write_to[W: Writer](self, mut w: W):
        w.write("(", self.a, ",", self.b, ")")


def validate_map(h: List[Int]) raises:
    """Reject anything that is not a self-map of `0 .. len(h)-1`."""
    if len(h) == 0:
        raise Error("finite map must have a nonempty domain")
    for a in range(len(h)):
        if h[a] < 0 or h[a] >= len(h):
            raise Error("map value lies outside 0.." + String(len(h) - 1))


def all_maps(size: Int) -> List[List[Int]]:
    """Every self-map of `size` letters, lexicographically (`size^size` of them)."""
    var out: List[List[Int]] = [List[Int]()]
    for _ in range(size):
        var grown = List[List[Int]]()
        for i in range(len(out)):
            for value in range(size):
                var extended = out[i].copy()
                extended.append(value)
                grown.append(extended^)
        out = grown^
    return out^


def conjugate(h: List[Int], perm: List[Int]) -> List[Int]:
    """`p o h o p^{-1}` for a permutation `p` of the alphabet."""
    var inv = inverse_permutation(perm)
    var out = List[Int](capacity=len(h))
    for x in range(len(h)):
        out.append(perm[h[inv[x]]])
    return out^


def conjugacy_orbit(h: List[Int]) -> List[List[Int]]:
    """Every relabelling of `h`, sorted and deduplicated."""
    var perms = permutations(len(h))
    var out = List[List[Int]]()
    for i in range(len(perms)):
        var image = conjugate(h, perms[i])
        var known = False
        for j in range(len(out)):
            if out[j] == image:
                known = True
        if not known:
            out.append(image^)
    sort_words(out)
    return out^


def canonical_map(h: List[Int]) -> List[Int]:
    """Lexicographically least conjugate of `h`."""
    return conjugacy_orbit(h)[0].copy()


def synchronizes(h: List[Int], a: Int, b: Int) -> Bool:
    """Whether the forward orbits of `a` and `b` ever meet, decided exactly:
    `2n+1` transitions settle two orbits of a map on `n` letters."""
    return sync_after(h, a, b) >= 0


def synchronization_partition(h: List[Int]) -> List[List[Int]]:
    """Partition the letters by eventual same-time coalescence under `h`."""
    var blocks = List[List[Int]]()
    for a in range(len(h)):
        var placed = False
        for i in range(len(blocks)):
            if not placed and synchronizes(h, a, blocks[i][0]):
                blocks[i].append(a)
                placed = True
        if not placed:
            var block: List[Int] = [a]
            blocks.append(block^)
    return blocks^


def synchronization_quotient_permutation(h: List[Int]) raises -> List[Int]:
    """The permutation `h` induces on its synchronization classes.

    If `a ~ b` then `h(a) ~ h(b)`, so the quotient map is well defined;
    conversely `h(a) ~ h(b)` gives `a ~ b` one iterate earlier, so it is
    injective and hence, on a finite quotient, a permutation. A failure of
    either is a contradiction in the exact construction and raises."""
    var partition = synchronization_partition(h)
    var class_of_letter = List[Int](length=len(h), fill=-1)
    for i in range(len(partition)):
        for j in range(len(partition[i])):
            class_of_letter[partition[i][j]] = i

    var quotient = List[Int](capacity=len(partition))
    for i in range(len(partition)):
        var target = class_of_letter[h[partition[i][0]]]
        for j in range(len(partition[i])):
            if class_of_letter[h[partition[i][j]]] != target:
                raise Error("synchronization quotient is not well defined")
        quotient.append(target)

    var hit = List[Bool](length=len(partition), fill=False)
    for i in range(len(quotient)):
        if hit[quotient[i]]:
            raise Error("synchronization quotient is not a permutation")
        hit[quotient[i]] = True
    return quotient^


def nonsynchronizing_pairs(h: List[Int]) -> List[LetterPair]:
    """Every ordered distinct pair whose forward orbits never coalesce."""
    var out = List[LetterPair]()
    for a in range(len(h)):
        for b in range(len(h)):
            if a != b and not synchronizes(h, a, b):
                out.append(LetterPair(a, b))
    return out^


def is_recurrent_pair(h: List[Int], pair: LetterPair) -> Bool:
    """Whether `pair` is periodic under `h x h` and stays off the diagonal."""
    if pair.is_diagonal():
        return False
    var current = pair.step(h)
    for _ in range(2 * len(h) * len(h) + 1):
        if current.is_diagonal():
            return False
        if current == pair:
            return True
        current = current.step(h)
    return False


def recurrent_nonsynchronizing_core(h: List[Int]) -> List[LetterPair]:
    """The periodic off-diagonal points of the product map `h x h`."""
    var out = List[LetterPair]()
    var candidates = nonsynchronizing_pairs(h)
    for i in range(len(candidates)):
        if is_recurrent_pair(h, candidates[i]):
            out.append(candidates[i].copy())
    return out^


def steps_to_recurrent_core(h: List[Int], a: Int, b: Int) raises -> Int:
    """Steps until a nonsynchronizing pair first enters the recurrent core, or
    `-1` when the pair synchronizes. Determinism on a finite state space
    guarantees entry, so failing to arrive raises."""
    if synchronizes(h, a, b):
        return -1
    var core = recurrent_nonsynchronizing_core(h)
    var current = LetterPair(a, b)
    for steps in range(len(h) * len(h) + 1):
        for i in range(len(core)):
            if core[i] == current:
                return steps
        current = current.step(h)
    raise Error("nonsynchronizing orbit never reached the recurrent core")


def functional_cycle_lengths(h: List[Int]) -> List[Int]:
    """Sorted cycle lengths of the functional graph of `h`.

    A readable invariant for reports; it is not the canonical classifier,
    because distinct rooted-tree attachments can share cycle data."""
    var lengths = List[Int]()
    var globally_seen = List[Bool](length=len(h), fill=False)
    for start in range(len(h)):
        if globally_seen[start]:
            continue
        var position = List[Int](length=len(h), fill=-1)
        var path = List[Int]()
        var x = start
        while position[x] < 0 and not globally_seen[x]:
            position[x] = len(path)
            path.append(x)
            x = h[x]
        for i in range(len(path)):
            globally_seen[path[i]] = True
        if position[x] >= 0:
            lengths.append(len(path) - position[x])
    sort(lengths)
    return lengths^


struct EndpointMapClass(Copyable, Movable):
    """One conjugacy class of finite maps under alphabet relabelling."""

    var representative: List[Int]
    var members: List[List[Int]]
    var nonsynchronizing: List[LetterPair]
    var recurrent_core: List[LetterPair]
    var cycle_lengths: List[Int]

    def __init__(out self, var representative: List[Int]):
        self.members = conjugacy_orbit(representative)
        self.nonsynchronizing = nonsynchronizing_pairs(representative)
        self.recurrent_core = recurrent_nonsynchronizing_core(representative)
        self.cycle_lengths = functional_cycle_lengths(representative)
        self.representative = representative^

    def size(self) -> Int:
        return len(self.members)

    def globally_synchronizing(self) -> Bool:
        return len(self.nonsynchronizing) == 0


def classify_maps(size: Int) -> List[EndpointMapClass]:
    """Every self-map of `size` letters, classified up to relabelling, with
    the representatives in lexicographic order."""
    var representatives = Set[String]()
    var canonical = List[List[Int]]()
    var maps = all_maps(size)
    for i in range(len(maps)):
        var rep = canonical_map(maps[i])
        if word_key(rep) not in representatives:
            representatives.add(word_key(rep))
            canonical.append(rep^)
    sort_words(canonical)
    var out = List[EndpointMapClass]()
    for i in range(len(canonical)):
        out.append(EndpointMapClass(canonical[i].copy()))
    return out^


def class_of(h: List[Int]) -> EndpointMapClass:
    """The conjugacy class descriptor containing `h`."""
    return EndpointMapClass(canonical_map(h))


def pairs_key(pairs: List[LetterPair]) -> String:
    """`(a,b) (a,b) ...`, the report rendering of a pair list."""
    var out = String("")
    for i in range(len(pairs)):
        out += ("" if i == 0 else " ") + String(pairs[i])
    return out
