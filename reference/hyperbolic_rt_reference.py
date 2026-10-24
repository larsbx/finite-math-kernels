"""Independent exact Python oracle for the hyperbolic RT conformance data.

Scalar modular arithmetic, not a port of the Mojo ExactField implementation.
No floating point, no randomness, no theorem promotion.
"""
from __future__ import annotations

def _coords(p: int, x: tuple[int, ...]) -> tuple[int, ...]:
    if not isinstance(p, int) or p < 3 or p % 2 == 0:
        raise ValueError("odd characteristic only")
    if len(x) != 8 or any(type(a) is not int for a in x):
        raise ValueError("eight integral coordinates required")
    return tuple(a % p for a in x)

def norm(p: int, x: tuple[int, ...]) -> int:
    x = _coords(p, x)
    # Gram matrix with unit off-diagonal (i,i+4)/(i+4,i).
    return sum(x[i] * x[i+4] + x[i+4] * x[i] for i in range(4)) % p

def polar(p: int, x: tuple[int, ...], y: tuple[int, ...]) -> int:
    x, y = _coords(p, x), _coords(p, y)
    return sum(x[i] * y[i+4] + x[i+4] * y[i] for i in range(4)) % p

def spread(p: int, x: tuple[int, ...], y: tuple[int, ...]) -> int | None:
    nx, ny = norm(p, x), norm(p, y)
    if not nx or not ny:
        return None
    denominator = (4 * nx * ny) % p
    if denominator == 0:
        return None
    return (1 - polar(p, x, y)**2 * pow(denominator, -1, p)) % p

def triple_defect(p: int, a: int, b: int, c: int) -> int:
    return ((a+b+c)**2 - 2*(a*a+b*b+c*c) - 4*a*b*c) % p
