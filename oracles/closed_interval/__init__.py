"""Exact closed intervals and complex boxes in pure Python, with directed
dyadic rounding.

The vendorable Python twin of the Mojo ``finite_exact.closed_q`` layer
(``closed_interval`` is its stable facade name), for consumers that check
interval arithmetic without a Mojo toolchain (decision D1 of
docs/vendoring-candidates-2026-10-05.md). Standard library only
(``fractions``), exact, fail-closed: a rejected interval poisons every
operation it enters, a division whose domain meets zero is refused, and a
float is never accepted as an endpoint.

It is non-authoritative (``oracles/``): ``closed_q.mojo`` is canonical, and
tests/closed_interval/test_closed_q_twin.py compares the two on a shared
transcript.

Modules:

``interval``
    ``IQ``, ``ComplexIQ`` (also exported as ``ComplexBox``, the
    finite-julia-set-research name).
``dyadic``
    ``round_down``, ``round_up``, ``round_outward``, ``round_interval``,
    ``significant_bits``, ``scale_for``, ``DEFAULT_PRECISION``.

Ported from larsbx/finite-julia-set-research reference/interval_box.py and
reference/dyadic.py; those import as ``from closed_interval import
ComplexBox, IQ`` and ``from closed_interval import round_down, round_up,
DEFAULT_PRECISION``. The module docstrings list every behavioural
difference from those copies.
"""

from __future__ import annotations

from .dyadic import (
    DEFAULT_PRECISION,
    round_down,
    round_interval,
    round_outward,
    round_up,
    scale_for,
    significant_bits,
)
from .interval import IQ, ComplexBox, ComplexIQ, Scalar, exact

__all__ = [
    "DEFAULT_PRECISION",
    "ComplexBox",
    "ComplexIQ",
    "IQ",
    "Scalar",
    "exact",
    "round_down",
    "round_interval",
    "round_outward",
    "round_up",
    "scale_for",
    "significant_bits",
]
