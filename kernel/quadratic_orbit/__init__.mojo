# quadratic_orbit: interval orbits of z -> z^2 + c, and the collision patterns
# an orbit type imposes on them.
#
#   orbit       the seeded orbit over complex rational interval boxes:
#               a step, a term by index, the difference of two terms, and the
#               three-valued zero-exclusion test on a box.
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
