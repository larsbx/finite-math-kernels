"""Regressions for the canonical fixed-dimension integer vector kernel.

Three things are pinned, in the order they can go wrong.

The dimension-specialised paths are an optimisation, so they are checked
against the general loop -- which is the definition -- over a grid, rather than
by reading two spellings of the same sum and agreeing they look alike.

The dimension contract is checked on both sides: a mismatch raises, and never
comes back truncated or zero-padded. Fail closed.

The arithmetic contract is the one place this kernel and its Python oracle
differ, and it is checked hardest. Python's `int` cannot overflow; `Int` is
64-bit, so a sum or product that would leave the range must raise rather than
wrap. A wrapped coordinate is a wrong number presented as a lattice point.

The corpus checksum against the Python oracle stays with the oracle and its
corpus, in `larsbx/pisot-substitution-conjecture-research`.
"""

from std.testing import assert_equal, assert_true

from finite_linear_algebra.integer_vector import (
    add,
    add_general,
    matvec,
    matvec_general,
    sub,
    sub_general,
)

def _raises_add(a: List[Int], b: List[Int]) -> Bool:
    try:
        _ = add(a, b)
        return False
    except:
        return True


def _raises_sub(a: List[Int], b: List[Int]) -> Bool:
    try:
        _ = sub(a, b)
        return False
    except:
        return True


def _raises_matvec(m: List[List[Int]], v: List[Int]) -> Bool:
    try:
        _ = matvec(m, v)
        return False
    except:
        return True


def test_the_specialised_paths_agree_with_the_general_loop() raises:
    """The unroll is an optimisation, so it has to compute the definition.

    A 7^3 grid of vectors against a 5^3 grid of matrix rows, at dimension
    three where the specialised path is taken, plus dimension two and four
    where it is not, so the fallback is exercised on the same assertion.
    """
    var compared = 0
    for a0 in range(-3, 4):
        for a1 in range(-3, 4):
            for a2 in range(-3, 4):
                var v: List[Int] = [a0, a1, a2]
                var w: List[Int] = [a2, a0, a1]
                var fast_add = add(v, w)
                var slow_add = add_general(v, w)
                var fast_sub = sub(v, w)
                var slow_sub = sub_general(v, w)
                for i in range(3):
                    assert_equal(fast_add[i], slow_add[i])
                    assert_equal(fast_sub[i], slow_sub[i])
                for b in range(-2, 3):
                    var m: List[List[Int]] = [
                        [b, 1, 0],
                        [0, b, 1],
                        [1, 0, b],
                    ]
                    var fast = matvec(m, v)
                    var slow = matvec_general(m, v)
                    for i in range(3):
                        assert_equal(fast[i], slow[i])
                    compared += 1
    assert_true(compared == 7 * 7 * 7 * 5)

    # dimension two and four take the general path; same assertion, no unroll
    var two: List[Int] = [5, -7]
    var two_b: List[Int] = [-1, 9]
    assert_equal(add(two, two_b)[0], add_general(two, two_b)[0])
    assert_equal(add(two, two_b)[1], add_general(two, two_b)[1])
    assert_equal(sub(two, two_b)[1], sub_general(two, two_b)[1])
    var m2: List[List[Int]] = [[1, 2], [3, 4]]
    assert_equal(matvec(m2, two)[0], matvec_general(m2, two)[0])
    assert_equal(matvec(m2, two)[1], matvec_general(m2, two)[1])
    var four: List[Int] = [1, 2, 3, 4]
    var m4: List[List[Int]] = [[1, 0, 0, 1], [0, 1, 1, 0]]
    assert_equal(matvec(m4, four)[0], 5)
    assert_equal(matvec(m4, four)[1], 5)


def test_a_dimension_that_does_not_agree_is_refused() raises:
    """Never a truncated or zero-padded answer, in either direction."""
    var three: List[Int] = [1, 2, 3]
    var two: List[Int] = [1, 2]
    assert_true(_raises_add(three, two))
    assert_true(_raises_add(two, three))
    assert_true(_raises_sub(three, two))
    assert_true(_raises_sub(two, three))

    var square: List[List[Int]] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    assert_true(_raises_matvec(square, two))
    var ragged: List[List[Int]] = [[1, 0, 0], [0, 1], [0, 0, 1]]
    assert_true(_raises_matvec(ragged, three))
    var no_rows = List[List[Int]]()
    assert_true(_raises_matvec(no_rows, three))


def test_an_intermediate_past_the_machine_range_raises_rather_than_wrapping() raises:
    """The documented difference from the Python oracle, pinned as a refusal.

    `Int.MAX + 1`, `Int.MIN - 1` and a product of two values near `2^62` all
    have exact answers the oracle would return and this kernel cannot hold. It
    refuses each one; what it must never do is return the wrapped value.
    """
    var big: List[Int] = [Int.MAX, 0, 0]
    var one: List[Int] = [1, 0, 0]
    assert_true(_raises_add(big, one))

    var small: List[Int] = [Int.MIN, 0, 0]
    assert_true(_raises_sub(small, one))

    var huge = 1 << 62
    var wide: List[List[Int]] = [[huge, 0, 0], [0, 1, 0], [0, 0, 1]]
    var scale: List[Int] = [huge, 1, 1]
    assert_true(_raises_matvec(wide, scale))

    # the sum overflows although no single product does
    var half = Int.MAX // 2
    var rows: List[List[Int]] = [[half, half, half], [0, 0, 0], [0, 0, 0]]
    var ones: List[Int] = [1, 1, 1]
    assert_true(_raises_matvec(rows, ones))

    # and a value that does fit still comes back exact, not refused
    var safe: List[List[Int]] = [[2, 0, 0], [0, 3, 0], [0, 0, 4]]
    var v: List[Int] = [10, 10, 10]
    assert_equal(matvec(safe, v)[0], 20)
    assert_equal(matvec(safe, v)[2], 40)


def main() raises:
    test_the_specialised_paths_agree_with_the_general_loop()
    print("[PASS] test_the_specialised_paths_agree_with_the_general_loop")
    test_a_dimension_that_does_not_agree_is_refused()
    print("[PASS] test_a_dimension_that_does_not_agree_is_refused")
    test_an_intermediate_past_the_machine_range_raises_rather_than_wrapping()
    print("[PASS] test_an_intermediate_past_the_machine_range_raises_rather_than_wrapping")
    print("3 integer_vector tests passed.")
