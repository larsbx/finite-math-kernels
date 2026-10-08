# root_isolation: Krawczyk root isolation on complex rational boxes.
#
# Specification: docs/root-isolation-spec.md.
#
#   boxes           the generic helpers: exact centre, exact inverse of a
#                   point, and the exclusion and disjointness tests.
#   krawczyk        the Krawczyk operator (Krawczyk 1969) in one complex
#                   variable over `finite_exact.closed_interval`.
#   krawczyk_moore  the Krawczyk-Moore test (Moore 1977): the image strictly
#                   inside the box, rejection kept apart from non-contraction.
#
# The package never evaluates a map: the caller supplies an enclosure of F at
# the centre and of F' over the box. The test returns the hypothesis of the
# Krawczyk-Moore theorem (specification section 4), never the conclusion;
# naming and gating that import is the consumer's decision. Nothing here
# raises or aborts: a refusal is a rejected value.
#
# The vendorable Python package `oracles/root_isolation_py` is the same
# specification in one or two variables, with the same module names;
# tests/root_isolation compares them.

from .boxes import centre, disjoint, exact_inverse, excludes_zero, is_point, rejected_box
from .krawczyk import krawczyk_image
from .krawczyk_moore import strictly_inside
