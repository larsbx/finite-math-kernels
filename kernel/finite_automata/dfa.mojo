"""Deterministic finite automata over an integer alphabet.

The operations a decision procedure needs, and no more: intersection, union,
complement, the subset construction that discharges an existential quantifier
over one track, the widening and cylinder that put a single-track condition
into a product in the first place, emptiness with a witness word, and Moore
minimisation.

Every automaton here is *total*: `delta` has one entry per (state, letter), so
complement is exactly a flip of the accepting set and no operation has to
special-case a missing transition. A partial transition table is made total by
`with_sink` before anything else touches it.

This module states no theorem about substitutions. It is the engine under
the Dumont-Thomas numeration of `larsbx/pisot-substitution-conjecture-research`, where the letters of a fixed point become the outputs of a
run, and it is the engine a first-order decision procedure over a numeration
system would need. What that procedure additionally requires -- recognisability
of addition in the numeration -- is an imported theorem, gated in that
repository's automatic-sequence literature gate, and nothing here
supplies it.

The two named constructions live in modules named after them, which cite
them, and are re-exported here unchanged: `subset_construction.mojo`
(`project`, Rabin-Scott) and `moore_minimisation.mojo` (`minimised`, Moore).
"""

from finite_exact.bigint_z import BigZ, bigz_add, bigz_from_i64, bigz_zero
from finite_automata.moore_minimisation import minimised
from finite_automata.subset_construction import project



struct Dfa(Copyable, Movable):
    """States `0 .. n-1`, start state `0`, total transition table row major."""

    var letters: Int
    var delta: List[Int]
    var accepting: List[Bool]

    def __init__(out self, letters: Int, delta: List[Int], accepting: List[Bool]) raises:
        if letters < 1:
            raise Error("an automaton needs at least one letter")
        if len(accepting) < 1 or len(delta) != letters * len(accepting):
            raise Error("transition table does not match the state count")
        for i in range(len(delta)):
            if delta[i] < 0 or delta[i] >= len(accepting):
                raise Error("transition leaves the state set")
        self.letters = letters
        self.delta = delta.copy()
        self.accepting = accepting.copy()

    def states(self) -> Int:
        return len(self.accepting)

    def step(self, state: Int, letter: Int) raises -> Int:
        if state < 0 or state >= self.states() or letter < 0 or letter >= self.letters:
            raise Error("step outside the automaton")
        return self.delta[state * self.letters + letter]

    def run(self, word: List[Int]) raises -> Int:
        var state = 0
        for i in range(len(word)):
            state = self.step(state, word[i])
        return state

    def accepts(self, word: List[Int]) raises -> Bool:
        return self.accepting[self.run(word)]


def with_sink(letters: Int, partial: List[Int], accepting: List[Bool]) raises -> Dfa:
    """Complete a partial table by routing every `-1` to a new rejecting sink."""
    var states = len(accepting)
    var delta = List[Int]()
    for i in range(len(partial)):
        delta.append(states if partial[i] < 0 else partial[i])
    var out = accepting.copy()
    out.append(False)
    for _ in range(letters):
        delta.append(states)
    return Dfa(letters, delta, out)


def _product(a: Dfa, b: Dfa, conjunction: Bool) raises -> Dfa:
    """The synchronous product, accepting where both (or either) accept."""
    if a.letters != b.letters:
        raise Error("product needs one alphabet")
    var n = b.states()
    var delta = List[Int]()
    var accepting = List[Bool]()
    for p in range(a.states()):
        for q in range(n):
            var left = a.accepting[p]
            var right = b.accepting[q]
            accepting.append(left and right if conjunction else left or right)
            for c in range(a.letters):
                delta.append(a.step(p, c) * n + b.step(q, c))
    return Dfa(a.letters, delta, accepting)


def intersection(a: Dfa, b: Dfa) raises -> Dfa:
    return _product(a, b, True)


def union(a: Dfa, b: Dfa) raises -> Dfa:
    return _product(a, b, False)


def complement(a: Dfa) raises -> Dfa:
    """Total transitions are what make this a flip and nothing more."""
    var accepting = List[Bool]()
    for i in range(a.states()):
        accepting.append(not a.accepting[i])
    return Dfa(a.letters, a.delta, accepting)


struct Witness(Copyable, Movable):
    """A word the automaton accepts, or the fact that there is none."""

    var word: List[Int]
    var empty: Bool

    def __init__(out self, word: List[Int], empty: Bool):
        self.word = word.copy()
        self.empty = empty


def witness(a: Dfa) raises -> Witness:
    """Breadth-first, so the word returned is a shortest accepted one.

    A decision procedure reports the instance, not just the verdict: an empty
    language is the answer `no`, and a non-empty one should hand back the
    counterexample that makes it `yes`."""
    var seen = List[Bool](length=a.states(), fill=False)
    var parent = List[Int](length=a.states(), fill=-1)
    var arrival = List[Int](length=a.states(), fill=-1)
    var queue: List[Int] = [0]
    seen[0] = True
    var head = 0
    while head < len(queue):
        var state = queue[head]
        head += 1
        if a.accepting[state]:
            var reversed = List[Int]()
            var walk = state
            while parent[walk] >= 0:
                reversed.append(arrival[walk])
                walk = parent[walk]
            var word = List[Int]()
            for i in range(len(reversed)):
                word.append(reversed[len(reversed) - 1 - i])
            return Witness(word, False)
        for c in range(a.letters):
            var next = a.step(state, c)
            if not seen[next]:
                seen[next] = True
                parent[next] = state
                arrival[next] = c
                queue.append(next)
    return Witness(List[Int](), True)


def is_empty(a: Dfa) raises -> Bool:
    return witness(a).empty


def same_language(a: Dfa, b: Dfa) raises -> Bool:
    """Symmetric difference empty. Cheaper than comparing minimal automata up
    to isomorphism, and it is the question actually being asked."""
    if a.letters != b.letters:
        raise Error("comparison needs one alphabet")
    var left = intersection(a, complement(b))
    var right = intersection(complement(a), b)
    return is_empty(left) and is_empty(right)


def widened(a: Dfa, letters: Int) raises -> Dfa:
    """The same language over a larger alphabet.

    A letter the original did not have cannot begin an accepted word, so it
    falls into a rejecting sink. This is what lets two automata built over
    different digit ranges -- a path alphabet and a greedy one -- be combined
    over the common alphabet the product needs."""
    if letters < a.letters:
        raise Error("an alphabet is not widened by shrinking it")
    var sink = a.states()
    var delta = List[Int]()
    for state in range(a.states()):
        for c in range(letters):
            delta.append(a.step(state, c) if c < a.letters else sink)
    for _ in range(letters):
        delta.append(sink)
    var accepting = a.accepting.copy()
    accepting.append(False)
    return Dfa(letters, delta, accepting)


def cylinder(a: Dfa, tracks: Int, track: Int, radix: Int) raises -> Dfa:
    """An automaton on one track, read as an automaton on the product alphabet.

    The inverse of `project` in the sense that matters: `project` discharges an
    existential over a track, and this is how a condition on a single track
    enters a product in the first place. The packing is the one `project`
    undoes -- digit `t` of a letter sits at position `t` in base `radix`."""
    if tracks < 1 or track < 0 or track >= tracks:
        raise Error("track outside the product alphabet")
    if a.letters != radix:
        raise Error("the automaton's alphabet is not this track's radix")
    var letters = radix ** tracks
    var place = radix ** track
    var delta = List[Int]()
    for state in range(a.states()):
        for packed in range(letters):
            delta.append(a.step(state, (packed // place) % radix))
    return Dfa(letters, delta, a.accepting)


struct BoundedAutomaton(Copyable, Movable):
    """An automaton a bounded exploration found, or the refusal that it did not.

    `refused` is the state cap being exceeded and nothing else: a search that
    ran out of budget, which is inconclusive about the input rather than
    negative about it. A refused result carries no automaton worth reading, and
    `accepted` is how a caller asks before reading one.

    Malformed input is deliberately not this. That raises, because it is an
    impossible state and not an exhausted budget, and a caller free to catch
    both through one channel would be free to report a defect as inconclusive
    evidence."""

    var automaton: Dfa
    var explored: Int
    var refused: Bool

    def __init__(out self, automaton: Dfa, explored: Int, refused: Bool):
        self.automaton = automaton.copy()
        self.explored = explored
        self.refused = refused

    def accepted(self) -> Bool:
        return not self.refused


def refusal(letters: Int) raises -> BoundedAutomaton:
    """A refusal carries a rejecting one-state automaton, never a truncated
    exploration that a caller could mistake for the real one."""
    var delta = List[Int](length=letters, fill=0)
    var accepting: List[Bool] = [False]
    return BoundedAutomaton(Dfa(letters, delta, accepting), 0, True)


def accepted_count(a: Dfa, length: Int) raises -> BigZ:
    """How many words of exactly `length` letters the automaton accepts.

    Counting by dynamic programming over states rather than by enumeration:
    the count is exponential in the length and the vector of per-state counts
    is not.

    The count is exact and unbounded, over the vendored `BigZ`. A machine
    integer would be the wrong type here rather than merely a tight one: an
    automaton accepting every word over two letters has `2^length` of them, so
    `length = 63` already leaves the range, and a wrapped count is a wrong
    number presented as a mathematical fact.

    A negative length is refused. `range` would perform no iterations and hand
    back the empty-word count, which would make an impossible query look like a
    level-zero answer."""
    if length < 0:
        raise Error("a word length is not negative")
    var counts = List[BigZ]()
    for state in range(a.states()):
        counts.append(bigz_from_i64(Int64(1)) if state == 0 else bigz_zero())
    for _ in range(length):
        var next = List[BigZ]()
        for _ in range(a.states()):
            next.append(bigz_zero())
        for state in range(a.states()):
            if counts[state].is_zero():
                continue
            for c in range(a.letters):
                var to = a.step(state, c)
                next[to] = bigz_add(next[to], counts[state])
        counts = next^
    var total = bigz_zero()
    for state in range(a.states()):
        if a.accepting[state]:
            total = bigz_add(total, counts[state])
    return total^
