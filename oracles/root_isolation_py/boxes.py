"""Generic box helpers for root isolation, in one or two complex variables.

Specification: docs/root-isolation-spec.md, sections 1, 3 and 6. A box is a
tuple of ``ComplexIQ`` (one per variable), a matrix a tuple of rows. Here:
the exact centre, the two preconditioners of section 1.4 (``exact_inverse``,
``midpoint_inverse``), the shared matrix helpers, and the two tests that need
no theorem -- exclusion and disjointness. The named certificates are
``krawczyk`` (the operator) and ``krawczyk_moore`` (the test).

Refusals are values: a rejected operand gives a rejected result and every
test answers ``False``. A malformed shape raises ``ValueError``.
"""

from __future__ import annotations

from fractions import Fraction
from typing import Callable

from closed_interval import ComplexIQ

Vector = tuple[ComplexIQ, ...]
Matrix = tuple[Vector, ...]
Round = Callable[[Fraction], Fraction]
Outward = Callable[[ComplexIQ], ComplexIQ]

ZERO = ComplexIQ.singleton(0)
ONE = ComplexIQ.singleton(1)


def _exact(x: Fraction) -> Fraction:
    return x


def _square(matrix: Matrix) -> int:
    n = len(matrix)
    if n == 0 or any(len(row) != n for row in matrix):
        raise ValueError("a preconditioner or Jacobian must be a non-empty n x n matrix")
    return n


def _refused(n: int) -> Matrix:
    return tuple(tuple(ComplexIQ.refused() for _ in range(n)) for _ in range(n))


def _is_point(z: ComplexIQ) -> bool:
    return z.accepted() and z.re.lo == z.re.hi and z.im.lo == z.im.hi


def _point(z: ComplexIQ, round_point: Round) -> ComplexIQ:
    return ComplexIQ.singleton(round_point(z.re.lo), round_point(z.im.lo))


def centre(x: Vector) -> Vector:
    """The exact centre of every coordinate, as points; rejected where ``x`` is."""
    return tuple(z.midpoint() if z.accepted() else ComplexIQ.refused() for z in x)


def _sum(terms) -> ComplexIQ:
    terms = iter(terms)
    total = next(terms)
    for term in terms:
        total = total.add(term)
    return total


def _matvec(a: Matrix, v: Vector) -> Vector:
    if any(len(row) != len(v) for row in a):
        raise ValueError("matrix and vector lengths differ")
    return tuple(_sum(e.mul(x) for e, x in zip(row, v)) for row in a)


def _matmul(a: Matrix, b: Matrix) -> Matrix:
    return tuple(tuple(_sum(row[k].mul(b[k][j]) for k in range(len(b))) for j in range(len(b[0]))) for row in a)


def _invert(points: Matrix, round_point: Round) -> Matrix:
    """``r(1/det)`` for ``n = 1``; ``r(r(1/det) * adj)`` with ``r = round_point`` for ``n = 2``."""
    n = len(points)
    if n == 1:
        det = points[0][0]
    else:
        (a, b), (c, d) = points
        det = a.mul(d).sub(b.mul(c))
    x, y = det.re.lo, det.im.lo
    quadrance = x * x + y * y
    if quadrance == 0:
        return _refused(n)
    inverse = ComplexIQ.singleton(round_point(x / quadrance), round_point(-y / quadrance))
    if n == 1:
        return ((inverse,),)
    adjugate = ((d, b.neg()), (c.neg(), a))
    return tuple(tuple(_point(inverse.mul(e), round_point) for e in row) for row in adjugate)


def _invertible_size(matrix: Matrix) -> int:
    n = _square(matrix)
    if n > 2:
        raise ValueError("the preconditioners are specified for one or two variables")
    return n


def exact_inverse(j: Matrix) -> Matrix:
    """The exact inverse of a matrix of points; refused for a non-point entry
    or a zero determinant (section 1.4)."""
    n = _invertible_size(j)
    if not all(_is_point(e) for row in j for e in row):
        return _refused(n)
    return _invert(j, _exact)


def midpoint_inverse(j: Matrix, round_point: Round = _exact) -> Matrix:
    """The inverse of the centre matrix of ``j``, each coordinate passed through
    ``round_point``; refused when an entry is rejected or the centre is singular."""
    n = _invertible_size(j)
    if not all(e.accepted() for row in j for e in row):
        return _refused(n)
    return _invert(tuple(tuple(e.midpoint() for e in row) for row in j), round_point)


def excludes_zero(values: Vector) -> bool:
    """The exclusion test on an enclosure of ``F(X)``: all accepted, and some
    coordinate misses ``0`` in its real or imaginary part."""
    return all(v.accepted() for v in values) and any(not v.contains_zero() for v in values)


def disjoint(a: Vector, b: Vector) -> bool:
    """Strict separation in some real coordinate; ``False`` on a rejection."""
    if len(a) != len(b):
        raise ValueError("boxes of different dimension")
    if not all(z.accepted() for z in (*a, *b)):
        return False
    return any(
        p.hi < q.lo or q.hi < p.lo
        for u, v in zip(a, b)
        for p, q in ((u.re, v.re), (u.im, v.im))
    )
