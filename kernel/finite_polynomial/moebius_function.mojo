# moebius_function.mojo
#
# The Moebius function mu(n), exactly.
#
# mu(n) is 0 when a square greater than one divides n and (-1)^r when n is a
# product of r distinct primes. References: A. F. Moebius, "Ueber eine
# besondere Art von Umkehrung der Reihen", J. reine angew. Math. 9 (1832)
# 105-123; G. H. Hardy and E. M. Wright, *An Introduction to the Theory of
# Numbers* (1938; 6th ed., Oxford, 2008), section 16.3. The independent Python
# twin is the moebius_function module of oracles/rational_dynamics_py.
#
# The one Mojo implementation is `moebius` in rational_dynamics/moebius.mojo
# (rational_dynamics depends only on finite_exact, so this edge adds no cycle
# and no further package). This module re-exports it under both names:
# `mobius_mu` is the same function as `moebius`. Like it, `mobius_mu` refuses
# n < 1 (it raises); before the two were merged it returned 1 there.
#
# `mobius_mu` was previously in cyclotomic_field.mojo, which still re-exports it.

from rational_dynamics.moebius import moebius
from rational_dynamics.moebius import moebius as mobius_mu
