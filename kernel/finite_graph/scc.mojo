"""Strongly connected components of a finite directed graph.

A graph is an adjacency list `adj` on the vertices `0..len(adj)-1`: `adj[v]`
lists the heads of the edges out of `v`. Components are returned in Tarjan's
emission order, which is a reverse topological order of the condensation, and
each component lists its vertices in the order they left the stack.

Every consumer that walks a finite automaton for its recurrent part needs the
same two facts, so they live here once rather than beside each automaton type.

Reference: R. E. Tarjan, "Depth-first search and linear graph algorithms",
SIAM J. Comput. 1 (1972) 146-160. The module is named after the object it
computes; the algorithm is Tarjan's, made iterative.
"""


def sccs(adj: List[List[Int]]) -> List[List[Int]]:
    """Tarjan's algorithm, iterative (no recursion-depth limit)."""
    var n = len(adj)
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
            if p < len(adj[v]):
                pos[len(pos) - 1] = p + 1
                var w = adj[v][p]
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


def has_cycle(adj: List[List[Int]], comp: List[Int]) -> Bool:
    """Whether a strongly connected component carries a cycle: it has two or
    more vertices, or its one vertex has a loop."""
    if len(comp) > 1:
        return True
    var v = comp[0]
    for i in range(len(adj[v])):
        if adj[v][i] == v:
            return True
    return False
