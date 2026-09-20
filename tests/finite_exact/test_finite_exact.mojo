"""Executable smoke and law checks for the finite_exact package.

Run with `pixi run test-finite-exact` (`mojo run -I . tests/finite_exact/test_finite_exact.mojo`).
The randomized property probe (`pixi run property`) is the stronger check;
this driver pins the documented examples and the field laws of
docs/rational-interval-arithmetic-spec.md section 1.3.
"""

from finite_exact.bigint_z import bigint_z_phase_one_smoke, bigint_z_phase_two_smoke, bigint_z_phase_three_smoke, bigz_long_division_smoke
from finite_exact.enclosure_width import enclosure_width_smoke
from finite_exact.rat_q import Q, bigq_storage_smoke, demo_q_normalization, demo_q_order, q_cancellation_smoke


def test_rational_field_laws() -> Bool:
    # docs/rational-interval-arithmetic-spec.md section 1.3: decidable
    # equality, associativity, distributivity, lossless cancellation.
    var a = Q(1, 3)
    var b = Q(1, 7)
    var c = Q(-2, 9)
    return (
        Q(1, 10).add(Q(2, 10)).eq(Q(3, 10)) and
        a.add(b).add(c).eq(a.add(b.add(c))) and
        a.mul(b.add(c)).eq(a.mul(b).add(a.mul(c))) and
        a.add(b).sub(b).eq(a) and
        Q(1, 3).lt(Q(1, 2))
    )


def test_rejection_is_explicit_and_sticky() -> Bool:
    # docs/exact-arithmetic-public-boundary.md section 2, item 4.
    var zero_den = Q(1, 0)
    var by_zero = Q(1, 2).div(Q.zero())
    return (
        zero_den.rejected and by_zero.rejected and
        zero_den.add(Q.one()).rejected and by_zero.mul(Q.one()).rejected and
        not zero_den.eq(zero_den) and not zero_den.lt(Q.one())
    )


def main() raises:
    if not bigint_z_phase_one_smoke() or not bigint_z_phase_two_smoke() or not bigint_z_phase_three_smoke():
        raise Error("BigZ smoke failed")
    if not bigz_long_division_smoke():
        raise Error("BigZ long division smoke failed")
    if not bigq_storage_smoke() or not q_cancellation_smoke() or not demo_q_normalization() or not demo_q_order():
        raise Error("Q smoke failed")
    if not test_rational_field_laws():
        raise Error("Q field laws failed")
    if not test_rejection_is_explicit_and_sticky():
        raise Error("Q rejection semantics failed")
    if not enclosure_width_smoke():
        raise Error("enclosure width bounds failed")
    print("finite_exact smoke and law checks passed.")
