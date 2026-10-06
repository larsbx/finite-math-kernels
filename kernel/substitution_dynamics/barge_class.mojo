"""Conjugates of powers of a substitution in Barge's class, decided exactly.

M. Barge, "Pure discrete spectrum for a class of one-dimensional substitution
tiling systems", Discrete Contin. Dyn. Syst. 36 (2016) 1159-1173; the
geometric setting is M. Barge and J. Kwapisz, "Geometric theory of unimodular
Pisot substitutions", Amer. J. Math. 128 (2006) 1219-1282.

Barge (2016) proves pure discrete spectrum for a primitive, non-periodic
substitution with Pisot inflation that is *injective on initial letters and
constant on final letters*. Reversing every image preserves the spectrum, so
the *mirror* class (constant on initial letters, injective on final letters)
is covered too. Powers `sigma^n` and conjugates `tau(a) = u^{-1} sigma^n(a) u`
(all images of `sigma^n` beginning with `u`), or `tau(a) = v sigma^n(a) v^{-1}`
(all ending with `v`), have the same tiling space up to translation, hence the
same spectrum, and the same incidence matrix up to the power.

For a left rotation every image of `tau` ends with `u`, so `tau` is constant
on final letters; it is injective on initial letters exactly when the letters
following the common prefix are pairwise distinct, which needs the *maximal*
common prefix (a shorter one leaves them all equal). Symmetrically for right
rotations. So, per power, three candidates decide membership: `sigma^n`, its
maximal left rotation and its maximal right rotation.

This module decides the combinatorial membership only, on any alphabet. The
spectral conclusion is Barge's theorem under its hypotheses (primitivity,
non-periodicity, Pisot inflation), which the caller must establish; nothing
here checks them, and a missing witness proves nothing.
"""

from substitution_dynamics.substitution import Substitution


comptime KIND_NONE = 0
comptime KIND_DIRECT = 1
comptime KIND_LEFT_ROTATION = 2
comptime KIND_RIGHT_ROTATION = 3


def _first(t: Substitution, a: Int) -> Int:
    return t.images[a][0]


def _last(t: Substitution, a: Int) -> Int:
    return t.images[a][len(t.images[a]) - 1]


def injective_on_initial(t: Substitution) -> Bool:
    for a in range(t.size):
        for b in range(a + 1, t.size):
            if _first(t, a) == _first(t, b):
                return False
    return True


def injective_on_final(t: Substitution) -> Bool:
    for a in range(t.size):
        for b in range(a + 1, t.size):
            if _last(t, a) == _last(t, b):
                return False
    return True


def constant_on_initial(t: Substitution) -> Bool:
    for a in range(1, t.size):
        if _first(t, a) != _first(t, 0):
            return False
    return True


def constant_on_final(t: Substitution) -> Bool:
    for a in range(1, t.size):
        if _last(t, a) != _last(t, 0):
            return False
    return True


def in_barge_class(t: Substitution) -> Bool:
    """Injective on initial letters and constant on final letters."""
    return injective_on_initial(t) and constant_on_final(t)


def in_mirror_class(t: Substitution) -> Bool:
    """Constant on initial letters and injective on final letters."""
    return constant_on_initial(t) and injective_on_final(t)


def _shortest_image(t: Substitution) -> Int:
    var n = len(t.images[0])
    for a in range(1, t.size):
        if len(t.images[a]) < n:
            n = len(t.images[a])
    return n


def common_prefix_length(t: Substitution) -> Int:
    var shortest = _shortest_image(t)
    var k = 0
    while k < shortest:
        for a in range(1, t.size):
            if t.images[a][k] != t.images[0][k]:
                return k
        k += 1
    return k


def common_suffix_length(t: Substitution) -> Int:
    var shortest = _shortest_image(t)
    var k = 0
    while k < shortest:
        var x = t.images[0][len(t.images[0]) - 1 - k]
        for a in range(1, t.size):
            if t.images[a][len(t.images[a]) - 1 - k] != x:
                return k
        k += 1
    return k


def rotate_left(t: Substitution, k: Int) -> Substitution:
    """`tau(a) = u^{-1} t(a) u` for the common prefix `u` of length `k`."""
    var out = List[List[Int]]()
    for a in range(t.size):
        var w = List[Int]()
        for i in range(k, len(t.images[a])):
            w.append(t.images[a][i])
        for i in range(k):
            w.append(t.images[0][i])
        out.append(w^)
    return Substitution(out^, t.size)


def rotate_right(t: Substitution, k: Int) -> Substitution:
    """`tau(a) = v t(a) v^{-1}` for the common suffix `v` of length `k`."""
    var out = List[List[Int]]()
    ref head = t.images[0]
    for a in range(t.size):
        var w = List[Int]()
        for i in range(len(head) - k, len(head)):
            w.append(head[i])
        for i in range(len(t.images[a]) - k):
            w.append(t.images[a][i])
        out.append(w^)
    return Substitution(out^, t.size)


struct BargeWitness(Copyable, Movable, Writable):
    var power: Int  # 0 when none was found
    var kind: Int
    var mirror: Bool

    def __init__(out self, power: Int, kind: Int, mirror: Bool):
        self.power = power
        self.kind = kind
        self.mirror = mirror

    def found(self) -> Bool:
        return self.kind != KIND_NONE

    def write_to[W: Writer](self, mut w: W):
        w.write("power=", self.power, " kind=", self.kind, " mirror=", self.mirror)


def _classify(t: Substitution, power: Int, kind: Int) -> BargeWitness:
    if in_barge_class(t):
        return BargeWitness(power, kind, False)
    if in_mirror_class(t):
        return BargeWitness(power, kind, True)
    return BargeWitness(0, KIND_NONE, False)


def barge_witness(sigma: Substitution, max_power: Int) raises -> BargeWitness:
    """The least power `n <= max_power` at which `sigma^n` or its maximal left
    or right rotation lies in Barge's class or its mirror."""
    for n in range(1, max_power + 1):
        var t = sigma.power(n)
        var w = _classify(t, n, KIND_DIRECT)
        if w.found():
            return w^
        var p = common_prefix_length(t)
        if p > 0:
            w = _classify(rotate_left(t, p), n, KIND_LEFT_ROTATION)
            if w.found():
                return w^
        var s = common_suffix_length(t)
        if s > 0:
            w = _classify(rotate_right(t, s), n, KIND_RIGHT_ROTATION)
            if w.found():
                return w^
    return BargeWitness(0, KIND_NONE, False)
