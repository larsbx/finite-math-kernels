"""Consumer-style test of the stable public facades.

Run with `pixi run test-facades`. This file imports only the entry points
the README advertises as stable (`rational`, `closed_interval`, `matrix`,
`matrix3`, `rational_elimination`), never the implementation modules behind
them, and exercises every name each facade exports. A broken re-export
therefore fails here even when the implementation-module tests pass.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult, IQSignResult, bigq_interval_conformance_smoke, demo_complex_quadrance_point, demo_interval_mul
from finite_exact.rational import Q, QCanonicalBytes, bigq_storage_smoke, demo_q_normalization, demo_q_order, q_cancellation_smoke, q_canonical_bytes, q_from_bigz, q_max, q_min, q_rejected
from finite_linear_algebra.matrix import in_span, is_zero_vec, matvec, nullspace, q_int, q_is_zero, q_vec, rank, rref
from finite_linear_algebra.matrix3 import Mat3, has_rational_root, identity3
from finite_linear_algebra.rational_elimination import in_span as elim_in_span, is_zero_vec as elim_is_zero_vec, matvec as elim_matvec, nullspace as elim_nullspace, rank as elim_rank, rref as elim_rref


def test_rational_facade() raises:
    var third = Q(1, 3)
    assert_true(third.add(Q(1, 6)).eq(Q(1, 2)))
    assert_true(q_min(third, Q(1, 2)).eq(third))
    assert_true(q_max(third, Q(1, 2)).eq(Q(1, 2)))
    assert_true(q_rejected().rejected)
    # The facade exports no BigZ constructor; a consumer reaches BigZ values
    # through the parts of an accepted Q.
    assert_true(q_from_bigz(Q(6, 1).num, Q(4, 1).num).eq(Q(3, 2)))
    assert_true(q_from_bigz(Q(1, 1).num, Q.zero().num).rejected)
    var encoded: QCanonicalBytes = q_canonical_bytes(Q(1, 2))
    assert_true(encoded.accepted())
    assert_equal(len(encoded.bytes), 20)
    assert_true(q_canonical_bytes(q_rejected()).rejected)
    assert_true(bigq_storage_smoke())
    assert_true(demo_q_normalization())
    assert_true(demo_q_order())
    assert_true(q_cancellation_smoke())


def test_closed_interval_facade() raises:
    var box = IQ(Q(1, 2), Q(3, 2))
    var contains: IQBoolResult = box.contains_zero()
    assert_false(contains.value)
    assert_false(contains.rejected)
    var sign: IQSignResult = box.sign()
    assert_equal(sign.code, 1)
    assert_false(sign.rejected)
    var doubled = box.mul(IQ.singleton(Q(2, 1)))
    assert_true(doubled.lo.eq(Q(1, 1)))
    assert_true(doubled.hi.eq(Q(3, 1)))
    assert_true(IQ.singleton(Q(1, 1)).subset_of(box).value)
    assert_true(IQ(Q(2, 1), Q(1, 1)).rejected)
    var z = ComplexIQ.singleton(Q(3, 1), Q(4, 1))
    assert_true(z.quadrance().lo.eq(Q(25, 1)))
    assert_true(z.accepted())
    assert_true(bigq_interval_conformance_smoke())
    assert_true(demo_complex_quadrance_point())
    assert_true(demo_interval_mul())


def dependent_rows() -> List[List[Q]]:
    var m = List[List[Q]]()
    var r0: List[Int] = [1, 2, 3]
    var r1: List[Int] = [2, 4, 6]
    m.append(q_vec(r0))
    m.append(q_vec(r1))
    return m^


def test_matrix_facade() raises:
    assert_true(q_int(-3).eq(Q(-3, 1)))
    assert_true(q_is_zero(Q(0, 7)))
    assert_false(q_is_zero(Q(1, 7)))
    var m = dependent_rows()
    assert_equal(rank(m), 1)
    var reduced = rref(m)
    assert_equal(len(reduced[1]), 1)
    assert_equal(reduced[1][0], 0)
    assert_true(reduced[0][0][0].eq(Q.one()))
    var kernel = nullspace(m, 3)
    assert_equal(len(kernel), 2)
    for k in range(len(kernel)):
        assert_true(is_zero_vec(matvec(m, kernel[k])))
    var inside: List[Int] = [3, 6, 9]
    var outside: List[Int] = [1, 0, 0]
    assert_true(in_span(m, q_vec(inside)))
    assert_false(in_span(m, q_vec(outside)))


def test_rational_elimination_facade_agrees_with_matrix() raises:
    var m = dependent_rows()
    assert_equal(elim_rank(m), rank(m))
    assert_equal(len(elim_rref(m)[1]), len(rref(m)[1]))
    var kernel = elim_nullspace(m, 3)
    assert_equal(len(kernel), len(nullspace(m, 3)))
    for k in range(len(kernel)):
        assert_true(elim_is_zero_vec(elim_matvec(m, kernel[k])))
    var inside: List[Int] = [3, 6, 9]
    assert_true(elim_in_span(m, q_vec(inside)))


def test_matrix3_facade() raises:
    var e: List[Int] = [1, 1, 1, 1, 0, 0, 0, 1, 0]
    var tribonacci = Mat3(e)
    assert_equal(tribonacci.det(), 1)
    assert_true(tribonacci * tribonacci.adjugate() == identity3().scale(tribonacci.det()))
    assert_equal(identity3().trace(), 3)
    var cp = tribonacci.charpoly()
    assert_equal(cp[0], -1)
    assert_equal(cp[3], 1)
    assert_false(has_rational_root(cp))
    var with_zero_root: List[Int] = [0, 1, 1, 1]
    assert_true(has_rational_root(with_zero_root))


def main() raises:
    test_rational_facade()
    test_closed_interval_facade()
    test_matrix_facade()
    test_rational_elimination_facade_agrees_with_matrix()
    test_matrix3_facade()
    print("stable facade checks passed.")
