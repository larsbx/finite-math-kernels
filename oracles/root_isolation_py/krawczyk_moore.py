"""The Krawczyk-Moore existence and uniqueness test.

R. E. Moore, "A Test for Existence of Solutions to Nonlinear Systems", SIAM
Journal on Numerical Analysis 14 (1977), 611-615, for the operator of
R. Krawczyk, Computing 4 (1969), 187-201; with an arbitrary point
preconditioner, A. Neumaier, "Interval Methods for Systems of Equations",
Cambridge University Press (1990), chapter 5.

Specification: docs/root-isolation-spec.md, sections 3-4. ``strictly_inside``
decides the hypothesis -- ``K(X)`` in the interior of ``X`` in every real
coordinate -- and never states the conclusion (exactly one zero in ``X``,
simple). That theorem is the consumer's import (``KrawczykMooreUniqueness``).
"""

from __future__ import annotations

from .boxes import Vector


def strictly_inside(image: Vector, x: Vector) -> bool:
    """The isolation test: ``image`` in the interior of ``x`` in every real
    coordinate, both accepted (section 3). The hypothesis, not the conclusion."""
    if len(image) != len(x):
        raise ValueError("boxes of different dimension")
    return all(k.strict_subset_of(z) for k, z in zip(image, x))
