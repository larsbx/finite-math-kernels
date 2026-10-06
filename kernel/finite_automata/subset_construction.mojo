"""Projection of a product-alphabet DFA by the subset construction.

Dropping one track of a product alphabet leaves a nondeterministic automaton;
the subset (powerset) construction determinises it, numbering subsets by
first encounter. References: M. O. Rabin and D. Scott, "Finite automata and
their decision problems", IBM J. Res. Develop. 3 (1959) 114-125; J. E.
Hopcroft and J. D. Ullman, *Introduction to Automata Theory, Languages, and
Computation* (Addison-Wesley, 1979), section 2.3.

`project` was previously in `finite_automata/dfa.mojo`, which still
re-exports it. What is claimed: the result accepts a word exactly when some
value of the dropped track completes it.
"""

from finite_automata.dfa import Dfa


def _subset_index(mut index: Dict[String, Int], mut sets: List[List[Int]], key: String,
                  members: List[Int]) raises -> Int:
    """Index a subset by its key, appending it when it is new.

    The index is a hash map, not a scanned list: the subset construction asks
    this question once per (state, letter), so a linear scan makes the
    determinisation quadratic in the number of subsets. Subsets are still
    numbered by first encounter, so the automaton this returns is the one the
    scan returned, not merely one with the same language."""
    if key in index:
        return index[key]
    var at = len(sets)
    index[key] = at
    sets.append(members.copy())
    return at


def project(a: Dfa, tracks: Int, track: Int) raises -> Dfa:
    """Existential quantification over one track of a product alphabet.

    A letter of `a` is a tuple of `tracks` digits packed in base `radix`, digit
    `track` least significant by position `track`. Dropping that track leaves a
    nondeterministic automaton -- several values of the quantified digit may be
    read -- which the subset construction determinises. The result accepts a
    word exactly when some value of the dropped track completes it, which is
    what `exists` means on a track.
    """
    if tracks < 1 or track < 0 or track >= tracks:
        raise Error("track outside the product alphabet")
    var radix = 1
    while radix ** tracks < a.letters:
        radix += 1
    if radix ** tracks != a.letters:
        raise Error("alphabet is not a power of a radix")
    var out_letters = radix ** (tracks - 1)

    var index = Dict[String, Int]()
    var sets = List[List[Int]]()
    var start: List[Int] = [0]
    _ = _subset_index(index, sets, String("0"), start)
    var delta = List[Int]()
    var accepting = List[Bool]()
    var done = 0
    while done < len(sets):
        var members = sets[done].copy()
        var accepts = False
        for i in range(len(members)):
            if a.accepting[members[i]]:
                accepts = True
        accepting.append(accepts)
        for letter in range(out_letters):
            # rebuild the full letter by reinserting every value of `track`
            var reached = List[Bool](length=a.states(), fill=False)
            var image = List[Int]()
            for value in range(radix):
                var full = 0
                var rest = letter
                for position in range(tracks):
                    var digit = value
                    if position != track:
                        digit = rest % radix
                        rest = rest // radix
                    full += digit * (radix ** position)
                for i in range(len(members)):
                    var next = a.step(members[i], full)
                    if not reached[next]:
                        reached[next] = True
                        image.append(next)
            sort(image)
            var key = String("")
            for i in range(len(image)):
                key += String(image[i]) + ","
            delta.append(_subset_index(index, sets, key, image))
        done += 1
    return Dfa(out_letters, delta, accepting)
