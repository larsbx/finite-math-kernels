# krawczyk.mojo
#
# The Krawczyk operator: R. Krawczyk, "Newton-Algorithmen zur Bestimmung von
# Nullstellen mit Fehlerschranken", Computing 4 (1969), 187-201.
#
# Specification: docs/root-isolation-spec.md, section 2, n = 1.
# Arithmetic: docs/rational-interval-arithmetic-spec.md, sections 2.3-2.4
# (enclosures over `closed_q`; the strict-inclusion hypothesis of 2.4).
#
#     K(X) = m - Y F(m) + (1 - Y F'(X)) (X - m),    m = centre(X)
#
# in exactly that association, over rectangular complex rational intervals.
# No rounding: `closed_q` never rounds, and the preconditioner is either the
# exact inverse of a point (`boxes.exact_inverse`) or a point the caller
# chose. The theorem that reads the operator (`krawczyk_moore`) allows any
# point preconditioner, so the choice affects whether a box passes, never
# whether a pass is sound.

from finite_exact.closed_interval import ComplexIQ
from finite_exact.rat_q import Q
from root_isolation.boxes import rejected_box


def krawczyk_image(x: ComplexIQ, m: ComplexIQ, y: ComplexIQ, f_m: ComplexIQ, d_x: ComplexIQ) -> ComplexIQ:
    """`m - Y F(m) + (1 - Y F'(X))(X - m)` from the enclosures given (spec 2).

    `f_m` must contain `F(m)` and `d_x` must contain `F'(x)` for every `x` in
    `X`; that is the caller's obligation and the one thing no check here can
    see. A rejected operand gives a rejected image.
    """
    if not (x.accepted() and m.accepted() and y.accepted() and f_m.accepted() and d_x.accepted()):
        return rejected_box()
    var one = ComplexIQ.singleton(Q(1, 1), Q.zero())
    var slope = one.sub(y.mul(d_x))
    return m.sub(y.mul(f_m)).add(slope.mul(x.sub(m)))
