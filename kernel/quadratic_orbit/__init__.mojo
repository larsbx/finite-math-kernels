# quadratic_orbit: interval orbits of z -> z^2 + c, their escape and multiplier
# tests, and the collision patterns an orbit type imposes on them.
#
#   orbit       the seeded orbit over complex rational interval boxes:
#               a step, a term by index, the difference of two terms, and the
#               three-valued zero-exclusion test on a box.
#   escape_criterion  the escape criterion (Carleson-Gamelin 1993, Milnor
#               2006) as the bound `max(4, N(c))`, the strict test on a box,
#               and the rational growth certificate behind it.
#   multiplier_classification  the attracting / indifferent / repelling
#               classification of a multiplier box (Milnor 2006), with
#               UNDECIDED and REJECTED kept apart.
#   preperiodic exclusion and the Krawczyk hypothesis for preperiodic points.
#   collision   which index pairs an (ell, period) orbit type intends to
#               collide and which it forbids, and how many of each there are
#               below a horizon.
#
# Both planes of the quadratic family use the same orbit. The parameter plane
# iterates the critical orbit `z_0 = 0` over a parameter box `c`; the
# dynamical plane iterates a point over a fixed parameter. They differ in
# which argument varies, not in the recurrence, so the seed is an argument
# here rather than a constant.
#
# Nothing in this package raises, aborts, or decides certificate acceptance.
# A box is a conservative enclosure: unknown containment or sign is never
# promoted to equality or to acceptance, and what an accepted value is allowed
# to prove is the consumer's decision.

from .escape_criterion import (
    certificate_holds,
    escape_bound,
    escape_bound_quadrance,
    escapes,
    growth_form,
    next_quadrance_bound,
    quadrance_escapes,
    threshold_form,
)
from .multiplier_classification import (
    MULTIPLIER_ATTRACTING,
    MULTIPLIER_INDIFFERENT,
    MULTIPLIER_REJECTED,
    MULTIPLIER_REPELLING,
    MULTIPLIER_UNDECIDED,
    multiplier_regime,
)
