"""Strong coincidence as an automaton over pairs of Dumont-Thomas paths.

The strong coincidence condition: P. Arnoux and S. Ito, "Pisot substitutions
and Rauzy fractals", Bull. Belg. Math. Soc. Simon Stevin 8 (2001) 181-207
(after F. M. Dekking, "The spectrum of dynamical systems arising from
substitutions of constant length", Z. Wahrsch. Verw. Gebiete 41 (1978)).
The paths are those of `substitution_dynamics.dumont_thomas`.

## The formula

For letters `i, j` of a substitution `sigma`, strong coincidence asks

    SC(i, j)  ==  exists k, exists p :
                      p < |sigma^k(i)|,  p < |sigma^k(j)|,
                      sigma^k(i)[p] = sigma^k(j)[p],
                      l(sigma^k(i)[0..p)) = l(sigma^k(j)[0..p))

with `l` the Parikh (abelianisation) map. The last conjunct is what makes this
the *strong* condition: the two occurrences must be reached after prefixes
carrying the same number of each letter.

## The automaton

Read a Dumont-Thomas path in `sigma^k(i)` and one in `sigma^k(j)` on two
tracks, synchronously, most significant digit first, the digit pair packed as
`p + radix q`. A path digit `d` from letter `a` skips the first `d` child
blocks of `sigma(a)`, so accumulating `x <- M x + s` (with `M[i][j]` the count
of letter `i` in `sigma(j)` and `s` the Parikh vector of what was skipped)
leaves `x` equal to the Parikh vector of the prefix, and the automaton carries
the difference

    delta <- M delta + (s_top - s_bottom),   delta_0 = 0,

alongside the two letters the paths have reached. An inadmissible digit on
either track falls into the rejecting sink, and a word is accepted exactly when
`delta = 0` and the two letters agree. `SC(i, j)` is the language being
non-empty, and a shortest accepted word is the least level at which the pair
coincides.

## What the caller supplies

The difference is an integer vector, and nothing makes the state set finite
in general. What does is a bound on the differences that can still return to
zero, and that bound is not combinatorial: for a Pisot substitution it is the
expanding coordinate measured against the Perron eigenvector, an exact
comparison in the Perron number field. So this module is generic over two
traits the caller implements: `DifferenceStep` (how `delta` advances one level)
and `DifferenceBound` (which differences may still be completed to zero).
`CheckedIncidence` is the plain checked `M x + s` step; the bound is always the
caller's, and with it the claim that the exploration terminates. The state cap
is therefore a guard, not a budget: exceeding it raises.

`parikh_equality_automaton` drops the letter conjunct, leaving the one
recognisable relation the numeration's own signature does not supply;
`coincidence_by_elimination` conjoins it with the admissibility and letter
automata of `substitution_dynamics.dumont_thomas` through the `finite_automata`
Boolean algebra, which is the formula's quantifiers eliminated rather than
wired into one accepting condition. That the two routes give one language is
a regression, not an assumption.

Nothing here claims that any family satisfies strong coincidence; the
condition is decided per substitution, given a sound bound.
"""

from finite_automata.dfa import (
    Dfa,
    Witness,
    cylinder,
    intersection,
    minimised,
    project,
    union,
    widened,
    witness,
)
from finite_exact.checked_int import checked_add, checked_mul
from substitution_dynamics.dumont_thomas import letter_automaton, max_image_length, numeration_automaton
from substitution_dynamics.substitution import Substitution


comptime STATE_CAP = 1 << 20
"""The default guard: a sound bound makes the state set finite, so reaching
this means the bound or the caller is wrong."""

comptime TRACKS = 2
comptime PATH_TRACK = 0
comptime OTHER_TRACK = 1


trait DifferenceStep(Copyable, Deinitable, Movable):
    """One level of the Parikh-difference recursion: `M delta + s`."""

    def advance(self, delta: List[Int], contribution: List[Int]) raises -> List[Int]:
        ...


trait DifferenceBound(DifferenceStep):
    """A step together with the differences that can still return to zero.

    Soundness is the implementer's obligation: `admits` must keep every
    difference from which zero is reachable. Pruning too little adds states,
    which the cap catches; pruning too much drops a real answer, which nothing
    here can catch."""

    def admits(self, delta: List[Int]) raises -> Bool:
        ...


struct CheckedIncidence(DifferenceStep):
    """`M x + s` over the substitution's incidence matrix, in checked machine
    integers: a coordinate that would wrap raises instead."""

    var incidence: List[Int]
    var size: Int

    def __init__(out self, sigma: Substitution):
        self.incidence = sigma.incidence()
        self.size = sigma.size

    def advance(self, delta: List[Int], contribution: List[Int]) raises -> List[Int]:
        if len(delta) != self.size or len(contribution) != self.size:
            raise Error("a difference vector carries one coefficient per letter")
        var out = List[Int](capacity=self.size)
        for row in range(self.size):
            var total = contribution[row]
            for col in range(self.size):
                total = checked_add(total, checked_mul(self.incidence[row * self.size + col], delta[col]))
            out.append(total)
        return out^


def require_letter_pair(sigma: Substitution, top: Int, bottom: Int) raises:
    if top < 0 or top >= sigma.size or bottom < 0 or bottom >= sigma.size:
        raise Error("a coincidence pair is two letters of the substitution")


def _key(top: Int, bottom: Int, delta: List[Int]) -> String:
    var out = String(top) + "," + String(bottom)
    for i in range(len(delta)):
        out += "," + String(delta[i])
    return out


def skipped(sigma: Substitution, letter: Int, digit: Int) raises -> List[Int]:
    """The Parikh vector of the first `digit` letters of `sigma(letter)`."""
    ref image = sigma.images[letter]
    if digit < 0 or digit > len(image):
        raise Error("path digit outside the image")
    var out = List[Int](length=sigma.size, fill=0)
    for r in range(digit):
        out[image[r]] += 1
    return out^


def _is_zero(delta: List[Int]) -> Bool:
    for i in range(len(delta)):
        if delta[i] != 0:
            return False
    return True


struct _Frontier[D: DifferenceBound](Copyable, Movable):
    """Everything a step needs, built once per pair rather than per state."""

    var sigma: Substitution
    var bound: Self.D
    var radix: Int

    def __init__(out self, sigma: Substitution, bound: Self.D):
        self.sigma = sigma.copy()
        self.bound = bound.copy()
        self.radix = max_image_length(sigma)

    def letters(self) -> Int:
        return self.radix * self.radix

    def step(
        self, top: Int, bottom: Int, delta: List[Int], packed: Int
    ) raises -> List[Int]:
        """The successor of a live state, as `(top, bottom, delta)`, or an empty
        list where the transition is inadmissible or can no longer reach zero.

        One place where a transition is decided, so the whole-language build and
        the search that stops at the first witness cannot drift apart."""
        var p = packed % self.radix
        var q = packed // self.radix
        if p >= len(self.sigma.images[top]) or q >= len(self.sigma.images[bottom]):
            return List[Int]()
        var contribution = skipped(self.sigma, top, p)
        var below = skipped(self.sigma, bottom, q)
        for letter in range(self.sigma.size):
            contribution[letter] -= below[letter]
        var next = self.bound.advance(delta, contribution)
        if not self.bound.admits(next):
            return List[Int]()
        var out: List[Int] = [self.sigma.images[top][p], self.sigma.images[bottom][q]]
        for letter in range(self.sigma.size):
            out.append(next[letter])
        return out^


def coincidence_automaton[D: DifferenceBound](
    sigma: Substitution,
    top: Int,
    bottom: Int,
    bound: D,
    cap: Int = STATE_CAP,
    letters_must_agree: Bool = True,
) raises -> Dfa:
    """Pairs of paths of one length reaching one letter after prefixes of one
    Parikh vector, over digit pairs packed as `p + radix q`: the whole
    language. With `letters_must_agree = False` it is the Parikh-equality
    relation alone (`parikh_equality_automaton`).

    `coincidence_witness` answers the emptiness question without building the
    language, and is what a caller that only wants the verdict should use."""
    require_letter_pair(sigma, top, bottom)
    if cap < 2:
        raise Error("a state cap leaves room for the start state and the sink")
    var frontier = _Frontier(sigma, bound)

    # State 0 is the zero difference at the two starting letters; state 1 is the
    # rejecting sink an inadmissible or hopeless transition falls into.
    var zero = List[Int](length=sigma.size, fill=0)
    var keys: List[String] = [_key(top, bottom, zero), String("dead")]
    var index = Dict[String, Int]()
    index[keys[0]] = 0
    var tops: List[Int] = [top, -1]
    var bottoms: List[Int] = [bottom, -1]
    var deltas: List[List[Int]] = [zero.copy(), zero.copy()]
    var dead: List[Bool] = [False, True]
    var delta = List[Int]()
    var letters = frontier.letters()

    var done = 0
    while done < len(keys):
        for packed in range(letters):
            if dead[done]:
                delta.append(1)
                continue
            var next = frontier.step(
                tops[done], bottoms[done], deltas[done], packed
            )
            if len(next) == 0:
                delta.append(1)
                continue
            var reached = List[Int]()
            for i in range(sigma.size):
                reached.append(next[2 + i])
            var key = _key(next[0], next[1], reached)
            var at = index.get(key, -1)
            if at < 0:
                if len(keys) >= cap:
                    raise Error("coincidence state set past the cap: see the finiteness argument")
                keys.append(key)
                index[key] = len(keys) - 1
                tops.append(next[0])
                bottoms.append(next[1])
                deltas.append(reached^)
                dead.append(False)
                at = len(keys) - 1
            delta.append(at)
        done += 1

    var accepting = List[Bool]()
    for s in range(len(keys)):
        if dead[s]:
            accepting.append(False)
            continue
        accepting.append(
            _is_zero(deltas[s]) and (tops[s] == bottoms[s] or not letters_must_agree)
        )
    return Dfa(letters, delta, accepting)


def parikh_equality_automaton[D: DifferenceBound](
    sigma: Substitution, top: Int, bottom: Int, bound: D, cap: Int = STATE_CAP
) raises -> Dfa:
    """Pairs of admissible paths of one length whose prefixes carry one Parikh
    vector, saying nothing about the letters they reach."""
    return coincidence_automaton(sigma, top, bottom, bound, cap, False)


def coincidence_witness[D: DifferenceBound](
    sigma: Substitution, top: Int, bottom: Int, bound: D, cap: Int = STATE_CAP
) raises -> Witness:
    """Breadth-first over the same state space, stopping at the first accepting
    state rather than building the whole language first.

    Same answer as `witness(coincidence_automaton(...))` and much less work for
    a pair that coincides early: a shallow search visits a handful of states
    where the full construction would close a set of thousands."""
    require_letter_pair(sigma, top, bottom)
    if cap < 1:
        raise Error("a state cap is positive")
    var frontier = _Frontier(sigma, bound)
    var zero = List[Int](length=sigma.size, fill=0)
    var keys: List[String] = [_key(top, bottom, zero)]
    var seen = Dict[String, Int]()
    seen[keys[0]] = 0
    var tops: List[Int] = [top]
    var bottoms: List[Int] = [bottom]
    var deltas: List[List[Int]] = [zero.copy()]
    var parent: List[Int] = [-1]
    var arrival: List[Int] = [-1]
    var letters = frontier.letters()

    var done = 0
    while done < len(keys):
        if tops[done] == bottoms[done] and _is_zero(deltas[done]):
            var reversed = List[Int]()
            var walk = done
            while parent[walk] >= 0:
                reversed.append(arrival[walk])
                walk = parent[walk]
            var word = List[Int]()
            for i in range(len(reversed)):
                word.append(reversed[len(reversed) - 1 - i])
            return Witness(word, False)
        for packed in range(letters):
            var next = frontier.step(
                tops[done], bottoms[done], deltas[done], packed
            )
            if len(next) == 0:
                continue
            var reached = List[Int]()
            for i in range(sigma.size):
                reached.append(next[2 + i])
            var key = _key(next[0], next[1], reached)
            if key in seen:
                continue
            if len(keys) >= cap:
                raise Error("coincidence state set past the cap: see the finiteness argument")
            seen[key] = len(keys)
            keys.append(key)
            tops.append(next[0])
            bottoms.append(next[1])
            deltas.append(reached^)
            parent.append(done)
            arrival.append(packed)
        done += 1
    return Witness(List[Int](), True)


def coincidence_level[D: DifferenceBound](
    sigma: Substitution, top: Int, bottom: Int, bound: D
) raises -> Int:
    """The least `k` with a coincidence of the pair inside `sigma^k`, or `-1`:
    a decided negative given a sound bound, not an exhausted budget."""
    var found = coincidence_witness(sigma, top, bottom, bound)
    return -1 if found.empty else len(found.word)


def first_letter_merge_level(sigma: Substitution, top: Int, bottom: Int) -> Int:
    """The least `n` with `h^n(top) = h^n(bottom)`, `h(a) = sigma(a)[0]` the
    first-letter map, or `-1`. Then `sigma^n(top)` and `sigma^n(bottom)` start
    with one letter, a coincidence at the left end, so `n` bounds the level.
    Two orbits of a self-map of `d` letters that ever meet do so within `d - 1`
    steps (the tail of one of them is at most that long)."""
    var x = top
    var y = bottom
    for n in range(sigma.size):
        if x == y:
            return n
        x = sigma.images[x][0]
        y = sigma.images[y][0]
    return -1


def balanced_proper_prefix_pairs(sigma: Substitution, top: Int, bottom: Int) -> Int:
    """The number of pairs `(p, q)` of nonempty proper prefixes of
    `sigma(top)`, `sigma(bottom)` with `ab(p) = ab(q)`: the offset-zero children
    of the aligned overlap `(top, bottom, 0)` other than its leftmost one."""
    var count = 0
    ref upper = sigma.images[top]
    ref lower = sigma.images[bottom]
    var above = List[Int](length=sigma.size, fill=0)
    for p in range(1, len(upper)):
        above[upper[p - 1]] += 1
        var below = List[Int](length=sigma.size, fill=0)
        for q in range(1, len(lower)):
            below[lower[q - 1]] += 1
            var same = True
            for c in range(sigma.size):
                same = same and above[c] == below[c]
            count += Int(same)
    return count


def pair_paths(radix: Int, word: List[Int]) raises -> List[List[Int]]:
    """The two path words a packed pair word carries, top track first."""
    if radix < 1:
        raise Error("a digit alphabet has at least one digit")
    var top = List[Int]()
    var bottom = List[Int]()
    for i in range(len(word)):
        if word[i] < 0 or word[i] >= radix * radix:
            raise Error("a packed digit pair lies outside the alphabet")
        top.append(word[i] % radix)
        bottom.append(word[i] // radix)
    var out = List[List[Int]]()
    out.append(top^)
    out.append(bottom^)
    return out^


def path_prefix_parikh[S: DifferenceStep](
    sigma: Substitution, step: S, letter: Int, path: List[Int]
) raises -> List[Int]:
    """The Parikh vector of what a Dumont-Thomas path skips: the prefix of
    `sigma^|path|(letter)` before the position the path names.

    Independent of the automaton, so a witness can be checked rather than
    trusted. The position itself is the sum of the coordinates."""
    if letter < 0 or letter >= sigma.size:
        raise Error("a path starts at a letter of the substitution")
    var parikh = List[Int](length=sigma.size, fill=0)
    var current = letter
    for t in range(len(path)):
        var digit = path[t]
        if digit < 0 or digit >= len(sigma.images[current]):
            raise Error("inadmissible path digit for this letter")
        parikh = step.advance(parikh, skipped(sigma, current, digit))
        current = sigma.images[current][digit]
    return parikh^


def path_letter(sigma: Substitution, letter: Int, path: List[Int]) raises -> Int:
    """The letter a path reaches, which is the one standing at its position."""
    var current = letter
    for t in range(len(path)):
        if path[t] < 0 or path[t] >= len(sigma.images[current]):
            raise Error("inadmissible path digit for this letter")
        current = sigma.images[current][path[t]]
    return current


def _on_track(single: Dfa, track: Int, radix: Int) raises -> Dfa:
    """A one-track condition, placed on its track of the pair alphabet."""
    return cylinder(widened(single, radix), TRACKS, track, radix)


def reaching_one_letter(sigma: Substitution, top: Int, bottom: Int) raises -> Dfa:
    """`or over letters a : end_top(P) = a and end_bottom(Q) = a`, built out of
    the Dumont-Thomas letter map and nothing else."""
    require_letter_pair(sigma, top, bottom)
    var radix = max_image_length(sigma)
    var assembled = Dfa(radix * radix, List[Int](length=radix * radix, fill=0), [False])
    for letter in range(sigma.size):
        var both = intersection(
            _on_track(letter_automaton(sigma, top, letter), PATH_TRACK, radix),
            _on_track(letter_automaton(sigma, bottom, letter), OTHER_TRACK, radix),
        )
        assembled = both.copy() if letter == 0 else union(assembled, both)
    return minimised(assembled)


def coincidence_by_elimination(
    sigma: Substitution, top: Int, bottom: Int, parikh_equality: Dfa
) raises -> Dfa:
    """The formula assembled conjunct by conjunct and minimised:
    admissibility on both tracks, the letter conjunct, and the caller's
    Parikh-equality relation (`parikh_equality_automaton`).

    The admissibility conjuncts are applied before the Parikh relation, which is
    the largest automaton by far: the product is built before it is minimised,
    so intersecting the small conditions first is the difference between a
    product that closes and one that does not."""
    require_letter_pair(sigma, top, bottom)
    var radix = max_image_length(sigma)
    var conditions = intersection(
        _on_track(numeration_automaton(sigma, top), PATH_TRACK, radix),
        _on_track(numeration_automaton(sigma, bottom), OTHER_TRACK, radix),
    )
    conditions = minimised(intersection(conditions, reaching_one_letter(sigma, top, bottom)))
    return minimised(intersection(conditions, parikh_equality))


def coincident_positions(eliminated: Dfa) raises -> Dfa:
    """The paths on the first track at which the pair coincides, with the other
    path quantified away by the subset construction: a recognisable *set* of
    positions rather than one witness."""
    return minimised(project(eliminated, TRACKS, OTHER_TRACK))


struct PairDepthBound(Copyable, Movable):
    """A fixed-substitution graph bound on the least coincidence level and its
    nonemptiness outcome."""

    var states: Int
    var coaccessible: Int
    var upper: Int
    var level: Int
    var empty: Bool

    def __init__(out self, states: Int, coaccessible: Int, upper: Int, level: Int, empty: Bool):
        self.states = states
        self.coaccessible = coaccessible
        self.upper = upper
        self.level = level
        self.empty = empty

    def certifies_level(self) -> Bool:
        return self.empty or (self.level >= 0 and self.level <= self.upper)


def coaccessible_state_count(automaton: Dfa) raises -> Int:
    """Count states from which some accepting state is reachable.

    The automata built here contain only forward-reachable states, so reverse
    reachability from every accepting state gives exactly the states that can
    lie on an accepting run. A graph computation: no spectral approximation and
    no substitution hypothesis enters."""
    var reverse = List[List[Int]]()
    for _ in range(automaton.states()):
        reverse.append(List[Int]())
    for source in range(automaton.states()):
        for letter in range(automaton.letters):
            reverse[automaton.step(source, letter)].append(source)

    var live = List[Bool](length=automaton.states(), fill=False)
    var queue = List[Int]()
    for state in range(automaton.states()):
        if automaton.accepting[state]:
            live[state] = True
            queue.append(state)
    var head = 0
    while head < len(queue):
        var target = queue[head]
        head += 1
        for i in range(len(reverse[target])):
            var source = reverse[target][i]
            if not live[source]:
                live[source] = True
                queue.append(source)
    return len(queue)


def depth_bound(automaton: Dfa) raises -> PairDepthBound:
    """The bound one complete reachable coincidence automaton certifies.

    When its language is nonempty, the shortest level is at most
    `coaccessible - 1`: every state on a shortest accepting run can reach its
    accepting endpoint, and deleting a repeated-state segment would give a
    shorter run. States that cannot reach acceptance -- including the rejecting
    sink -- are excluded exactly by reverse reachability."""
    var found = witness(automaton)
    var coaccessible = coaccessible_state_count(automaton)
    var upper = -1 if found.empty else coaccessible - 1
    var level = -1 if found.empty else len(found.word)
    var out = PairDepthBound(
        automaton.states(), coaccessible, upper, level, found.empty
    )
    if not out.certifies_level():
        raise Error("shortest coincidence path exceeds its finite-state bound")
    return out^


def worst_depth_bound(pairs: List[PairDepthBound]) -> PairDepthBound:
    """The maximum over pair bounds; `level = -1` when some pair language is
    empty, in which case the state bound is diagnostic only."""
    var largest_states = 0
    var largest_coaccessible = 0
    var largest_upper = -1
    var largest_level = 0
    var any_empty = False
    for i in range(len(pairs)):
        ref pair = pairs[i]
        if pair.states > largest_states:
            largest_states = pair.states
        if pair.coaccessible > largest_coaccessible:
            largest_coaccessible = pair.coaccessible
        if pair.upper > largest_upper:
            largest_upper = pair.upper
        if pair.empty:
            any_empty = True
        elif pair.level > largest_level:
            largest_level = pair.level
    return PairDepthBound(
        largest_states,
        largest_coaccessible,
        largest_upper,
        -1 if any_empty else largest_level,
        any_empty,
    )
