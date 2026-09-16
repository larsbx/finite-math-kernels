#!/usr/bin/env python3
"""Reference model of tuning substitutions, directive prefixes, and column coincidence.

Specification: docs/tuning-substitutions-spec.md. This module is the executable
form of that document, written before the Mojo kernels in
``substitution_dynamics/tuning.mojo``, ``substitution_dynamics/sadic.mojo``, and
``substitution_dynamics/coincidence.mojo`` and kept as their independent oracle:
``tests/substitution_dynamics/test_tuning_reference.py`` asserts the constants that
``tests/substitution_dynamics/test_tuning.mojo`` asserts, so the two agree on every
pinned value. Pure functions over tuples; no repository policy, no theorem.

A substitution is a tuple of images, ``images[a]`` a tuple of letters over the
alphabet ``0 .. len(images)-1``. A tuning pattern is ``(prefix, twist)`` with
``prefix`` a non-empty tuple over ``{0, 1}`` and ``twist`` a bool.
"""

from __future__ import annotations

from collections import deque
from collections.abc import Sequence

Word = tuple[int, ...]
Images = tuple[Word, ...]
Pattern = tuple[Word, bool]

MAX_COINCIDENCE_ALPHABET = 60


# --- section 1: tuning patterns and the star product ---------------------------


def checked_pattern(prefix: Sequence[int], twist: bool) -> Pattern:
    """Boundary: a non-empty prefix over ``{0, 1}``."""
    p = tuple(prefix)
    if not p:
        raise ValueError("tuning prefix must be non-empty (period at least 2)")
    if any(x not in (0, 1) for x in p):
        raise ValueError("tuning prefix letters must lie in {0, 1}")
    return (p, bool(twist))


def dgp_twist(prefix: Sequence[int]) -> bool:
    """Parity twist of Derrida, Gervois, and Pomeau: odd number of ``1`` in the prefix."""
    return sum(prefix) % 2 == 1


def dgp_pattern(prefix: Sequence[int]) -> Pattern:
    return checked_pattern(prefix, dgp_twist(prefix))


def period(pattern: Pattern) -> int:
    return len(pattern[0]) + 1


def tuning_substitution(pattern: Pattern) -> Images:
    """``tau(s) = prefix . (s xor twist)`` for ``s`` in ``{0, 1}``: constant length ``period``."""
    prefix, twist = pattern
    return tuple(prefix + (s ^ int(twist),) for s in (0, 1))


def apply(images: Images, word: Sequence[int]) -> Word:
    return tuple(x for a in word for x in images[a])


def compose(outer: Images, inner: Images) -> Images:
    """``(outer o inner)(a) = outer(inner(a))``; both over one alphabet."""
    if len(outer) != len(inner):
        raise ValueError("composition needs substitutions over one alphabet")
    return tuple(apply(outer, inner[a]) for a in range(len(inner)))


def star_product(a: Pattern, b: Pattern) -> Pattern:
    """``A * B``: prefix ``tau_A(B') . A'``, twist ``eps_A xor eps_B``, so that
    ``tuning_substitution(A * B) == compose(tuning_substitution(A), tuning_substitution(B))``."""
    prefix_a, twist_a = a
    prefix_b, twist_b = b
    return (apply(tuning_substitution(a), prefix_b) + prefix_a, twist_a != twist_b)


def kneading_prefix(patterns: Sequence[Pattern]) -> Word:
    """Prefix of the iterated star product ``A_1 * ... * A_n``; the first
    ``p_1 ... p_n - 1`` letters of every tuning of these patterns."""
    if not patterns:
        raise ValueError("directive sequence must be non-empty")
    acc = patterns[0]
    for p in patterns[1:]:
        acc = star_product(acc, p)
    return acc[0]


# --- section 2: directive prefixes ------------------------------------------------


def directive_composite(subs: Sequence[Images]) -> Images:
    """``sigma_1 o sigma_2 o ... o sigma_n``."""
    if not subs:
        raise ValueError("directive sequence must be non-empty")
    acc = subs[0]
    for s in subs[1:]:
        acc = compose(acc, s)
    return acc


def apply_directive(subs: Sequence[Images], word: Sequence[int]) -> Word:
    """``sigma_1(sigma_2(... sigma_n(word)))`` without forming the composite."""
    w = tuple(word)
    for s in reversed(subs):
        w = apply(s, w)
    return w


# --- section 3: column coincidence for constant-length substitutions ---------


def constant_length(images: Images) -> int | None:
    lengths = {len(img) for img in images}
    return lengths.pop() if len(lengths) == 1 else None


def column_coincidence(images: Images) -> tuple[int, Word] | None:
    """Least ``k`` with a column ``j`` of ``sigma^k`` constant over the alphabet,
    returned with the base-``q`` digits of ``j`` (one column choice per level),
    or ``None`` when no such column exists.

    Breadth-first search over subsets of the alphabet: from ``S`` the column
    ``c`` leads to ``{images[a][c] : a in S}``; a singleton at depth ``k`` is a
    constant column of ``sigma^k``. Exact and complete: the state space is finite.
    """
    q = constant_length(images)
    if q is None:
        raise ValueError("column coincidence is defined for constant-length substitutions only")
    n = len(images)
    if n > MAX_COINCIDENCE_ALPHABET:
        raise ValueError("alphabet too large for the subset search")
    start = frozenset(range(n))
    if len(start) == 1:
        return (0, ())
    parent: dict[frozenset[int], tuple[frozenset[int], int] | None] = {start: None}
    queue = deque([start])
    while queue:
        s = queue.popleft()
        for c in range(q):
            t = frozenset(images[a][c] for a in s)
            if t in parent:
                continue
            parent[t] = (s, c)
            if len(t) == 1:
                path: list[int] = []
                cur: frozenset[int] = t
                while parent[cur] is not None:
                    prev, col = parent[cur]  # type: ignore[misc]
                    path.append(col)
                    cur = prev
                path.reverse()
                return (len(path), tuple(path))
            queue.append(t)
    return None
