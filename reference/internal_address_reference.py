#!/usr/bin/env python3
"""Reference model of the internal address of a periodic 0/1 kneading sequence.

Lau and Schleicher, *Internal addresses in the Mandelbrot set and
irreducibility of polynomials*, Stony Brook IMS Preprint 1994/19 (1994);
Bruin and Schleicher, *Symbolic dynamics of quadratic polynomials*, Institut
Mittag-Leffler Report 7 (2001/02), section 4. Specification:
docs/tuning-substitutions-spec.md, section 1.3. Independent oracle of
``kernel/substitution_dynamics/internal_address.mojo``; pure functions, no
repository policy, no theorem.
"""

from __future__ import annotations

from collections.abc import Sequence

Word = tuple[int, ...]


def internal_address(nu: Sequence[int]) -> Word:
    """``1 -> rho(1) -> rho(rho(1)) -> ...`` up to ``n = len(nu)``:
    ``rho(m) = min {k in (m, n] : nu_k != nu_(k-m)}`` (1-indexed), the entries of
    the internal address of the ``n``-periodic sequence ``nu nu nu ...`` that do
    not exceed its period. Boundary: a non-empty word over ``{0, 1}``."""
    p = tuple(nu)
    if not p:
        raise ValueError("a kneading word must be non-empty")
    if any(x not in (0, 1) for x in p):
        raise ValueError("kneading letters must lie in {0, 1}")
    address = [1]
    while (r := next((k for k in range(address[-1] + 1, len(p) + 1) if p[k - 1] != p[k - address[-1] - 1]), None)) is not None:
        address.append(r)
    return tuple(address)
