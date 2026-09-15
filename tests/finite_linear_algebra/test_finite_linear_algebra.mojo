"""Regressions for the finite_linear_algebra package.

Run with `pixi run test` (`mojo run -I . tests/test_finite_linear_algebra.mojo`).
The assertions are the general ones carried over from the PSC kernel test;
certificate-specific claims stay in that repository.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.rat_q import Q
from finite_linear_algebra.mat3 import Mat3, has_rational_root, identity3
from finite_linear_algebra.qlinalg import in_span, is_zero_vec, matvec, nullspace, rank
from finite_linear_algebra.scalar import q_int, q_is_zero, q_vec
from finite_linear_algebra.tensor3 import idx3, is_zero27, levi_civita, shuffle_image, shuffle_matrix, tensor_cube_apply, theta, zeros27
from finite_linear_algebra.w3 import in_w3, spans_same_space, w3_basis


def tribonacci() -> Mat3:
    var e: List[Int] = [1, 1, 1, 1, 0, 0, 0, 1, 0]
    return Mat3(e)


def test_scalar_lifts() raises:
    assert_true(q_int(-3).eq(Q(-3, 1)))
    assert_true(q_is_zero(Q(0, 7)))
    assert_false(q_is_zero(Q(1, 7)))
    var v: List[Int] = [1, -2, 3]
    var lifted = q_vec(v)
    assert_equal(len(lifted), 3)
    assert_true(lifted[1].eq(Q(-2, 1)))


def test_exact_nullspace_rank_and_span() raises:
    var m = List[List[Q]]()
    var r0: List[Int] = [1, 2, 3]
    var r1: List[Int] = [2, 4, 6]
    m.append(q_vec(r0))
    m.append(q_vec(r1))
    assert_equal(rank(m), 1)
    var kernel = nullspace(m, 3)
    assert_equal(len(kernel), 2)
    for k in range(len(kernel)):
        assert_true(is_zero_vec(matvec(m, kernel[k])))
    var v: List[Int] = [3, 6, 9]
    var w: List[Int] = [1, 0, 0]
    assert_true(in_span(m, q_vec(v)))
    assert_false(in_span(m, q_vec(w)))


def test_mat3_adjugate_and_charpoly() raises:
    var m = tribonacci()
    assert_true(m * m.adjugate() == identity3().scale(m.det()))
    assert_equal(m.det(), 1)
    var cp = m.charpoly()
    assert_equal(len(cp), 4)
    assert_equal(cp[0], -1)
    assert_equal(cp[1], -1)
    assert_equal(cp[2], -1)
    assert_equal(cp[3], 1)
    assert_false(has_rational_root(cp))
    # (1,1,1)^T is an eigenvector, so this characteristic cubic is reducible.
    var e: List[Int] = [1, 1, 0, 0, 1, 1, 1, 0, 1]
    assert_true(has_rational_root(Mat3(e).charpoly()))


def test_levi_civita_and_tensor_action() raises:
    assert_equal(levi_civita(0, 1, 2), 1)
    assert_equal(levi_civita(0, 2, 1), -1)
    assert_equal(levi_civita(1, 1, 2), 0)
    var x = zeros27()
    x[idx3(0, 1, 2)] = 1
    var same = tensor_cube_apply(identity3(), x)
    for i in range(27):
        assert_equal(same[i], x[i])
    assert_false(is_zero27(x))
    assert_true(is_zero27(zeros27()))
    # Theta(x)_{ij} = sum_{k,l} eps_{jkl} x_{ikl}: only row 0 of e_{012} survives.
    var t = theta(x)
    assert_equal(t.at(0, 0), 1)
    assert_equal(t.at(1, 1), 0)
    assert_equal(t.at(2, 2), 0)


def test_w3_is_eight_dimensional_and_invariant() raises:
    var basis = w3_basis()
    assert_equal(len(basis), 8)
    assert_equal(rank(shuffle_matrix()), 19)
    # W_3 is invariant under the cube action: check on an integer kernel vector.
    var b: List[Int] = zeros27()
    b[idx3(0, 0, 1)] = 1
    b[idx3(0, 1, 0)] = -2
    b[idx3(1, 0, 0)] = 1
    assert_true(in_w3(b))
    assert_true(in_w3(tensor_cube_apply(tribonacci(), b)))
    var family = List[List[Int]]()
    family.append(b.copy())
    assert_false(spans_same_space(family, basis))
    var image = shuffle_image(b)
    assert_true(is_zero27(image))


def main() raises:
    test_scalar_lifts()
    print("[PASS]", "test_scalar_lifts")
    test_exact_nullspace_rank_and_span()
    print("[PASS]", "test_exact_nullspace_rank_and_span")
    test_mat3_adjugate_and_charpoly()
    print("[PASS]", "test_mat3_adjugate_and_charpoly")
    test_levi_civita_and_tensor_action()
    print("[PASS]", "test_levi_civita_and_tensor_action")
    test_w3_is_eight_dimensional_and_invariant()
    print("[PASS]", "test_w3_is_eight_dimensional_and_invariant")
    print("5 finite_linear_algebra tests passed.")
