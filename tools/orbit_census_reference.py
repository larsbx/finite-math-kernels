#!/usr/bin/env python3
"""Reference semantics of contract ``orbit-census-v1``.

The smallest executable statement of section 3 of
``docs/polyglot-orbit-census-design.md``. It generates the golden vectors and
has no acceptance authority: the Mojo replay predicate in
``finite_field_orbit/census.mojo`` is the only authority.

Everything here is a pure function of its arguments.
"""

from __future__ import annotations

import hashlib
from dataclasses import astuple, dataclass, replace
from functools import reduce
from typing import NamedTuple

TAG = "orbit-census-v1"
BOUND = 2**32
FIELDS = ("n", "resolved", "sum_mu", "sum_lambda", "periodic", "has_w", "w_seed", "w_mu", "w_lambda")
BLOCK_FIELDS = ("p", "c", "cap", "lo", "hi")


class Block(NamedTuple):
    p: int
    c: int
    cap: int
    lo: int
    hi: int


@dataclass(frozen=True)
class Agg:
    n: int = 0
    resolved: int = 0
    sum_mu: int = 0
    sum_lambda: int = 0
    periodic: int = 0
    has_w: int = 0
    w_seed: int = 0
    w_mu: int = 0
    w_lambda: int = 0


EMPTY = Agg()


def is_prime(p: int) -> bool:
    return p >= 2 and all(p % d for d in range(2, int(p**0.5) + 1))


def malformed_field(b: Block) -> str | None:
    """The first field that makes ``b`` ill-formed, or None (section 3.1)."""
    if not (is_prime(b.p) and b.p < BOUND):
        return "p"
    if not 0 <= b.c < b.p:
        return "c"
    if not 0 <= b.cap < BOUND:
        return "cap"
    if not 0 <= b.lo <= b.hi:
        return "lo"
    if not b.hi <= b.p:
        return "hi"
    return None


def rho(p: int, c: int, cap: int, seed: int) -> tuple[int, int] | None:
    """``(mu, lambda)`` when the first repeat index ``j`` is at most ``cap``."""
    first_seen: dict[int, int] = {}
    x, j = seed, 0
    while x not in first_seen:
        if j == cap:
            return None
        first_seen[x] = j
        x, j = (x * x + c) % p, j + 1
    mu = first_seen[x]
    return mu, j - mu


def leaf(b: Block, seed: int) -> Agg:
    r = rho(b.p, b.c, b.cap, seed)
    if r is None:
        return Agg(n=1)
    mu, lam = r
    return Agg(1, 1, mu, lam, int(mu == 0), 1, seed, mu, lam)


def _witness_key(a: Agg) -> tuple[int, int]:
    return (-(a.w_mu + a.w_lambda), a.w_seed)


def merge(a: Agg, b: Agg) -> Agg:
    """The monoid of section 3.3; ``EMPTY`` is its identity."""
    w = a if not b.has_w or (a.has_w and _witness_key(a) <= _witness_key(b)) else b
    return Agg(a.n + b.n, a.resolved + b.resolved, a.sum_mu + b.sum_mu, a.sum_lambda + b.sum_lambda,
               a.periodic + b.periodic, w.has_w, w.w_seed, w.w_mu, w.w_lambda)


def census(b: Block) -> Agg:
    if (field := malformed_field(b)) is not None:
        raise ValueError(f"malformed:{field}")
    return reduce(merge, (leaf(b, s) for s in range(b.lo, b.hi)), EMPTY)


def tree_census(b: Block, cuts: list[int]) -> Agg:
    """Census over the partition of ``[lo, hi)`` at ``cuts``; must equal ``census``."""
    edges = [b.lo, *sorted(c for c in cuts if b.lo < c < b.hi), b.hi]
    return reduce(merge, (census(b._replace(lo=l, hi=h)) for l, h in zip(edges, edges[1:])), EMPTY)


def encode(b: Block, a: Agg) -> str:
    return " ".join([TAG, *map(str, (*b, *astuple(a)))])


def decode(line: str) -> tuple[Block, Agg]:
    """Total inverse of ``encode``: every other string raises ``ValueError('malformed:...')``."""
    tokens = line.split(" ")
    if len(tokens) != 1 + len(BLOCK_FIELDS) + len(FIELDS) or tokens[0] != TAG:
        raise ValueError("malformed:arity")
    names = BLOCK_FIELDS + FIELDS
    for name, t in zip(names, tokens[1:]):
        if not (t.isascii() and t.isdigit()) or (len(t) > 1 and t[0] == "0") or int(t) >= BOUND:
            raise ValueError(f"malformed:{name}")
    values = [int(t) for t in tokens[1:]]
    return Block(*values[:5]), Agg(*values[5:])


def digest(lines: list[str]) -> str:
    return hashlib.sha256("".join(line + "\n" for line in lines).encode("ascii")).hexdigest()


def trajectory(p: int, c: int, seed: int, steps: int) -> list[int]:
    xs = [seed]
    for _ in range(steps):
        xs.append((xs[-1] ** 2 + c) % p)
    return xs


def replay_verdict(b: Block, claimed: Agg) -> str:
    """What the authority must answer (section 4); the vectors pin this."""
    if (field := malformed_field(b)) is not None:
        return f"malformed:{field}"
    actual = census(b)
    for name, x, y in zip(FIELDS, astuple(claimed), astuple(actual)):
        if x != y:
            return f"mismatch:{name}"
    return "accepted"


def tamper(a: Agg, field: str, delta: int = 1) -> Agg:
    return replace(a, **{field: getattr(a, field) + delta})
