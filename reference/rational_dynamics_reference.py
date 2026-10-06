"""Independent Python reference for rational_dynamics R1.

The definitions live in the vendorable Python package
``oracles/rational_dynamics_py/`` (module ``farey``); this module re-exports
them under the import path the R1 tests and
``schemas/rational-dynamics-cyclotomic-v1.json`` name, so there is one
definition and no copy to drift.
"""

from __future__ import annotations

import sys
from pathlib import Path

_ORACLES = str(Path(__file__).resolve().parents[1] / "oracles")
if _ORACLES not in sys.path:
    sys.path.insert(0, _ORACLES)

from rational_dynamics_py.farey import (  # noqa: E402
    Address,
    address,
    continued_fraction,
    convergents,
    double_mod_one,
    farey_adjacent,
    farey_determinant,
    mod_inverse,
    signed_mod_inverse,
)

__all__ = [
    "Address",
    "address",
    "continued_fraction",
    "convergents",
    "double_mod_one",
    "farey_adjacent",
    "farey_determinant",
    "mod_inverse",
    "signed_mod_inverse",
]
