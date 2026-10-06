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
        if state.is_coincidence():
            continue
        var cs = children(sigma, state)
        for i in range(len(cs)):
            queue.append(cs[i].copy())

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
