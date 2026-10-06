"""Regressions for `substitution_dynamics.return_lattice`.

The Tribonacci and `|det M| = 2` fixtures (`0 -> 22, 1 -> 20, 2 -> 221`) carry
the expected values the PSC research kernel
(`larsbx/pisot-substitution-conjecture-research`,
`kernel/tests/test_return_lattice.mojo`) pins on its alphabet-3 view. Off
three letters the exact Rauzy-graph route is checked against the sampled
route, which shares no step with it, on Fibonacci, period doubling and a
four-letter substitution; on Thue-Morse, whose incidence matrix is singular,
the lattice drops rank and both routes must raise rather than report index
zero. Run with
`pixi run test-substitution`.
"""

from std.testing import assert_equal, assert_raises, assert_true

from substitution_dynamics.return_lattice import (
    TriangularLattice,
    covering_level,
    factor_set,
    max_factor_length,
    return_index_profile,
    return_lattice,
    sampled_return_index,
    verify_index_profile,
)
from substitution_dynamics.substitution import Substitution


def tribonacci() raises -> Substitution:
    return Substitution.checked([[0, 1], [0, 2], [0]])


def det_two() raises -> Substitution:
    return Substitution.checked([[2, 2], [2, 0], [2, 2, 1]])


def test_hermite_form_index() raises:
    var lattice = TriangularLattice(3)
    lattice.insert([4, 0, 0])
    lattice.insert([6, 3, 0])
    assert_equal(lattice.rank(), 2)
    with assert_raises():
        _ = lattice.index()
    lattice.insert([0, 5, 1])
    assert_equal(lattice.index(), 12)
    lattice.insert([2, 0, 0])
    assert_equal(lattice.index(), 6)
    with assert_raises():
        lattice.insert([1, 2])
    var plane = TriangularLattice(2)
    plane.insert([2, 1])
    plane.insert([0, 3])
    assert_equal(plane.index(), 6)


def test_alphabet3_fixtures() raises:
    assert_equal(max_factor_length(3), 39)
    for n in range(1, 11):
        assert_equal(len(factor_set(tribonacci(), n)), 2 * n + 1)
    var unimodular = return_index_profile(tribonacci(), 12)
    for n in range(12):
        assert_equal(unimodular[n], 1)
    var expected: List[Int] = [1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4]
    var profile = return_index_profile(det_two(), 13)
    assert_equal(profile, expected)
    for n in range(1, 9):
        assert_equal(sampled_return_index(tribonacci(), n, 20000), unimodular[n - 1])
        assert_equal(sampled_return_index(det_two(), n, 20000), profile[n - 1])
    assert_equal(return_lattice(det_two(), 4).index(), 2)
    assert_equal(covering_level(tribonacci(), 1), 0)
    assert_equal(covering_level(tribonacci(), 2), 2)
    verify_index_profile(det_two(), 2, profile)
    verify_index_profile(tribonacci(), 1, unimodular)
    with assert_raises():
        verify_index_profile(det_two(), 2, [1, 2, 1])
    with assert_raises():
        verify_index_profile(tribonacci(), 1, [1, 2])
    with assert_raises():
        _ = factor_set(tribonacci(), 40)


def test_other_alphabets_agree_with_the_sampled_route() raises:
    var cases: List[Substitution] = [
        Substitution.checked([[0, 1], [0]]),
        Substitution.checked([[0, 1], [0, 0]]),
        Substitution.checked([[0, 1], [0, 2], [0, 3], [0]]),
    ]
    var dets: List[Int] = [1, 2, 1]
    for c in range(len(cases)):
        var profile = return_index_profile(cases[c], 8)
        for n in range(1, 9):
            assert_equal(sampled_return_index(cases[c], n, 20000), profile[n - 1])
        verify_index_profile(cases[c], dets[c], profile)
    # Fibonacci is Sturmian: n + 1 factors of length n, and unimodular.
    for n in range(1, 11):
        assert_equal(len(factor_set(cases[0], n)), n + 1)
    assert_equal(return_index_profile(cases[0], 6), [1, 1, 1, 1, 1, 1])
    assert_equal(max_factor_length(2), 62)
    assert_equal(max_factor_length(4), 31)


def test_a_rank_drop_raises_on_both_routes() raises:
    """Thue-Morse has a singular incidence matrix. Its letter returns span
    `Z^2`, but from some order on every return of a patch carries as many
    zeros as ones, the lattice drops rank, and both routes must raise rather
    than report an index of zero -- never one route answering and the other
    refusing."""
    var thue_morse = Substitution.checked([[0, 1], [1, 0]])
    var dropped = 0
    for n in range(1, 7):
        var exact = -1
        var sampled = -1
        try:
            exact = return_lattice(thue_morse, n).index()
        except:
            dropped += 1
        try:
            sampled = sampled_return_index(thue_morse, n, 20000)
        except:
            pass
        assert_equal(exact, sampled)
    assert_equal(return_lattice(thue_morse, 1).index(), 1)
    assert_true(dropped > 0)


def main() raises:
    test_hermite_form_index()
    print("[PASS] test_hermite_form_index")
    test_alphabet3_fixtures()
    print("[PASS] test_alphabet3_fixtures")
    test_other_alphabets_agree_with_the_sampled_route()
    print("[PASS] test_other_alphabets_agree_with_the_sampled_route")
    test_a_rank_drop_raises_on_both_routes()
    print("[PASS] test_a_rank_drop_raises_on_both_routes")
    print("4 return-lattice Mojo tests passed.")
