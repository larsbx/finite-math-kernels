"""Compatibility alias: the arithmetic functions moved to their named modules
``moebius_function``, ``dedekind_sums`` and ``ramanujan_sums``; import from there.

``from rational_dynamics_py.arithmetic import ...`` keeps working and returns
the same function objects.
"""

from __future__ import annotations

from .dedekind_sums import dedekind_sum
from .moebius_function import moebius
from .ramanujan_sums import ramanujan_sum

__all__ = ["dedekind_sum", "moebius", "ramanujan_sum"]
