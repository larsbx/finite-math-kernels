"""The balanced-pair automaton `B_sigma`: reachable states and components.

`build` explores breadth-first from the swap seeds. It stops at `max_states`
and returns `capped = True` with no edges; a capped automaton is an
incomplete prefix of the graph, so `sccs`, `recurrent_noncoincident_sccs`,
and `nonproductive_states` raise on it instead of turning the cap into
evidence. Component routines are iterative and index-based.
"""

from substitution_dynamics.balanced_pairs import children, normalise, seed_states
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.words import Pair


struct Automaton(Copyable, Movable):
    """Reachable part of `B_sigma`: states plus an adjacency list of indices."""

    var states: List[Pair]
    var adj: List[List[Int]]
    var capped: Bool
    var alphabet: Int

    def __init__(out self, states: List[Pair], adj: List[List[Int]], capped: Bool, alphabet: Int):
        self.states = states.copy()
        self.adj = adj.copy()
        self.capped = capped
        self.alphabet = alphabet

    def size(self) -> Int:
        return len(self.states)


def build(sigma: Substitution, max_states: Int = 20000) raises -> Automaton:
    var states = List[Pair]()
    var adj = List[List[Int]]()
    var index = Dict[String, Int]()
    var queue = List[Pair]()
    var capped = False

    var seeds = seed_states(sigma.size)
    for i in range(len(seeds)):
        queue.append(normalise(seeds[i]))

    var head = 0
    while head < len(queue):
        var s = queue[head].copy()
        head += 1
        var k = s.key()
        if k in index:
            continue
        if len(states) >= max_states:
            capped = True
            break
        index[k] = len(states)
        states.append(s.copy())
        adj.append(List[Int]())
        if s.is_coincidence():
            continue
        var cs = children(sigma, s)
        for i in range(len(cs)):
            queue.append(cs[i].copy())

    if capped:
        return Automaton(states, adj, True, sigma.size)

    # second pass: edges, now that every reachable state has an index
    for i in range(len(states)):
        if states[i].is_coincidence():
            continue
        var cs = children(sigma, states[i])
        for j in range(len(cs)):
            var ck = cs[j].key()
            if ck in index:
                adj[i].append(index[ck])
    return Automaton(states, adj, False, sigma.size)


def require_complete(a: Automaton) raises:
    """Component and productivity queries are undefined on a capped prefix."""
    if a.capped:
        raise Error("automaton is capped: components and productivity are undefined on a partial graph")


def sccs(a: Automaton) raises -> List[List[Int]]:
    """Tarjan's algorithm, iterative (no recursion-depth limit)."""
    require_complete(a)
    var n = a.size()
    var idx = List[Int]()
    var low = List[Int]()
    var on = List[Bool]()
    for _ in range(n):
        idx.append(-1)
        low.append(0)
        on.append(False)
    var stack = List[Int]()
    var out = List[List[Int]]()
    var counter = 0

    for root in range(n):
        if idx[root] != -1:
            continue
        var call = List[Int]()
        var pos = List[Int]()
        call.append(root)
        pos.append(0)
        idx[root] = counter
        low[root] = counter
        counter += 1
        stack.append(root)
        on[root] = True

        while len(call) > 0:
            var v = call[len(call) - 1]
            var p = pos[len(pos) - 1]
            if p < len(a.adj[v]):
                pos[len(pos) - 1] = p + 1
                var w = a.adj[v][p]
                if idx[w] == -1:
                    idx[w] = counter
                    low[w] = counter
                    counter += 1
                    stack.append(w)
                    on[w] = True
                    call.append(w)
                    pos.append(0)
                elif on[w]:
                    if idx[w] < low[v]:
                        low[v] = idx[w]
            else:
                _ = call.pop()
                _ = pos.pop()
                if len(call) > 0:
                    var parent = call[len(call) - 1]
                    if low[v] < low[parent]:
                        low[parent] = low[v]
                if low[v] == idx[v]:
                    var comp = List[Int]()
                    while True:
                        var w = stack.pop()
                        on[w] = False
                        comp.append(w)
                        if w == v:
                            break
                    out.append(comp^)
    return out^


def has_cycle(a: Automaton, comp: List[Int]) -> Bool:
    if len(comp) > 1:
        return True
    var v = comp[0]
    for i in range(len(a.adj[v])):
        if a.adj[v][i] == v:
            return True
    return False


def is_noncoincident(a: Automaton, comp: List[Int]) -> Bool:
    for i in range(len(comp)):
        if a.states[comp[i]].is_coincidence():
            return False
    return True


def recurrent_noncoincident_sccs(a: Automaton) raises -> List[List[Int]]:
    var all = sccs(a)
    var out = List[List[Int]]()
    for i in range(len(all)):
        if has_cycle(a, all[i]) and is_noncoincident(a, all[i]):
            out.append(all[i].copy())
    return out^


def nonproductive_states(a: Automaton) raises -> List[Int]:
    """Indices of states from which no coincidence pair is reachable.

    An empty result for one substitution eliminates counterexamples for that
    substitution; it proves nothing in general. Raises on a capped automaton.
    """
    require_complete(a)
    var n = a.size()
    var good = List[Bool]()
    for i in range(n):
        good.append(a.states[i].is_coincidence())
    # backwards closure over the reverse graph, to a fixpoint
    var changed = True
    while changed:
        changed = False
        for i in range(n):
            if good[i]:
                continue
            for j in range(len(a.adj[i])):
                if good[a.adj[i][j]]:
                    good[i] = True
                    changed = True
    var out = List[Int]()
    for i in range(n):
        if not good[i]:
            out.append(i)
    return out^
