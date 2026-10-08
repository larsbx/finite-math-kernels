"""The balanced pair algorithm under a state-count *and* a state-length budget.

A. N. Livshits, "On the spectra of adic transformations of Markov compacta",
Russian Math. Surveys 42 (1987) 222-223; V. F. Sirvent and B. Solomyak,
"Pure discrete spectrum for one-dimensional substitution systems of Pisot
type", Canad. Math. Bull. 45 (2002) 697-710. The graph `B_sigma` of balanced
pairs is the same one `substitution_dynamics.automaton` builds.

The canonical builder in `substitution_dynamics.automaton` caps the number of
reachable states, which is the right contract where a discrepancy bound keeps
every reachable balanced pair short (a Pisot substitution, for instance). An
exploratory sweep visits substitutions with no discrepancy bound, where the
states themselves grow like `beta^n` and a state-count cap alone does not
bound the memory a single state needs.

`build_bounded` therefore stops on either budget and reports which one, so an
exhausted resource is recorded as inconclusive. A bounded automaton is a
partial prefix of the graph: like a capped one it must never be read as a
counterexample or as a proof. This is a second builder with a different
contract, not a copy of the canonical one. The alphabet is the
substitution's, `sigma.size`.

The length budget also bounds the work of a single inflation.
`bounded_children` sums the image lengths first, with a check that cannot
overflow, and when the inflated pair would exceed `max_length` it cuts the
blocks while reading the two images letter by letter, so it stops on the first
over-length block after `max_length + 1` letters instead of building it. Up to
that block the children are exactly `children(sigma, p)`. The builder queues no
child behind an over-length one, because breadth-first order never dequeues
them: the first over-length child is the last thing the queue would reach.
"""

from substitution_dynamics.automaton import Automaton
from substitution_dynamics.balanced_pairs import children, normalise, seed_states
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.words import Pair

comptime BUDGET_NONE = 0
comptime BUDGET_STATES = 1
comptime BUDGET_LENGTH = 2


struct BoundedAutomaton(Copyable, Movable):
    """A reachable prefix of `B_sigma` and the budget that stopped it."""

    var graph: Automaton
    var exhausted: Int
    var longest_state: Int

    def __init__(out self, var graph: Automaton, exhausted: Int, longest_state: Int):
        self.graph = graph^
        self.exhausted = exhausted
        self.longest_state = longest_state

    def complete(self) -> Bool:
        return self.exhausted == BUDGET_NONE and not self.graph.capped


struct BoundedChildren(Movable):
    """The children of one balanced pair up to the first over-length block.

    `children` is the prefix of `children(sigma, p)` before the first block
    longer than `max_length`; `over_budget` says such a block exists.
    `letters_read` counts the inflated letters read on each side: the whole
    inflation when it fits, else at most `max_length + 1` past the last cut.
    """

    var children: List[Pair]
    var over_budget: Bool
    var letters_read: Int

    def __init__(out self, var children: List[Pair], over_budget: Bool, letters_read: Int):
        self.children = children^
        self.over_budget = over_budget
        self.letters_read = letters_read


def _inflation_fits(sigma: Substitution, w: List[Int], cap: Int) -> Bool:
    """`|sigma(w)| <= cap`, summing image lengths with no overflow."""
    var total = 0
    for i in range(len(w)):
        var n = len(sigma.images[w[i]])
        if n > cap - total:
            return False
        total += n
    return True


def bounded_children(sigma: Substitution, p: Pair, max_length: Int) -> BoundedChildren:
    """`children(sigma, p)` up to its first block longer than `max_length`,
    never building that block. `p` is balanced, as every state is."""
    if _inflation_fits(sigma, p.u, max_length):
        var full = children(sigma, p)
        var n = 0
        for i in range(len(full)):
            n += full[i].length()
        return BoundedChildren(full^, False, n)

    var out = List[Pair]()
    var diff = List[Int](length=sigma.size, fill=0)
    var unequal = 0
    var bu = List[Int]()
    var bv = List[Int]()
    var iu = 0
    var ju = 0
    var iv = 0
    var jv = 0
    var read = 0
    while iu < len(p.u):
        ref img_u = sigma.images[p.u[iu]]
        ref img_v = sigma.images[p.v[iv]]
        var a = img_u[ju]
        var b = img_v[jv]
        ju += 1
        if ju == len(img_u):
            ju = 0
            iu += 1
        jv += 1
        if jv == len(img_v):
            jv = 0
            iv += 1
        read += 1
        if len(bu) == max_length:
            return BoundedChildren(out^, True, read)
        bu.append(a)
        bv.append(b)
        if a != b:
            if diff[a] == 0:
                unequal += 1
            diff[a] += 1
            if diff[a] == 0:
                unequal -= 1
            if diff[b] == 0:
                unequal += 1
            diff[b] -= 1
            if diff[b] == 0:
                unequal -= 1
        if unequal == 0:
            out.append(normalise(Pair(bu, bv)))
            bu = List[Int]()
            bv = List[Int]()
    return BoundedChildren(out^, False, read)


def build_bounded(
    sigma: Substitution, max_states: Int, max_length: Int
) raises -> BoundedAutomaton:
    """Breadth-first closure of the swap seeds, stopped by either budget."""
    if max_states <= 0 or max_length <= 0:
        raise Error("bounded balanced-pair budgets must be positive")

    var states = List[Pair]()
    var index = Dict[String, Int]()
    var queue = List[Pair]()
    var exhausted = BUDGET_NONE
    var longest = 0
    # An over-length child stands in the queue only as this flag: it sits
    # behind everything already queued, and nothing queued after it matters.
    var over_length_queued = False

    var seeds = seed_states(sigma.size)
    for i in range(len(seeds)):
        queue.append(normalise(seeds[i]))

    var head = 0
    while head < len(queue) and exhausted == BUDGET_NONE:
        var state = queue[head].copy()
        head += 1
        var key = state.key()
        if key in index:
            continue
        if len(states) >= max_states:
            exhausted = BUDGET_STATES
            break
        if state.length() > max_length:
            exhausted = BUDGET_LENGTH
            break
        if state.length() > longest:
            longest = state.length()
        index[key] = len(states)
        states.append(state.copy())
        if state.is_coincidence() or over_length_queued:
            continue
        var cs = bounded_children(sigma, state, max_length)
        for i in range(len(cs.children)):
            queue.append(cs.children[i].copy())
        if cs.over_budget:
            over_length_queued = True
    if exhausted == BUDGET_NONE and over_length_queued:
        # Dequeueing the over-length child: it is not a known state (every
        # known state fits), so the state budget is checked first, as above.
        exhausted = BUDGET_STATES if len(states) >= max_states else BUDGET_LENGTH

    var adj = List[List[Int]]()
    for _ in range(len(states)):
        adj.append(List[Int]())
    if exhausted != BUDGET_NONE:
        return BoundedAutomaton(Automaton(states, adj, True, sigma.size), exhausted, longest)

    for i in range(len(states)):
        if states[i].is_coincidence():
            continue
        var cs = children(sigma, states[i])
        for j in range(len(cs)):
            var key = cs[j].key()
            if key not in index:
                raise Error("terminated balanced-pair graph lost a reachable child")
            adj[i].append(index[key])
    return BoundedAutomaton(Automaton(states, adj, False, sigma.size), BUDGET_NONE, longest)
