"""Words over `{0, ..., size-1}`, scattered-subword counts, and word pairs.

The scattered-subword kernels stream over the word once: `N2` and `N3` are
accumulated from prefix letter and pair counters, so the cost is O(n) in the
word length with `size`- and `size^2`-sized inner loops. For `size == 3`
this is exactly the alphabet-3 kernel the PSC certificate uses.

`Pair` carries no alphabet; balance and the horizontal invariants `K1, K2,
K3` are functions of a pair *and* an alphabet size, because their dimension
is `size`, `size^2`, and `size^3`.
"""

from substitution_dynamics.substitution import validate_word
from finite_exact.checked_int import checked_add, checked_mul


def parikh(w: List[Int], size: Int) -> List[Int]:
    """`N_i(w)` for valid letters; every count is at most `len(w) <= Int.MAX`."""
    var out = List[Int]()
    for _ in range(size):
        out.append(0)
    for p in range(len(w)):
        out[w[p]] += 1
    return out^


def n2(w: List[Int], size: Int) raises -> List[Int]:
    """Exact machine counts, or an error if any dimension/intermediate overflows.

    Valid words/alphabet are trusted as before. Refusal is inconclusive.
    """
    var out = List[Int]()
    var slots = checked_mul(size, size)
    for _ in range(slots):
        out.append(0)
    var seen = List[Int]()
    for _ in range(size):
        seen.append(0)
    for p in range(len(w)):
        var j = w[p]
        for i in range(size):
            out[size * i + j] = checked_add(out[size * i + j], seen[i])
        seen[j] = checked_add(seen[j], 1)
    return out^


def idx3(a: Int, b: Int, c: Int, size: Int) -> Int:
    """Lex index of the tensor slot `e_a (x) e_b (x) e_c`."""
    return (size * a + b) * size + c


def n3(w: List[Int], size: Int) raises -> List[Int]:
    """Exact machine counts, or an error if any dimension/intermediate overflows.

    Each triple, prefix pair and prefix letter addition is checked before
    evaluation. No partial vector is returned. This is a bounded Int API,
    not an unbounded integer carrier; even fitting final slots may be refused
    if a prefix pair does not fit. Valid words/alphabet are trusted as before.
    """
    var out = List[Int]()
    var pair_slots = checked_mul(size, size)
    var triple_slots = checked_mul(pair_slots, size)
    for _ in range(triple_slots):
        out.append(0)
    var seen = List[Int]()
    for _ in range(size):
        seen.append(0)
    var pairs = List[Int]()
    for _ in range(pair_slots):
        pairs.append(0)
    for p in range(len(w)):
        var k = w[p]
        for i in range(size):
            for j in range(size):
                var slot = idx3(i, j, k, size)
                out[slot] = checked_add(out[slot], pairs[size * i + j])
        for i in range(size):
            pairs[size * i + k] = checked_add(pairs[size * i + k], seen[i])
        seen[k] = checked_add(seen[k], 1)
    return out^


def diff(u: List[Int], v: List[Int]) -> List[Int]:
    var out = List[Int]()
    for i in range(len(u)):
        out.append(u[i] - v[i])
    return out^


def is_zero(v: List[Int]) -> Bool:
    for i in range(len(v)):
        if v[i] != 0:
            return False
    return True


def _letter_token(a: Int) -> String:
    if a >= 0 and a <= 9:
        return String(a)
    return "[" + String(a) + "]"


struct Pair(Copyable, Movable, Writable, Equatable):
    """A pair of words `(u, v)`; balance is decided relative to an alphabet."""

    var u: List[Int]
    var v: List[Int]

    def __init__(out self, u: List[Int], v: List[Int]):
        self.u = u.copy()
        self.v = v.copy()

    def __eq__(self, o: Pair) -> Bool:
        return self.u == o.u and self.v == o.v

    def __ne__(self, o: Pair) -> Bool:
        return not (self == o)

    def length(self) -> Int:
        return len(self.u)

    def is_coincidence(self) -> Bool:
        return self.u == self.v

    def key(self) -> String:
        """A canonical, injective string key for dictionaries and sets.

        Letters `0..9` are written as one digit each; a letter `10` or larger
        is written as `[n]`, so keys stay unambiguous on every alphabet while
        alphabets of at most ten letters keep the compact digit form.
        """
        var s = String("")
        for i in range(len(self.u)):
            s += _letter_token(self.u[i])
        s += "|"
        for i in range(len(self.v)):
            s += _letter_token(self.v[i])
        return s

    def write_to[W: Writer](self, mut w: W):
        w.write(self.key())


def checked_pair(u: List[Int], v: List[Int], size: Int) raises -> Pair:
    """Boundary constructor: both words over the alphabet and of equal length."""
    validate_word(u, size)
    validate_word(v, size)
    if len(u) != len(v):
        raise Error("pair sides have different lengths")
    return Pair(u, v)


def is_balanced(p: Pair, size: Int) -> Bool:
    """`|u| == |v|` and `Parikh(u) == Parikh(v)`."""
    return len(p.u) == len(p.v) and parikh(p.u, size) == parikh(p.v, size)


def k1(p: Pair, size: Int) -> List[Int]:
    return diff(parikh(p.u, size), parikh(p.v, size))


def k2(p: Pair, size: Int) raises -> List[Int]:
    """Exact difference if both N2 evaluations succeed; propagate refusal.

    Successful coordinates lie in [0, Int.MAX], so their difference fits.
    """
    return diff(n2(p.u, size), n2(p.v, size))


def k3(p: Pair, size: Int) raises -> List[Int]:
    """Exact difference if both N3 evaluations succeed; propagate refusal.

    Refusal is possible even when the mathematical difference would fit.
    Successful coordinates lie in [0, Int.MAX], so their difference fits.
    """
    return diff(n3(p.u, size), n3(p.v, size))

