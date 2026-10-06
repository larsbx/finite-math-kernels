"""Minimisation of a DFA by Moore's partition refinement.

Starting from the accepting/rejecting split of the reachable states, classes
are refined by the classes of their successors until stable; the result is
the minimal automaton of the language, unique up to renaming (here numbered
canonically from the start state). References: E. F. Moore,
"Gedanken-experiments on sequential machines", in *Automata Studies*, Annals
of Mathematics Studies 34 (Princeton, 1956) 129-153; J. E. Hopcroft and
J. D. Ullman, *Introduction to Automata Theory, Languages, and Computation*
(Addison-Wesley, 1979), section 3.4 (the Myhill-Nerode theorem).

`minimised` was previously in `finite_automata/dfa.mojo`, which still
re-exports it.
"""

from finite_automata.dfa import Dfa


def minimised(a: Dfa) raises -> Dfa:
    """Moore refinement from the accepting/rejecting split, over the reachable
    part. Two automata with the same language have the same minimal automaton,
    so this is also how two constructions are compared for equality."""
    # reachable states first: unreachable ones would survive refinement as
    # classes of their own and make the result depend on how it was built.
    var seen = List[Bool](length=a.states(), fill=False)
    var order = List[Int]()
    var queue: List[Int] = [0]
    seen[0] = True
    var head = 0
    while head < len(queue):
        var state = queue[head]
        head += 1
        order.append(state)
        for c in range(a.letters):
            var next = a.step(state, c)
            if not seen[next]:
                seen[next] = True
                queue.append(next)

    var block = List[Int](length=a.states(), fill=-1)
    for i in range(len(order)):
        block[order[i]] = 1 if a.accepting[order[i]] else 0
    var blocks = 2
    while True:
        # the signature -> class map is a hash index: scanning it would make
        # every refinement round quadratic in the number of classes
        var classes = Dict[String, Int]()
        var next_block = List[Int](length=a.states(), fill=-1)
        for i in range(len(order)):
            var state = order[i]
            var key = String(block[state]) + "|"
            for c in range(a.letters):
                key += String(block[a.step(state, c)]) + ","
            var at: Int
            if key in classes:
                at = classes[key]
            else:
                at = len(classes)
                classes[key] = at
            next_block[state] = at
        for i in range(len(order)):
            block[order[i]] = next_block[order[i]]
        if len(classes) == blocks:
            break
        blocks = len(classes)

    # renumber so the start block is 0, which `Dfa` requires
    var relabel = List[Int](length=blocks, fill=-1)
    relabel[block[0]] = 0
    var used = 1
    for i in range(len(order)):
        var b = block[order[i]]
        if relabel[b] < 0:
            relabel[b] = used
            used += 1
    var delta = List[Int](length=used * a.letters, fill=0)
    var accepting = List[Bool](length=used, fill=False)
    for i in range(len(order)):
        var state = order[i]
        var b = relabel[block[state]]
        accepting[b] = a.accepting[state]
        for c in range(a.letters):
            delta[b * a.letters + c] = relabel[block[a.step(state, c)]]
    return Dfa(a.letters, delta, accepting)
