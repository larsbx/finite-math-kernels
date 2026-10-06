"""The Krawczyk operator, in one or two complex variables.

R. Krawczyk, "Newton-Algorithmen zur Bestimmung von Nullstellen mit
Fehlerschranken", Computing 4 (1969), 187-201.

Specification: docs/root-isolation-spec.md, section 2. Nothing here
evaluates a map: the caller supplies an enclosure of ``F`` at the centre and
of the Jacobian over the box, and gets back

    K(X) = outward(m - C F(m) + (I - C J(X)) (X - m)),    m = centre(X),

in that association. Whether ``K(X)`` lies inside ``X`` is ``krawczyk_moore``.
"""

from __future__ import annotations

from typing import Callable

from closed_interval import ComplexIQ

from .boxes import ONE, ZERO, Matrix, Outward, Vector, _matmul, _matvec, _square, centre, exact_inverse


def krawczyk_image(x: Vector, m: Vector, c: Matrix, f_m: Vector, j_x: Matrix, outward: Outward | None = None) -> Vector:
    """``outward(m - C F(m) + (I - C J)(X - m))`` with the operands as given (section 2)."""
    n = len(x)
    if not (len(m) == len(f_m) == n and _square(c) == n and _square(j_x) == n):
        raise ValueError("box, centre, value and matrices must all have the same dimension")
    operands = (*x, *m, *f_m, *(e for row in (*c, *j_x) for e in row))
    if not all(z.accepted() for z in operands):
        return tuple(ComplexIQ.refused() for _ in range(n))
    slope = tuple(
        tuple((ONE if i == k else ZERO).sub(e) for k, e in enumerate(row)) for i, row in enumerate(_matmul(c, j_x))
    )
    shifted = tuple(xi.sub(mi) for xi, mi in zip(x, m))
    image = tuple(
        mi.sub(cf).add(correction)
        for mi, cf, correction in zip(m, _matvec(c, f_m), _matvec(slope, shifted))
    )
    return image if outward is None else tuple(outward(z) for z in image)


def krawczyk(
    x: Vector,
    at_centre: Callable[[Vector], tuple[Vector, Matrix]],
    over_box: Callable[[Vector], Matrix],
    invert: Callable[[Matrix], Matrix] = exact_inverse,
    outward: Outward | None = None,
) -> Vector:
    """``K(X)`` from evaluators: ``at_centre(m)`` encloses ``(F(m), J(m))`` and
    ``over_box(X)`` encloses the Jacobian on all of ``X``. ``invert`` builds the
    preconditioner from ``J(m)``; the exact inverse by default."""
    m = centre(x)
    if not all(z.accepted() for z in m):
        return tuple(ComplexIQ.refused() for _ in x)
    f_m, j_m = at_centre(m)
    return krawczyk_image(x, m, invert(j_m), f_m, over_box(x), outward)
