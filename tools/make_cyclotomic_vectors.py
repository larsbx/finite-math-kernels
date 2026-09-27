#!/usr/bin/env python3
"""Write the ``cyclotomic-germ-v1`` golden vectors from the C1-Q2 reference.

Usage:
    make_cyclotomic_vectors.py            rewrite fixtures/cyclotomic_germ_v1.json
    make_cyclotomic_vectors.py --check    exit 1 if the committed file has drifted

For every conductor q <= Q_MAX and every exponent p coprime to q, the vector
records lambda = zeta_q^p, the parabolic factor P of
w - g_lambda^q(w) = w^(q+1) P(w), and the coefficient [w^q] 1/P, each as exact
rational basis coordinates.  The coefficient is not named or interpreted here.
"""

from __future__ import annotations

import json
import sys
from math import gcd
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cyclotomic_reference import (  # noqa: E402
    canonical_bytes,
    cyclotomic_polynomial,
    parabolic_factor,
    reciprocal_series_coefficient,
    zeta_power,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "fixtures" / "cyclotomic_germ_v1.json"
Q_MAX = 8


def coords(a) -> list[str]:
    return [str(c) for c in a.coefficients]


def row(p: int, q: int) -> dict:
    factor = parabolic_factor(zeta_power(q, p), q)
    coefficient = reciprocal_series_coefficient(factor, q)
    return {
        "q": q,
        "p": p,
        "parabolic_factor_constant": coords(factor[0]),
        "reciprocal_coefficient": coords(coefficient),
        "reciprocal_coefficient_bytes": canonical_bytes(coefficient).hex(),
    }


def document() -> dict:
    exponents = lambda q: [1] if q == 1 else [p for p in range(1, q) if gcd(p, q) == 1]
    return {
        "schema": "cyclotomic-germ/v1",
        "generator": "tools/make_cyclotomic_vectors.py",
        "authority": "none",
        "basis": "coordinates on 1, zeta_q, ..., zeta_q^(phi(q)-1); zeta_q is the class of X in Q[X]/(Phi_q)",
        "germ": "g(w) = zeta_q^p w + w^2",
        "cyclotomic_polynomials": {str(q): list(cyclotomic_polynomial(q)) for q in range(1, Q_MAX + 1)},
        "vectors": [row(p, q) for q in range(1, Q_MAX + 1) for p in exponents(q)],
    }


def render() -> str:
    return json.dumps(document(), indent=2) + "\n"


def main(argv: list[str]) -> int:
    text = render()
    if "--check" in argv:
        if OUT.read_text() != text:
            print(f"{OUT.relative_to(ROOT)} has drifted; rerun tools/make_cyclotomic_vectors.py", file=sys.stderr)
            return 1
        return 0
    OUT.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
