"""Relabelling and reversal symmetries of words, pairs and substitutions.

The symmetric group on `{0, ..., size-1}` acts on a pair of words by
relabelling both sides, and on a substitution by conjugation
`sigma^p(p(a)) = p(sigma(a))`; word reversal is a further involution commuting
with inflation. Catalogue taxonomies quote orbits under these actions, so the
canonical representative is the lexicographically least element of the orbit,
with a pair first normalised so that `(u, v)` and `(v, u)` coincide.
Comparison is exact word lexicographic order (a proper prefix precedes its
extensions).

The alphabet of a pair is explicit (`canonical_pair(p, size)`); a
substitution carries its own, `len(sigma)`. The orbit is enumerated, so the
cost is `size!` -- the right tool for the small alphabets catalogues use.

Keys write letters `0..9` as one digit and a letter `10` or larger as `[n]`,
as `Pair.key` does, so a key is injective on every alphabet and
`parse_substitution_key` inverts `substitution_key` exactly.
"""

from substitution_dynamics.words import Pair, _letter_token


def word_less(a: List[Int], b: List[Int]) -> Bool:
    """Lexicographic order; a proper prefix precedes its extensions."""
    var n = len(a) if len(a) < len(b) else len(b)
    for i in range(n):
        if a[i] != b[i]:
            return a[i] < b[i]
    return len(a) < len(b)


def sort_words(mut words: List[List[Int]]):
    """Sort `words` by `word_less`, stably, by a bottom-up merge sort.

    Local rather than the standard library's comparator `sort`, whose
    signature differs between the Mojo toolchains the consumers pin; every
    caller sorts distinct words, so any correct sort gives the same order."""
    var n = len(words)
    var width = 1
    while width < n:
        var merged = List[List[Int]](capacity=n)
        var lo = 0
        while lo < n:
            var mid = lo + width if lo + width < n else n
            var hi = lo + 2 * width if lo + 2 * width < n else n
            var i = lo
            var j = mid
            while i < mid and j < hi:
                if word_less(words[j], words[i]):
                    merged.append(words[j].copy())
                    j += 1
                else:
                    merged.append(words[i].copy())
                    i += 1
            while i < mid:
                merged.append(words[i].copy())
                i += 1
            while j < hi:
                merged.append(words[j].copy())
                j += 1
            lo = hi
        words = merged^
        width *= 2


def permutations(size: Int) -> List[List[Int]]:
    """The `size!` permutations of `0 .. size-1` as images `[p(0), ...]`,
    in lexicographic order, built by insertion into every position."""
    var out: List[List[Int]] = [List[Int]()]
    for letter in range(size):
        var grown = List[List[Int]]()
        for i in range(len(out)):
            for slot in range(len(out[i]) + 1):
                var extended = List[Int](capacity=len(out[i]) + 1)
                for j in range(slot):
                    extended.append(out[i][j])
                extended.append(letter)
                for j in range(slot, len(out[i])):
                    extended.append(out[i][j])
                grown.append(extended^)
        out = grown^
    sort_words(out)
    return out^


def inverse_permutation(p: List[Int]) -> List[Int]:
    var inv = List[Int](length=len(p), fill=0)
    for old in range(len(p)):
        inv[p[old]] = old
    return inv^


def relabel(w: List[Int], p: List[Int]) -> List[Int]:
    var out = List[Int](capacity=len(w))
    for i in range(len(w)):
        out.append(p[w[i]])
    return out^


def reversed_word(w: List[Int]) -> List[Int]:
    var out = List[Int](capacity=len(w))
    for i in range(len(w) - 1, -1, -1):
        out.append(w[i])
    return out^


def normalised_pair(u: List[Int], v: List[Int]) -> Pair:
    """`(u, v)` with the lexicographically smaller side first."""
    return Pair(v, u) if word_less(v, u) else Pair(u, v)


def pair_less(p: Pair, q: Pair) -> Bool:
    if p.u != q.u:
        return word_less(p.u, q.u)
    return word_less(p.v, q.v)


def relabelled_pair(p: Pair, perm: List[Int]) -> Pair:
    return normalised_pair(relabel(p.u, perm), relabel(p.v, perm))


def reversed_pair(p: Pair) -> Pair:
    return normalised_pair(reversed_word(p.u), reversed_word(p.v))


def canonical_pair(p: Pair, size: Int) -> Pair:
    """Least normalised relabelling of `p` over the alphabet `0 .. size-1`."""
    var perms = permutations(size)
    var best = relabelled_pair(p, perms[0])
    for i in range(1, len(perms)):
        var candidate = relabelled_pair(p, perms[i])
        if pair_less(candidate, best):
            best = candidate^
    return best^


def conjugated_substitution(sigma: List[List[Int]], perm: List[Int]) -> List[List[Int]]:
    """`sigma^perm` with `sigma^perm(perm(a)) = perm(sigma(a))`."""
    var inv = inverse_permutation(perm)
    var out = List[List[Int]]()
    for letter in range(len(perm)):
        out.append(relabel(sigma[inv[letter]], perm))
    return out^


def reversed_substitution(sigma: List[List[Int]]) -> List[List[Int]]:
    var out = List[List[Int]]()
    for a in range(len(sigma)):
        out.append(reversed_word(sigma[a]))
    return out^


def substitution_less(s: List[List[Int]], t: List[List[Int]]) -> Bool:
    for a in range(len(s)):
        if s[a] != t[a]:
            return word_less(s[a], t[a])
    return False


def canonical_substitution(sigma: List[List[Int]]) -> List[List[Int]]:
    """Least conjugate of `sigma` under relabelling of its `len(sigma)` letters."""
    var perms = permutations(len(sigma))
    var best = conjugated_substitution(sigma, perms[0])
    for i in range(1, len(perms)):
        var candidate = conjugated_substitution(sigma, perms[i])
        if substitution_less(candidate, best):
            best = candidate^
    return best^


def word_key(w: List[Int]) -> String:
    var s = String("")
    for i in range(len(w)):
        s += _letter_token(w[i])
    return s


def substitution_key(sigma: List[List[Int]]) -> String:
    """`sigma(0)/sigma(1)/...`, one digit per letter below ten."""
    var s = word_key(sigma[0])
    for a in range(1, len(sigma)):
        s += "/" + word_key(sigma[a])
    return s


def parse_substitution_key(key: String, size: Int) raises -> List[List[Int]]:
    """Inverse of `substitution_key` on the alphabet `0 .. size-1`: exactly
    `size` images, each letter a digit or a bracketed `[n]`, all inside the
    alphabet. Anything else raises."""
    var out = List[List[Int]]()
    for image in key.split("/"):
        var w = List[Int]()
        var bracket = String("")
        var inside = False
        for ch in image.codepoint_slices():
            var c = String(ch)
            if inside:
                if c == "]":
                    w.append(_parse_letter(bracket, size))
                    bracket = String("")
                    inside = False
                else:
                    bracket += c
            elif c == "[":
                inside = True
            else:
                w.append(_parse_letter(c, size))
        if inside:
            raise Error("substitution key has an unclosed letter: " + key)
        out.append(w^)
    if len(out) != size:
        raise Error("substitution key must have exactly " + String(size) + " images: " + key)
    return out^


def _parse_letter(text: String, size: Int) raises -> Int:
    var letter = Int(atol(text))
    if letter < 0 or letter >= size:
        raise Error("substitution letter lies outside 0.." + String(size - 1) + ": " + text)
    return letter
