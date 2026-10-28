"""Independent exact reference for split 8D Gram and exterior invariants.

Uses elementary integer modular arithmetic and coordinate determinants,
not the Mojo implementation or its ExactField abstraction. The finite
dataset is conformance evidence, NOT proof of a field-generic theorem.
"""
from __future__ import annotations

from itertools import combinations


def _vec(p: int, x: tuple[int, ...]) -> tuple[int, ...]:
    if p not in (3, 5, 7) or len(x) != 8 or any(type(a) is not int for a in x):
        raise ValueError("finite reference corpus domain: p in 3,5,7, dimension 8")
    return tuple(a % p for a in x)


def norm(p: int, x: tuple[int, ...]) -> int:
    x = _vec(p, x)
    return 2 * sum(x[i] * x[i + 4] for i in range(4)) % p


def gram(p: int, x: tuple[int, ...], y: tuple[int, ...]) -> int:
    x, y = _vec(p, x), _vec(p, y)
    return sum(x[i] * y[i + 4] + x[i + 4] * y[i] for i in range(4)) % p


def gram2(p: int, x: tuple[int, ...], y: tuple[int, ...]) -> int:
    return (norm(p, x) * norm(p, y) - gram(p, x, y) ** 2) % p


def det3(m: tuple[tuple[int, int, int], ...]) -> int:
    a, b, c = m
    return (a[0] * (b[1]*c[2]-b[2]*c[1])
            - a[1] * (b[0]*c[2]-b[2]*c[0])
            + a[2] * (b[0]*c[1]-b[1]*c[0]))


def gram3(p: int, x: tuple[int, ...], y: tuple[int, ...], z: tuple[int, ...]) -> int:
    rows = tuple(tuple(gram(p, a, b) for b in (x, y, z)) for a in (x, y, z))
    return det3(rows) % p


def rank_le_two(p: int, x: tuple[int, ...], y: tuple[int, ...], z: tuple[int, ...]) -> bool:
    x, y, z = (_vec(p, v) for v in (x, y, z))
    return all(det3(tuple((x[i], y[i], z[i]) for i in ix)) % p == 0
               for ix in combinations(range(8), 3))


def normalized_gram3(p: int, x: tuple[int, ...], y: tuple[int, ...], z: tuple[int, ...]) -> int | None:
    ns = [norm(p, t) for t in (x, y, z)]
    if 0 in ns:
        return None
    n = ns[0] * ns[1] * ns[2] % p
    return gram3(p, x, y, z) * pow(n, -1, p) % p


def spread(p: int, x: tuple[int, ...], y: tuple[int, ...]) -> int | None:
    nx, ny = norm(p, x), norm(p, y)
    if 0 in (nx, ny):
        return None
    t = (nx * ny) % p
    return (1 - gram(p, x, y)**2 * pow(t, -1, p)) % p


def planar_defect(p: int, x: tuple[int, ...], y: tuple[int, ...], z: tuple[int, ...]) -> int | None:
    if not rank_le_two(p, x, y, z):
        return None
    ss = (spread(p, x, y), spread(p, y, z), spread(p, z, x))
    if any(v is None for v in ss):
        return None
    a,b,c = ss
    return ((a+b+c)**2 - 2*(a*a+b*b+c*c) - 4*a*b*c) % p



def unrestricted_defect(p: int, x: tuple[int, ...],
                        y: tuple[int, ...], z: tuple[int, ...]) -> int | None:
    """Triple-spread defect WITHOUT the planar rank guard."""
    ss = (spread(p, x, y), spread(p, y, z), spread(p, z, x))
    if any(s is None for s in ss):
        return None
    a, b, c = ss
    return ((a+b+c)**2 - 2*(a*a+b*b+c*c) - 4*a*b*c) % p


def gram_predicted_defect(p: int, x: tuple[int, ...],
                          y: tuple[int, ...], z: tuple[int, ...]) -> int | None:
    """Independent Gram-side expression, not the spread expansion."""
    a, b, c = norm(p, x), norm(p, y), norm(p, z)
    if a == 0 or b == 0 or c == 0:
        return None
    u, v, w = gram(p, x, y), gram(p, y, z), gram(p, z, x)
    d = gram3(p, x, y, z)
    product = a*b*c % p
    return (d * (4*u*v*w-d) * pow(product*product % p, -1, p)) % p
