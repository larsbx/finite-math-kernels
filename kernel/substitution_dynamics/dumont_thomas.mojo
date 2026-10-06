"""The Dumont-Thomas numeration of a fixed point, and prolongable points.

J.-M. Dumont and A. Thomas, "Systemes de numeration et fonctions fractales
relatifs aux substitutions", Theoretical Computer Science 65 (1989) 153-169.

A substitution `tau` prolongable at `c` (`tau(c)` begins with `c`) has a fixed
point `u = tau^inf(c)`, and every position `n < |tau^k(c)|` has exactly one
decomposition along the prefix tree of `tau^k(c)`: read `tau(c) = b_0 b_1 ...`,
find the block `tau^(k-1)(b_j)` that contains `n`, keep `j` as a digit, and
recurse into that block. The digits `d_(k-1) ... d_0` are the Dumont-Thomas
representation of `n`, and the letter reached after the last digit is `u_n`.

Read as an automaton the recursion is small: the states are the letters, the
digit `j` moves from `a` to the `j`-th letter of `tau(a)`, and a digit past the
end of `tau(a)` is inadmissible. So `u` is a letter-valued output of a finite
automaton reading these digits, and the positions carrying a given letter are a
recognisable set.

What this module establishes is finite and checkable: the automaton reproduces
the fixed point letter by letter, admissible digit words of length `k` are in
bijection with positions of `tau^k(c)`, and the words ending at a letter are
counted by the incidence matrix. What it does *not* supply is the step from a
recognisable set to a decision procedure for first-order statements, which
needs recognisability of addition in the numeration; that is an imported
theorem, and nothing here supplies it.

Every substitution has a prolongable power, because the first-letter map of a
finite alphabet has a cycle; `prolongable_form` is that power. The alphabet is
the substitution's, `tau.size`; the automata are those of `finite_automata`,
so this module is vendored together with it and with `finite_exact`.
"""

from finite_exact.bigint_z import BigZ
from finite_automata.dfa import Dfa, accepted_count, with_sink
from substitution_dynamics.substitution import Substitution


struct ProlongablePoint(Copyable, Movable):
    """A power `q` and a letter `c` with `sigma^q(c)` beginning with `c`."""

    var power: Int
    var letter: Int

    def __init__(out self, power: Int, letter: Int):
        self.power = power
        self.letter = letter


def prolongable_points(sigma: Substitution) -> List[ProlongablePoint]:
    """Every `(q, c)` with `q <= |A|` minimal for its cycle of the first-letter
    map, in increasing `q` then `c`: exactly the cycles of `sigma_+`."""
    var first = sigma.prefix_endpoint_map()
    var out = List[ProlongablePoint]()
    var recorded = List[Bool](length=sigma.size, fill=False)
    for q in range(1, sigma.size + 1):
        for c in range(sigma.size):
            if recorded[c]:
                continue  # a multiple of its period, not a first return
            var x = c
            for _ in range(q):
                x = first[x]
            if x == c:
                recorded[c] = True
                out.append(ProlongablePoint(q, c))
    return out^


def prolongable_point(sigma: Substitution) raises -> ProlongablePoint:
    """The least prolongable `(q, c)`; every substitution with a non-erasing
    image has one, because the first-letter map of a finite alphabet has a
    cycle."""
    var points = prolongable_points(sigma)
    if len(points) == 0:
        raise Error("substitution has no prolongable power")
    return points[0].copy()


def prolongable_form(sigma: Substitution) raises -> Substitution:
    """The power of `sigma` that its least prolongable point makes prolongable."""
    return sigma.power(prolongable_point(sigma).power)


def max_image_length(tau: Substitution) -> Int:
    var longest = 0
    for a in range(tau.size):
        if len(tau.images[a]) > longest:
            longest = len(tau.images[a])
    return longest


def _next_lengths(tau: Substitution, lengths: List[Int]) raises -> List[Int]:
    """`|tau^(k+1)(a)|` for each `a`, from `|tau^k(b)|` for each `b`, checked."""
    var next = List[Int](length=tau.size, fill=0)
    for a in range(tau.size):
        ref image = tau.images[a]
        for i in range(len(image)):
            var add = lengths[image[i]]
            if next[a] > Int.MAX - add:
                raise Error("image length exceeds the machine integer range")
            next[a] += add
    return next^


def image_lengths(tau: Substitution, level: Int) raises -> List[Int]:
    """`|tau^level(a)|` for each letter `a`, by repeated substitution counts.

    These stay machine integers because they are positions: a position indexes
    a word a caller can hold. The growth is still exponential, so the
    accumulation is checked and a level past the range raises rather than
    wrapping -- a wrapped length would silently misplace every digit computed
    from it."""
    if level < 0:
        raise Error("a level is not negative")
    var lengths = List[Int](length=tau.size, fill=1)
    for _ in range(level):
        lengths = _next_lengths(tau, lengths)
    return lengths^


def _descendants(tau: Substitution, letter: Int) -> List[Bool]:
    """The letters occurring in some `tau^k(letter)`, `letter` included."""
    var seen = List[Bool](length=tau.size, fill=False)
    seen[letter] = True
    var stack: List[Int] = [letter]
    while len(stack) > 0:
        var a = stack.pop()
        ref image = tau.images[a]
        for i in range(len(image)):
            if not seen[image[i]]:
                seen[image[i]] = True
                stack.append(image[i])
    return seen^


def levels_to_cover(tau: Substitution, letter: Int, position: Int) raises -> Int:
    """The least `k` with `position < |tau^k(letter)|`.

    No level is capped. Images are non-erasing, so every length is
    non-decreasing in `k`, and the lengths over the descendants of `letter`
    evolve on their own: once one step leaves them all unchanged they never
    change again, and a position past `|tau^k(letter)|` then lies past the
    whole fixed point and is refused. Until then their sum grows every step,
    so the search ends -- at the level, at that refusal, or at the checked
    overflow of `image_lengths`."""
    _require_letter(tau, letter)
    if position < 0:
        raise Error("a position is not negative")
    var reach = _descendants(tau, letter)
    var lengths = List[Int](length=tau.size, fill=1)
    var k = 0
    while lengths[letter] <= position:
        var next = _next_lengths(tau, lengths)
        var grew = False
        for a in range(tau.size):
            if reach[a] and next[a] != lengths[a]:
                grew = True
        if not grew:
            raise Error("position lies past the letter's image, which has stopped growing")
        lengths = next^
        k += 1
    return k


def digits(tau: Substitution, letter: Int, position: Int) raises -> List[Int]:
    """The Dumont-Thomas digits of `position`, most significant first.

    The digit at each step is the index of the child block containing what is
    left of the position; the recursion ends with nothing left, at the letter
    that stands there."""
    var level = levels_to_cover(tau, letter, position)
    var table = List[List[Int]]()  # table[k] = |tau^k(a)| for each a
    table.append(List[Int](length=tau.size, fill=1))
    for k in range(1, level):
        table.append(_next_lengths(tau, table[k - 1]))
    var out = List[Int]()
    var current = letter
    var rest = position
    for step in range(level, 0, -1):
        ref lengths = table[step - 1]
        ref image = tau.images[current]
        var index = 0
        while index < len(image):
            var block = lengths[image[index]]
            if rest < block:
                break
            rest -= block
            index += 1
        if index >= len(image):
            raise Error("position escaped its block: the lengths disagree")
        out.append(index)
        current = image[index]
    return out^


def letter_at(tau: Substitution, letter: Int, position: Int) raises -> Int:
    """`u_position` for the fixed point of `tau` at `letter`, by the digits."""
    var path = digits(tau, letter, position)
    var current = letter
    for i in range(len(path)):
        current = tau.images[current][path[i]]
    return current


def letter_of_digits(tau: Substitution, letter: Int, path: List[Int]) raises -> Int:
    """Where an admissible digit word ends, which is the letter it names."""
    var current = letter
    for i in range(len(path)):
        if path[i] < 0 or path[i] >= len(tau.images[current]):
            raise Error("inadmissible digit for this letter")
        current = tau.images[current][path[i]]
    return current


def _transitions(tau: Substitution, radix: Int) -> List[Int]:
    """Row-major `letters x radix` partial table, `-1` past an image's end."""
    var partial = List[Int]()
    for a in range(tau.size):
        ref image = tau.images[a]
        for d in range(radix):
            partial.append(image[d] if d < len(image) else -1)
    return partial^


def numeration_automaton(tau: Substitution, letter: Int) raises -> Dfa:
    """Admissible digit words from `letter`: states are letters, a digit past
    the end of an image is inadmissible and falls into the sink."""
    _require_letter(tau, letter)
    var radix = max_image_length(tau)
    var accepting = List[Bool](length=tau.size, fill=True)
    return _rooted(_transitions(tau, radix), accepting, radix, letter)


def letter_automaton(tau: Substitution, letter: Int, target: Int) raises -> Dfa:
    """Admissible digit words from `letter` that end at `target`: the positions
    of the fixed point carrying that letter, as a recognisable set."""
    _require_letter(tau, letter)
    _require_letter(tau, target)
    var radix = max_image_length(tau)
    var accepting = List[Bool]()
    for a in range(tau.size):
        accepting.append(a == target)
    return _rooted(_transitions(tau, radix), accepting, radix, letter)


def _require_letter(tau: Substitution, letter: Int) raises:
    """A letter outside the alphabet is refused rather than indexed with.

    The automata renumber the state set around the letter they are given, so
    an out-of-range one would reach a bare list index and abort the process
    instead of raising -- a caller assembling a formula out of them would get a
    crash where it should get an error it can report."""
    if letter < 0 or letter >= tau.size:
        raise Error("letter lies outside the substitution's alphabet")


def _rooted(
    partial: List[Int], accepting: List[Bool], radix: Int, letter: Int
) raises -> Dfa:
    """Renumber so `letter` is state 0, which `Dfa` takes as the start, and
    make the table total with a rejecting sink."""
    var states = len(accepting)
    var relabel = List[Int](length=states, fill=0)
    relabel[letter] = 0
    var used = 1
    for a in range(states):
        if a != letter:
            relabel[a] = used
            used += 1
    var table = List[Int](length=states * radix, fill=-1)
    var flags = List[Bool](length=states, fill=False)
    for a in range(states):
        flags[relabel[a]] = accepting[a]
        for d in range(radix):
            var to = partial[a * radix + d]
            table[relabel[a] * radix + d] = -1 if to < 0 else relabel[to]
    return with_sink(radix, table, flags)


def positions_of_length(tau: Substitution, letter: Int, level: Int) raises -> BigZ:
    """`|tau^level(letter)|` counted through the automaton rather than by
    substitution: the two must agree, and that is the content of the
    numeration being a bijection on positions.

    Exact and unbounded, like the count beneath it: image lengths grow like the
    Perron root to the level, so the type has to carry more than a machine
    integer for a level a caller may legitimately ask about."""
    return accepted_count(numeration_automaton(tau, letter), level)


def occurrences_of_length(
    tau: Substitution, letter: Int, target: Int, level: Int
) raises -> BigZ:
    """How many positions of `tau^level(letter)` carry `target`, through the
    automaton. The incidence matrix counts the same thing."""
    return accepted_count(letter_automaton(tau, letter, target), level)
