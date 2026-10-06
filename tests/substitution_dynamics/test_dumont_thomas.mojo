"""Regressions for `dumont_thomas`, `barge_class` and `balanced_pair_algorithm`.

The three-letter fixtures (Tribonacci, `0 -> 1, 1 -> 021, 2 -> 001`, the
catch-up-free `0 -> 1, 1 -> 22, 2 -> 012`, the plastic substitution) carry the
expected values the PSC research kernel
(`larsbx/pisot-substitution-conjecture-research`, `kernel/tests/
test_automata.mojo`, `test_barge_class.mojo`, `test_boundary_sync.mojo`) pins
on its alphabet-3 views, so the generic modules reproduce them exactly. The
two- and four-letter cases check what is new: the numeration against the
fixed point and the incidence matrix on the Fibonacci and a four-letter
Arnoux-Rauzy-type substitution, Barge membership past three letters, and the
bounded builder on two letters. Run with `pixi run test-substitution`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_add, bigz_eq, bigz_from_i64, bigz_zero
from substitution_dynamics.automaton import build
from substitution_dynamics.barge_class import (
    KIND_DIRECT,
    KIND_LEFT_ROTATION,
    KIND_NONE,
    barge_witness,
    common_prefix_length,
    common_suffix_length,
    in_barge_class,
    in_mirror_class,
    rotate_left,
    rotate_right,
)
from substitution_dynamics.balanced_pair_algorithm import BUDGET_LENGTH, BUDGET_NONE, BUDGET_STATES, build_bounded
from substitution_dynamics.dumont_thomas import (
    digits,
    image_lengths,
    letter_at,
    letter_automaton,
    letter_of_digits,
    levels_to_cover,
    max_image_length,
    numeration_automaton,
    occurrences_of_length,
    positions_of_length,
    prolongable_form,
    prolongable_point,
    prolongable_points,
)
from substitution_dynamics.substitution import Substitution


def sub(images: List[List[Int]]) raises -> Substitution:
    return Substitution.checked(images)


def tribonacci() raises -> Substitution:
    return sub([[0, 1], [0, 2], [0]])


def tau_sigma() raises -> Substitution:
    """`0 -> 1, 1 -> 021, 2 -> 001`: prolongable only at a power."""
    return sub([[1], [0, 2, 1], [0, 0, 1]])


def fibonacci() raises -> Substitution:
    return sub([[0, 1], [0]])


def four_letter() raises -> Substitution:
    return sub([[0, 1], [0, 2], [0, 3], [0]])


def fixed_point_prefix(sigma: Substitution, power: Int, letter: Int, length: Int) -> List[Int]:
    """By substituting, independently of the numeration."""
    var u: List[Int] = [letter]
    while len(u) < length:
        u = sigma.apply_n(u, power)
    return u^


def counts(value: Int) raises -> BigZ:
    return bigz_from_i64(Int64(value))


def incidence_power_column(sigma: Substitution, k: Int, column: Int) -> List[Int]:
    """Column `column` of `M^k`, by integer matrix-vector products."""
    var m = sigma.incidence()
    var v = List[Int](length=sigma.size, fill=0)
    v[column] = 1
    for _ in range(k):
        var w = List[Int](length=sigma.size, fill=0)
        for i in range(sigma.size):
            for j in range(sigma.size):
                w[i] += m[i * sigma.size + j] * v[j]
        v = w^
    return v^


def test_the_numeration_automaton_is_the_fixed_point() raises:
    var cases: List[Substitution] = [tribonacci(), tau_sigma(), fibonacci(), four_letter()]
    for c in range(len(cases)):
        ref sigma = cases[c]
        var point = prolongable_point(sigma)
        var tau = prolongable_form(sigma)
        assert_equal(tau.images[point.letter][0], point.letter)
        var u = fixed_point_prefix(sigma, point.power, point.letter, 600)
        for n in range(500):
            assert_equal(letter_at(tau, point.letter, n), u[n])
        for n in range(60):
            var path = digits(tau, point.letter, n)
            assert_equal(letter_of_digits(tau, point.letter, path), u[n])
            assert_equal(len(path), levels_to_cover(tau, point.letter, n))


def test_counts_are_image_lengths_and_incidence_entries() raises:
    var trib = tribonacci()
    var point = prolongable_point(trib)
    var tau = prolongable_form(trib)
    var expected: List[Int] = [1, 2, 4, 7, 13, 24, 44, 81]
    for k in range(len(expected)):
        assert_equal(image_lengths(tau, k)[point.letter], expected[k])
        assert_true(bigz_eq(positions_of_length(tau, point.letter, k), counts(expected[k])))
    var cases: List[Substitution] = [tribonacci(), tau_sigma(), fibonacci(), four_letter()]
    for c in range(len(cases)):
        var p = prolongable_point(cases[c])
        var t = prolongable_form(cases[c])
        for k in range(6):
            var column = incidence_power_column(t, k, p.letter)
            var total = bigz_zero()
            for target in range(t.size):
                var counted = occurrences_of_length(t, p.letter, target, k)
                assert_true(bigz_eq(counted, counts(column[target])))
                total = bigz_add(total, counted)
            assert_true(bigz_eq(total, positions_of_length(t, p.letter, k)))


def test_prolongable_points_are_the_first_letter_cycles() raises:
    var point = prolongable_point(tau_sigma())
    assert_true(point.power > 1)
    var tau = prolongable_form(tau_sigma())
    assert_equal(len(tau.images[point.letter]), len(tau_sigma().power(point.power).images[point.letter]))
    assert_true(max_image_length(tau) >= max_image_length(tau_sigma()))
    # A 4-cycle of first letters: every letter prolongable at the fourth power only.
    var cycle = sub([[1, 0], [2], [3], [0, 1]])
    var points = prolongable_points(cycle)
    assert_equal(len(points), 4)
    for i in range(4):
        assert_equal(points[i].power, 4)
        assert_equal(points[i].letter, i)
    var refused = False
    try:
        _ = tribonacci().power(0)
    except:
        refused = True
    assert_true(refused)


def test_impossible_queries_are_refused() raises:
    var tau = tribonacci()
    var flags: List[Bool] = [False, False, False, False, False]
    try:
        _ = positions_of_length(tau, 0, -1)
    except:
        flags[0] = True
    try:
        _ = image_lengths(tau, -1)
    except:
        flags[1] = True
    try:
        _ = numeration_automaton(tau, -1)
    except:
        flags[2] = True
    try:
        _ = letter_automaton(tau, 3, 0)
    except:
        flags[3] = True
    try:
        _ = letter_of_digits(tau, 2, [1])
    except:
        flags[4] = True
    for i in range(len(flags)):
        assert_true(flags[i])


def test_barge_class_alphabet3_fixtures() raises:
    var w = barge_witness(tribonacci(), 6)
    assert_equal(w.power, 1)
    assert_equal(w.kind, KIND_DIRECT)
    assert_true(w.mirror)

    var free = sub([[1], [2, 2], [0, 1, 2]])
    assert_true(in_barge_class(free.power(2)))
    var square = barge_witness(free, 6)
    assert_equal(square.power, 2)
    assert_equal(square.kind, KIND_DIRECT)
    assert_false(square.mirror)

    var t = sub([[0, 0], [0, 1, 0], [0, 2, 0]])
    assert_false(in_barge_class(t) or in_mirror_class(t))
    assert_equal(common_prefix_length(t), 1)
    var r = rotate_left(t, 1)
    assert_true(in_barge_class(r))
    assert_equal(r.images[1][0], 1)
    var back = rotate_right(r, 1)
    for a in range(3):
        assert_true(back.images[a] == t.images[a])
    assert_equal(barge_witness(t, 1).kind, KIND_LEFT_ROTATION)

    assert_false(barge_witness(sub([[1], [2], [0, 1]]), 6).found())


def test_barge_class_other_alphabets() raises:
    # Fibonacci 0 -> 01, 1 -> 0 is constant on initial letters and injective
    # on final ones: the mirror class at the first power.
    var w = barge_witness(fibonacci(), 3)
    assert_equal(w.kind, KIND_DIRECT)
    assert_true(w.mirror)
    # The four-letter analogue likewise.
    assert_true(in_mirror_class(four_letter()))
    # Constant on both ends over four letters; the left rotation by the common
    # prefix 0 separates the initial letters.
    var t = sub([[0, 0], [0, 1, 0], [0, 2, 0], [0, 3, 0]])
    assert_equal(common_prefix_length(t), 1)
    assert_equal(common_suffix_length(t), 1)
    assert_true(in_barge_class(rotate_left(t, 1)))
    assert_equal(barge_witness(t, 1).kind, KIND_LEFT_ROTATION)
    # Thue-Morse is injective on both ends at every power, and no rotation
    # applies: no witness.
    assert_equal(barge_witness(sub([[0, 1], [1, 0]]), 4).kind, KIND_NONE)
    # Sharing the first letter 0, the left rotation (110, 010) is in the class.
    assert_equal(barge_witness(sub([[0, 1, 1], [0, 0, 1]]), 1).kind, KIND_LEFT_ROTATION)


def test_bounded_builder_matches_the_canonical_one() raises:
    var cases: List[Substitution] = [tribonacci(), fibonacci(), four_letter()]
    for c in range(len(cases)):
        var canonical = build(cases[c], 20000)
        var bounded = build_bounded(cases[c], 20000, 20000)
        assert_true(bounded.complete())
        assert_equal(bounded.exhausted, BUDGET_NONE)
        assert_equal(bounded.graph.size(), canonical.size())
        for i in range(canonical.size()):
            assert_equal(bounded.graph.states[i].key(), canonical.states[i].key())
            assert_equal(bounded.graph.adj[i], canonical.adj[i])
        assert_true(bounded.longest_state >= 1)
    var few = build_bounded(tribonacci(), 1, 20000)
    assert_false(few.complete())
    assert_equal(few.exhausted, BUDGET_STATES)
    assert_true(few.graph.capped)
    var short = build_bounded(tribonacci(), 20000, 1)
    assert_equal(short.exhausted, BUDGET_LENGTH)
    assert_true(short.graph.capped)
    var refused = False
    try:
        _ = build_bounded(tribonacci(), 0, 1)
    except:
        refused = True
    assert_true(refused)


def main() raises:
    test_the_numeration_automaton_is_the_fixed_point()
    print("[PASS] test_the_numeration_automaton_is_the_fixed_point")
    test_counts_are_image_lengths_and_incidence_entries()
    print("[PASS] test_counts_are_image_lengths_and_incidence_entries")
    test_prolongable_points_are_the_first_letter_cycles()
    print("[PASS] test_prolongable_points_are_the_first_letter_cycles")
    test_impossible_queries_are_refused()
    print("[PASS] test_impossible_queries_are_refused")
    test_barge_class_alphabet3_fixtures()
    print("[PASS] test_barge_class_alphabet3_fixtures")
    test_barge_class_other_alphabets()
    print("[PASS] test_barge_class_other_alphabets")
    test_bounded_builder_matches_the_canonical_one()
    print("[PASS] test_bounded_builder_matches_the_canonical_one")
    print("7 numeration, Barge-class and bounded-builder Mojo tests passed.")
