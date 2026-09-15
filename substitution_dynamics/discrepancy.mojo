"""Exact swap-walk discrepancy kernels.

For a seed `(ab, ba)` and a level `n` the *swap walk* is the prefix-difference
walk of the inflated pair `(sigma^n(ab), sigma^n(ba))`:

    Delta_n(j) = parikh(sigma^n(ab)[:j]) - parikh(sigma^n(ba)[:j]).

Every zero-return block of a swap pair inherits `max_j ||Delta_n(j)||_inf`
as a bound on its own discrepancy. This module only evaluates these
quantities exactly; whether they are bounded in `n` is the consumer's
theorem, not the kernel's.
"""

from substitution_dynamics.automaton import Automaton
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.words import Pair


def discrepancy(p: Pair, size: Int) -> Int:
    """`max_k ||parikh(u[:k]) - parikh(v[:k])||_inf` over the prefixes of `p`."""
    var diff = List[Int]()
    for _ in range(size):
        diff.append(0)
    var best = 0
    for i in range(len(p.u)):
        var x = p.u[i]
        var y = p.v[i]
        diff[x] = diff[x] + 1
        diff[y] = diff[y] - 1
        for j in range(size):
            var a = diff[j] if diff[j] >= 0 else -diff[j]
            if a > best:
                best = a
    return best


def swap_walk_sup(sigma: Substitution, a: Int, b: Int, level: Int) -> Int:
    """`max_j ||Delta_level(j)||_inf` for the seed `(ab, ba)`."""
    var ab: List[Int] = [a, b]
    var ba: List[Int] = [b, a]
    return discrepancy(Pair(sigma.apply_n(ab, level), sigma.apply_n(ba, level)), sigma.size)


def swap_walk_profile(sigma: Substitution, max_level: Int) -> List[Int]:
    """Entry `n` is the maximum over all seeds of the level-`n` swap-walk supremum."""
    var out = List[Int]()
    for n in range(max_level + 1):
        var best = 0
        for a in range(sigma.size):
            for b in range(a + 1, sigma.size):
                var s = swap_walk_sup(sigma, a, b, n)
                if s > best:
                    best = s
        out.append(best)
    return out^


def max_reachable_discrepancy(a: Automaton) -> Int:
    """Largest discrepancy over the vertices of a reachable balanced-pair graph."""
    var best = 0
    for i in range(a.size()):
        var d = discrepancy(a.states[i], a.alphabet)
        if d > best:
            best = d
    return best


def max_state_length(a: Automaton) -> Int:
    var best = 0
    for i in range(a.size()):
        var n = a.states[i].length()
        if n > best:
            best = n
    return best


def common_tile_count(sigma: Substitution, a: Int, b: Int, level: Int) -> List[Int]:
    """[common tiles, all tiles] of the level-`level` swap pair `(ab, ba)`.

    A common tile is a position with equal letters on both sides and a zero
    prefix difference before it (a coincidence block of the reduction)."""
    var ab: List[Int] = [a, b]
    var ba: List[Int] = [b, a]
    var u = sigma.apply_n(ab, level)
    var v = sigma.apply_n(ba, level)
    var diff = List[Int]()
    for _ in range(sigma.size):
        diff.append(0)
    var common = 0
    for i in range(len(u)):
        var zero = True
        for j in range(sigma.size):
            if diff[j] != 0:
                zero = False
        if u[i] == v[i] and zero:
            common += 1
        diff[u[i]] = diff[u[i]] + 1
        diff[v[i]] = diff[v[i]] - 1
    var out: List[Int] = [common, len(u)]
    return out^
