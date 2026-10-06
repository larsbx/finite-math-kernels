"""The Cauchy bound on the real roots of a polynomial over Q.

Every complex root `z` of `p = a_0 + ... + a_n x^n` with `a_n != 0` satisfies
`|z| < 1 + max_{k<n} |a_k| / |a_n|`. References: A.-L. Cauchy, *Exercices de
mathematiques* 4 (1829), "Sur la resolution des equations numeriques";
M. Mignotte, *Mathematics for Computer Algebra* (Springer, 1992), section 4.2;
specification: docs/exact-polynomial-root-isolation-spec.md.

`root_bound` was previously in `finite_linear_algebra/qpoly.mojo`, which still
re-exports it. What is claimed: the bound is the exact rational of the
formula. What is not: the inequality itself, Cauchy's theorem, which a
consumer that reads it as a root bound imports.
"""

from std.os import abort

from finite_exact.rat_q import Q, q_abs, q_max
from finite_linear_algebra.qpoly import degree, normalize


def root_bound(p: List[Q]) -> Q:
    """`1 + max |p[k]| / |lead|`, above every real root in magnitude."""
    var value = normalize(p)
    if degree(value) < 1:
        abort("a root bound needs degree at least one")
    var lead = q_abs(value[len(value) - 1])
    var largest = Q.zero()
    for k in range(len(value) - 1):
        largest = q_max(largest, q_abs(value[k]))
    return Q.one().add(largest.div(lead))
