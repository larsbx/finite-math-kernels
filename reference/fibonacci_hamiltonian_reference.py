#!/usr/bin/env python3
"""Reference model of the Fibonacci trace polynomials and their band edges.

Specification: docs/fibonacci-hamiltonian-band-edges-spec.md. This module is
the executable form of that document, written before the Mojo kernel
``fibonacci_hamiltonian`` and kept as its independent oracle:
``tests/fibonacci_hamiltonian/test_band_edges_reference.py`` asserts the
constants that ``tests/fibonacci_hamiltonian/test_band_edges.mojo`` asserts.
Pure functions over tuples of ``Fraction``; no floating point, no theorem.

The trace polynomials are ``t_(-1) = 2``, ``t_0 = E``, ``t_1 = E - lam`` and
``t_(k+1) = t_k t_(k-1) - t_(k-2)`` (A. Suto, "The spectrum of a quasiperiodic
Schrodinger operator", Comm. Math. Phys. 111 (1987) 409-415, in the
normalization ``t_k = 2 x_k``). What their sublevel sets mean for an operator
is imported, never computed here; section 6 of the specification.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import qpoly_reference as qp  # noqa: E402

Poly = qp.Poly

TWO: Poly = qp.of(2)
FOUR: Poly = qp.of(4)


# --- section 1: the trace polynomials -------------------------------------------


def trace_polynomials(k: int, lam: int | Fraction) -> tuple[Poly, ...]:
    """`(t_0, ..., t_k)` in `Q[E]`, for `k >= 0`."""
    if k < 0:
        raise ValueError("the level is at least zero")
    before, levels = TWO, [qp.of(0, 1), qp.of(-Fraction(lam), 1)]
    while len(levels) <= k:
        nxt = qp.sub(qp.mul(levels[-1], levels[-2]), before)
        before = levels[-2]
        levels.append(nxt)
    return tuple(levels[: k + 1])


def trace_polynomial(k: int, lam: int | Fraction) -> Poly:
    return trace_polynomials(k, lam)[k]


def trace_value(k: int, lam: int | Fraction, energy: int | Fraction) -> Fraction:
    """`t_k(energy)` by the scalar recurrence, without forming a polynomial."""
    if k < 0:
        raise ValueError("the level is at least zero")
    before, here, after = Fraction(2), Fraction(energy), Fraction(energy) - Fraction(lam)
    for _ in range(k):
        before, here, after = here, after, after * here - before
    return here


def invariant(a: Poly, b: Poly, c: Poly) -> Poly:
    """`a^2 + b^2 + c^2 - a b c - 4`, the Fricke-Vogt invariant of three traces."""
    squares = qp.add(qp.add(qp.mul(a, a), qp.mul(b, b)), qp.mul(c, c))
    return qp.sub(qp.sub(squares, qp.mul(qp.mul(a, b), c)), FOUR)


# --- sections 2 to 4: edges, segments, bands ------------------------------------


@dataclass(frozen=True, slots=True)
class Edge:
    """A bracket `lo < hi` holding one point where `t_k` equals `level`."""

    lo: Fraction
    hi: Fraction
    level: int


@dataclass(frozen=True, slots=True)
class Approximant:
    """The edges of level `k`, ascending, and its bands as index pairs into them."""

    k: int
    lam: Fraction
    edges: tuple[Edge, ...]
    bands: tuple[tuple[int, int], ...]

    def outer(self) -> tuple[tuple[Fraction, Fraction], ...]:
        return tuple((self.edges[a].lo, self.edges[b].hi) for a, b in self.bands)

    def inner(self) -> tuple[tuple[Fraction, Fraction], ...]:
        return tuple((self.edges[a].hi, self.edges[b].lo) for a, b in self.bands)

    def gap_bounds(self) -> tuple[tuple[Fraction, Fraction], ...]:
        """`(lower, upper)` for the length of each gap between consecutive bands."""
        return tuple(
            (self.edges[c].lo - self.edges[b].hi, self.edges[c].hi - self.edges[b].lo)
            for (_, b), (c, _) in zip(self.bands, self.bands[1:])
        )

    def closed_gaps(self) -> int:
        return len(self.edges) - 2 * len(self.bands)


def merged(upper: list[Edge], lower: list[Edge]) -> list[tuple[int, int]]:
    """`(side, index)` in ascending `lo`; the `+2` side goes first on a tie."""
    out, i, j = [], 0, 0
    while i < len(upper) or j < len(lower):
        if j == len(lower) or (i < len(upper) and upper[i].lo <= lower[j].lo):
            out.append((0, i))
            i += 1
        else:
            out.append((1, j))
            j += 1
    return out


def separated_edges(
    k: int, lam: int | Fraction, width: int | Fraction, max_steps: int
) -> tuple[Edge, ...] | None:
    """The brackets of `t_k - 2` and `t_k + 2`, merged and halved until ordered."""
    trace = trace_polynomial(k, lam)
    parts = (qp.squarefree_part(qp.sub(trace, TWO)), qp.squarefree_part(qp.add(trace, TWO)))
    sides: list[list[Edge]] = []
    for level, part in zip((2, -2), parts):
        brackets = qp.real_root_brackets(part, width, max_steps)
        if brackets is None:
            return None
        sides.append([Edge(b.lo, b.hi, level) for b in brackets])
    steps = 0
    while True:
        order = merged(*sides)
        edges = [sides[side][index] for side, index in order]
        clash = next((i for i in range(len(edges) - 1) if edges[i].hi > edges[i + 1].lo), None)
        if clash is None:
            return tuple(edges)
        for side, index in order[clash : clash + 2]:
            if steps >= max_steps:
                return None
            steps += 1
            edge = sides[side][index]
            sides[side][index] = Edge(*qp.halve_bracket(parts[side], edge.lo, edge.hi), edge.level)


def approximant(
    k: int,
    lam: int | Fraction,
    width: int | Fraction = qp.DEFAULT_WIDTH,
    max_steps: int = 1 << 16,
) -> Approximant | None:
    """The bands of `{E : |t_k(E)| <= 2}` between certified edges, or a refusal."""
    lam = Fraction(lam)
    edges = separated_edges(k, lam, width, max_steps)
    if edges is None or not edges:
        return None
    inside = []
    for left, right in zip(edges, edges[1:]):
        value = abs(trace_value(k, lam, (left.hi + right.lo) / 2))
        if value == 2:
            return None
        inside.append(value < 2)
    bands, start = [], None
    for i in range(len(edges)):
        before = inside[i - 1] if i > 0 else False
        after = inside[i] if i < len(inside) else False
        if not before and not after:
            return None
        if after and not before:
            start = i
        if before and not after:
            bands.append((start, i))
    return Approximant(k, lam, edges, tuple(bands))


# --- section 5: the cover by two consecutive levels ------------------------------


def cover(first: Approximant, second: Approximant) -> tuple[tuple[Fraction, Fraction], ...]:
    """The outer band enclosures of both levels, merged into ascending disjoint intervals."""
    merged: list[tuple[Fraction, Fraction]] = []
    for lo, hi in sorted(first.outer() + second.outer()):
        if merged and lo <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], hi))
        else:
            merged.append((lo, hi))
    return tuple(merged)
