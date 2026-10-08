"""Primitivity of non-negative integer matrices by Wielandt's bound.

Run with `pixi run test-integer-matrix`.

Wielandt's matrix is the extremal case: it is primitive and needs exactly the
bound, so a loop that stopped one power short would call it imprimitive.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_linear_algebra.integer_matrix import is_nonnegative, is_positive, is_primitive, matmul, wielandt_bound


def wielandt(n: Int) -> List[Int]:
    """The cycle 0 -> 1 -> ... -> n-1 -> 0 plus the chord n-1 -> 1."""
    var m = List[Int](length=n * n, fill=0)
    for i in range(n - 1):
        m[i * n + i + 1] = 1
    m[(n - 1) * n + 0] = 1
    m[(n - 1) * n + 1] = 1
    return m^


def first_positive_power(m: List[Int], n: Int) raises -> Int:
    var p = m.copy()
    for k in range(1, wielandt_bound(n) + 1):
        if is_positive(p):
            return k
        p = matmul(p, m, n)
    return -1


def test_the_bound_is_attained_and_sufficient() raises:
    for n in range(2, 6):
        assert_equal(wielandt_bound(n), n * n - 2 * n + 2)
        var m = wielandt(n)
        assert_true(is_primitive(m, n))
        assert_equal(first_positive_power(m, n), wielandt_bound(n))


def test_irreducible_but_periodic_is_not_primitive() raises:
    var swap: List[Int] = [0, 1, 1, 0]
    assert_false(is_primitive(swap, 2))
    var fibonacci: List[Int] = [1, 1, 1, 0]
    assert_true(is_primitive(fibonacci, 2))
    var tribonacci: List[Int] = [1, 1, 1, 1, 0, 0, 0, 1, 0]
    assert_true(is_primitive(tribonacci, 3))


def test_sign_predicates() raises:
    var m: List[Int] = [1, 0, 2, 3]
    assert_true(is_nonnegative(m))
    assert_false(is_positive(m))
    var n: List[Int] = [1, -1, 2, 3]
    assert_false(is_nonnegative(n))
    var product = matmul(m, m, 2)
    var expected: List[Int] = [1, 0, 8, 9]
    for i in range(4):
        assert_equal(product[i], expected[i])


def test_matrix_products_refuse_overflow() raises:
    var product_refused = False
    var accumulation_refused = False
    var large: List[Int] = [3037000500, 1, 1, 0]
    try:
        _ = matmul(large, large, 2)
    except:
        product_refused = True
    var a: List[Int] = [Int.MAX, 1, 0, 0]
    var b: List[Int] = [1, 0, 1, 0]
    try:
        _ = matmul(a, b, 2)
    except:
        accumulation_refused = True
    assert_true(product_refused)
    assert_true(accumulation_refused)
    var identity: List[Int] = [1, 0, 0, 1]
    var minima: List[Int] = [Int.MIN, 0, 0, 1]
    assert_equal(matmul(identity, minima, 2)[0], Int.MIN)


def test_primitivity_depends_only_on_support() raises:
    var large: List[Int] = [3037000500, 1, 1, 0]
    assert_true(is_primitive(large, 2))
    var periodic: List[Int] = [0, Int.MAX, Int.MAX, 0]
    assert_false(is_primitive(periodic, 2))
    var reducible: List[Int] = [Int.MAX, 0, 0, Int.MAX]
    assert_false(is_primitive(reducible, 2))


def main() raises:
    test_the_bound_is_attained_and_sufficient()
    print("[PASS] test_the_bound_is_attained_and_sufficient")
    test_irreducible_but_periodic_is_not_primitive()
    print("[PASS] test_irreducible_but_periodic_is_not_primitive")
    test_sign_predicates()
    print("[PASS] test_sign_predicates")
    test_matrix_products_refuse_overflow()
    print("[PASS] test_matrix_products_refuse_overflow")
    test_primitivity_depends_only_on_support()
    print("[PASS] test_primitivity_depends_only_on_support")
    print("5 integer_matrix tests passed.")
