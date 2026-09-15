"""Executable smoke and law checks for the interval_q package.

Run with `pixi run smoke` (`mojo run -I . tests/test_interval_q.mojo`).
The randomized property probe (`pixi run property`) is the stronger check;
this driver pins the documented examples and the enclosure laws of
larsbx/finite_exact:docs/rational-interval-arithmetic-spec.md sections 2.2 to 2.5.
"""

from finite_exact.rat_q import Q
from interval_q.closed_q import IQ, ComplexIQ, bigq_interval_conformance_smoke, demo_complex_quadrance_point, demo_interval_mul


def test_interval_enclosure_laws() -> Bool:
    # Spec sections 2.2 to 2.5: the dependency problem, subdistributivity,
    # and the tighter square.
    var x = IQ(Q(1, 1), Q(3, 1))
    var y = IQ(Q(-1, 1), Q(2, 1))
    var z = IQ(Q(2, 1), Q(5, 1))
    var d = x.sub(x)
    var lhs = x.mul(y.add(z))
    var rhs = x.mul(y).add(x.mul(z))
    return (
        d.lo.eq(Q(-2, 1)) and d.hi.eq(Q(2, 1)) and d.contains_zero().value and
        lhs.subset_of(rhs).value and
        y.square().subset_of(y.mul(y)).value and not y.mul(y).subset_of(y.square()).value and
        x.excludes_zero().value and not y.excludes_zero().value
    )


def test_three_valued_sign_and_fail_closed_reciprocal() -> Bool:
    # Spec section 2.4 and public boundary items 3 and 4: a zero-containing
    # interval has sign 0 (unknown) and no reciprocal; reversed endpoints and
    # rejected endpoints reject and stay rejected.
    var positive = IQ(Q(1, 2), Q(3, 1))
    var negative = IQ(Q(-3, 1), Q(-1, 2))
    var straddling = IQ(Q(-1, 1), Q(1, 1))
    var reversed = IQ(Q(2, 1), Q(1, 1))
    var poisoned = IQ(Q(1, 0), Q(1, 1))
    return (
        positive.sign().code == 1 and negative.sign().code == -1 and straddling.sign().code == 0 and
        not straddling.sign().rejected and
        straddling.reciprocal().rejected and not positive.reciprocal().rejected and
        positive.reciprocal().lo.eq(Q(1, 3)) and positive.reciprocal().hi.eq(Q(2, 1)) and
        reversed.rejected and poisoned.rejected and reversed.add(positive).rejected and
        reversed.sign().rejected and reversed.contains_zero().rejected and
        IQ.singleton(Q(5, 7)).lo.eq(IQ.singleton(Q(5, 7)).hi) and
        ComplexIQ.singleton(Q.one(), Q.zero()).quadrance().lo.eq(Q.one())
    )


def main() raises:
    if not bigq_interval_conformance_smoke() or not demo_interval_mul() or not demo_complex_quadrance_point():
        raise Error("IQ smoke failed")
    if not test_interval_enclosure_laws():
        raise Error("IQ enclosure laws failed")
    if not test_three_valued_sign_and_fail_closed_reciprocal():
        raise Error("IQ sign and rejection semantics failed")
    print("interval_q smoke and law checks passed.")
