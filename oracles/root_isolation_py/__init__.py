"""Krawczyk root isolation on complex rational boxes, in pure Python (``root_isolation_py``).

Specification: docs/root-isolation-spec.md. The vendorable Python side of
``root_isolation``: one or two complex variables over ``closed_interval``
(``ComplexIQ``), exact unless the caller passes a rounding hook, fail-closed.
The Mojo kernel ``kernel/root_isolation`` is canonical for one variable, and
tests/root_isolation/test_krawczyk_twin.py compares the two on a transcript.

It must be vendored beside ``closed_interval``, which it imports by that name.
The ``_py`` suffix keeps it from sharing a name, and so a ``vendored.toml``
entry, with the Mojo package (as ``rational_dynamics_py``).

``boxes``
    generic helpers: ``centre``, the preconditioners ``exact_inverse`` and
    ``midpoint_inverse``, and the tests ``excludes_zero`` (exclusion) and
    ``disjoint``.
``krawczyk``
    the Krawczyk operator (Krawczyk 1969): ``krawczyk_image``, ``krawczyk``.
``krawczyk_moore``
    the Krawczyk-Moore test (Moore 1977): ``strictly_inside`` (isolation).

What is claimed: the image of section 2 is computed exactly as specified, and
each test decides exactly what section 3 says. What is not: that a passing
isolation test is a zero. That is the Krawczyk-Moore theorem (section 4), the
consumer's import to name and gate (``KrawczykMooreUniqueness``).
"""

from __future__ import annotations

from .boxes import Matrix, Vector, centre, disjoint, exact_inverse, excludes_zero, midpoint_inverse
from .krawczyk import krawczyk, krawczyk_image
from .krawczyk_moore import strictly_inside

__all__ = [
    "Matrix",
    "Vector",
    "centre",
    "disjoint",
    "exact_inverse",
    "excludes_zero",
    "krawczyk",
    "krawczyk_image",
    "midpoint_inverse",
    "strictly_inside",
]
