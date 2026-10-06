"""Disjoint-set forest on `0..len(parent)-1`.

`parent[x] == x` marks a root. The forest is the caller's list, so a consumer
that already keeps one can call these directly; `singletons(n)` builds one.

References: B. A. Galler and M. J. Fischer, "An improved equivalence
algorithm", Comm. ACM 7 (1964) 301-303 (the disjoint-set forest); R. E.
Tarjan, "Efficiency of a good but not linear set union algorithm", J. ACM 22
(1975) 215-225. No union by rank and no path compression here: the forest is
the caller's list and stays as the caller left it apart from the one link
`union` adds.
"""


def singletons(n: Int) -> List[Int]:
    var parent = List[Int]()
    for i in range(n):
        parent.append(i)
    return parent^


def find_root(parent: List[Int], x: Int) -> Int:
    var root = x
    while parent[root] != root:
        root = parent[root]
    return root


def union(mut parent: List[Int], a: Int, b: Int):
    """Merge the classes of `a` and `b`; the root of `a`'s class survives."""
    var ra = find_root(parent, a)
    var rb = find_root(parent, b)
    if ra != rb:
        parent[rb] = ra
