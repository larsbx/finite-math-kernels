"""Regressions for `dumont_thomas`, `barge_class` and `balanced_pair_algorithm`.

The three-letter fixtures (Tribonacci, `0 -> 1, 1 -> 021, 2 -> 001`, the
catch-up-free `0 -> 1, 1 -> 22, 2 -> 012`, the plastic substitution) carry the
expected values the PSC research kernel
(`larsbx/pisot-substitution-conjecture-research`, `kernel/tests/test_automata.mojo`,
`kernel/tests/test_barge_class.mojo`, `kernel/tests/test_boundary_sync.mojo`) pins
on its alphabet-3 views, so the generic modules reproduce them exactly. The
two- and four-letter cases check what is new: the numeration against the
fixed point and the incidence matrix on the Fibonacci and a four-letter
Arnoux-Rauzy-type substitution, Barge membership past three letters, and the
bounded builder on two letters. Run with `pixi run test-substitution`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_add, bigz_eq, bigz_from_i64, bigz_zero
from substitution_dynamics.automaton import Automaton, build
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
from substitution_dynamics.balanced_pair_algorithm import (
    BUDGET_LENGTH,
    BUDGET_NONE,
    BUDGET_STATES,
    BoundedAutomaton,
    bounded_children,
    build_bounded,
)
from substitution_dynamics.balanced_pairs import children, normalise, seed_states
from substitution_dynamics.dumont_thomas import (
    _covering_table,
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
from substitution_dynamics.words import Pair


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
    # Fixed points: each letter at its first return only, never again at a
    # multiple of its period.
    var both_fixed = prolongable_points(sub([[0, 1], [1, 0]]))
    assert_equal(len(both_fixed), 2)
    for i in range(2):
        assert_equal(both_fixed[i].power, 1)
        assert_equal(both_fixed[i].letter, i)
    var trib = prolongable_points(tribonacci())
    assert_equal(len(trib), 1)
    assert_equal(trib[0].power, 1)
    assert_equal(trib[0].letter, 0)
    var mixed = prolongable_points(sub([[0], [2, 1], [1, 2]]))  # 0 fixed, 1 <-> 2
    assert_equal(len(mixed), 3)
    assert_equal(mixed[0].power, 1)
    assert_equal(mixed[0].letter, 0)
    assert_equal(mixed[1].power, 2)
    assert_equal(mixed[1].letter, 1)
    assert_equal(mixed[2].power, 2)
    assert_equal(mixed[2].letter, 2)
    var refused = False
    try:
        _ = tribonacci().power(0)
    except:
        refused = True
    assert_true(refused)


def refuses_letter_at(tau: Substitution, letter: Int, position: Int) -> Bool:
    try:
        _ = letter_at(tau, letter, position)
    except:
        return True
    return False


def test_a_slowly_growing_fixed_point_is_read_past_any_fixed_level() raises:
    # `0 -> 01, 1 -> 1`: |tau^k(0)| = k + 1, so position n needs level n.
    var tau = sub([[0, 1], [1]])
    assert_equal(levels_to_cover(tau, 0, 65), 65)
    assert_equal(len(digits(tau, 0, 65)), 65)
    assert_equal(letter_at(tau, 0, 0), 0)
    for n in range(1, 200):
        assert_equal(letter_at(tau, 0, n), 1)
    # A letter whose images stop growing has no position past them: refused,
    # at once, never a wrong digit and never a loop.
    var fixed = sub([[0], [1, 2], [2]])  # 0 stays one letter; 1 grows linearly
    assert_true(refuses_letter_at(fixed, 0, 1))
    assert_equal(letter_at(fixed, 1, 500), 2)
    var bounded = sub([[1], [2, 2], [2]])  # |tau^k(0)| = 1, 1, 2, 2, ...
    assert_equal(letter_at(bounded, 0, 1), 2)
    assert_true(refuses_letter_at(bounded, 0, 2))


def test_an_unrelated_letter_cannot_overflow_a_query() raises:
    # Letter 2 doubles and never occurs in the fixed point at 0, whose
    # prefix grows by one letter per level: past level 63 its length would
    # leave the machine range, which must not refuse a position at 0.
    var tau = sub([[0, 1], [1], [2, 2]])
    assert_equal(levels_to_cover(tau, 0, 100), 100)
    assert_equal(len(digits(tau, 0, 100)), 100)
    assert_equal(letter_at(tau, 0, 100), 1)
    assert_equal(letter_at(tau, 0, 0), 0)


def table_levels(tau: Substitution, letter: Int, position: Int) -> Int:
    """The level of the table `digits` uses, or `-1` where it is refused."""
    try:
        return len(_covering_table(tau, letter, position)) - 1
    except:
        return -1


def streamed_levels(tau: Substitution, letter: Int, position: Int) -> Int:
    """`levels_to_cover`, or `-1` where it is refused."""
    try:
        return levels_to_cover(tau, letter, position)
    except:
        return -1


def substituted_levels(tau: Substitution, letter: Int, position: Int, limit: Int) -> Int:
    """The least `k <= limit` with `position < |tau^k(letter)|`, by
    substituting the word itself; `-1` when no such level exists."""
    var w: List[Int] = [letter]
    for k in range(limit + 1):
        if position < len(w):
            return k
        w = tau.apply(w)
    return -1


def test_levels_to_cover_is_the_level_of_the_digits_table() raises:
    # Pisot, non-primitive, power-prolongable, disconnected (letter 2 never
    # below 0 yet doubling) and stopped images (refusals) alike: the streamed
    # count and the table `digits` builds name the same level, and the same
    # refusal, at every position and every start letter.
    var cases: List[Substitution] = [
        tribonacci(),
        fibonacci(),
        four_letter(),
        prolongable_form(tau_sigma()),
        sub([[0, 1], [1]]),
        sub([[0, 1], [1], [2, 2]]),
        sub([[0], [1, 2], [2]]),
        sub([[1], [2, 2], [2]]),
        sub([[0, 1, 1], [1, 0]]),
        sub([[0, 1, 2, 2], [2, 0], [1, 1, 0]]),
        sub([[1, 0], [2], [3], [0, 1]]),
    ]
    var refusals = 0
    for c in range(len(cases)):
        ref tau = cases[c]
        for letter in range(tau.size):
            for n in range(130):
                var streamed = streamed_levels(tau, letter, n)
                assert_equal(streamed, table_levels(tau, letter, n))
                if streamed < 0:
                    refusals += 1
                    assert_equal(substituted_levels(tau, letter, n, tau.size + 2), -1)
                    continue
                assert_equal(len(digits(tau, letter, n)), streamed)
                if streamed <= 12:
                    assert_equal(substituted_levels(tau, letter, n, 12), streamed)
    assert_true(refusals > 0)
    # Past the machine range of the unrelated letter 2 (it doubles), still in
    # agreement on the slowly growing component.
    var disconnected = sub([[0, 1], [1], [2, 2]])
    for n in [64, 100, 1000]:
        assert_equal(levels_to_cover(disconnected, 0, n), n)
        assert_equal(table_levels(disconnected, 0, n), n)


def test_levels_to_cover_streams_over_a_large_alphabet() raises:
    # `0 -> 01, 1 -> 1` beside 2^17 - 2 inert letters `a -> a`: position N
    # needs N levels. The streamed count keeps two vectors and advances only
    # the descendants of 0, so it costs O(N + |A|). A table of every level
    # would hold N * |A| = 10^6 * 2^17 machine integers (about a petabyte):
    # it cannot pass this, however long it is given.
    var size = 1 << 17
    var images = List[List[Int]]()
    images.append([0, 1])
    images.append([1])
    for a in range(2, size):
        images.append([a])
    var tau = sub(images)
    var n = 1000000
    assert_equal(levels_to_cover(tau, 0, n), n)
    assert_equal(levels_to_cover(tau, 0, 0), 0)
    # An inert letter's image stops growing at once: refused, not looped on.
    assert_equal(streamed_levels(tau, 5, 1), -1)
    assert_equal(levels_to_cover(tau, 5, 0), 0)


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


def materialising_build_bounded(sigma: Substitution, max_states: Int, max_length: Int) -> BoundedAutomaton:
    """The builder as it was before bounded inflation: every child of an
    admitted state is materialised in full and queued, and only compared
    with `max_length` when it is dequeued. The reference for equivalence."""
    var states = List[Pair]()
    var index = Dict[String, Int]()
    var queue = List[Pair]()
    var exhausted = BUDGET_NONE
    var longest = 0
    var seeds = seed_states(sigma.size)
    for i in range(len(seeds)):
        queue.append(normalise(seeds[i]))
    var head = 0
    while head < len(queue) and exhausted == BUDGET_NONE:
        var state = queue[head].copy()
        head += 1
        var key = state.key()
        if key in index:
            continue
        if len(states) >= max_states:
            exhausted = BUDGET_STATES
            break
        if state.length() > max_length:
            exhausted = BUDGET_LENGTH
            break
        if state.length() > longest:
            longest = state.length()
        index[key] = len(states)
        states.append(state.copy())
        if state.is_coincidence():
            continue
        var cs = children(sigma, state)
        for i in range(len(cs)):
            queue.append(cs[i].copy())
    var adj = List[List[Int]]()
    for _ in range(len(states)):
        adj.append(List[Int]())
    return BoundedAutomaton(Automaton(states, adj, exhausted != BUDGET_NONE, sigma.size), exhausted, longest)


def growing_cases() raises -> List[Substitution]:
    """Pisot cases plus substitutions whose balanced pairs grow without bound."""
    return [
        tribonacci(),
        fibonacci(),
        four_letter(),
        tau_sigma(),
        sub([[0, 1, 1], [1, 0]]),
        sub([[0, 0, 1], [1, 1, 0, 0]]),
        sub([[0, 1, 2, 2], [2, 0], [1, 1, 0]]),
    ]


def test_bounded_children_is_the_in_budget_prefix_of_children() raises:
    var cases = growing_cases()
    for c in range(len(cases)):
        ref sigma = cases[c]
        var reach = materialising_build_bounded(sigma, 60, 40)
        for s in range(len(reach.graph.states)):
            ref p = reach.graph.states[s]
            if p.is_coincidence():
                continue
            var full = children(sigma, p)
            for max_length in range(1, 50):
                var got = bounded_children(sigma, p, max_length)
                var expected = List[Pair]()
                var over = False
                for i in range(len(full)):
                    if full[i].length() > max_length:
                        over = True
                        break
                    expected.append(full[i].copy())
                assert_equal(got.over_budget, over)
                assert_equal(len(got.children), len(expected))
                for i in range(len(expected)):
                    assert_equal(got.children[i].key(), expected[i].key())


def test_bounded_builder_agrees_with_the_materialising_one() raises:
    var cases = growing_cases()
    for c in range(len(cases)):
        for max_states in [1, 2, 3, 5, 8, 13, 40, 400]:
            for max_length in [1, 2, 3, 4, 5, 7, 10, 16, 30, 400]:
                var got = build_bounded(cases[c], max_states, max_length)
                var want = materialising_build_bounded(cases[c], max_states, max_length)
                assert_equal(got.exhausted, want.exhausted)
                assert_equal(got.longest_state, want.longest_state)
                assert_equal(got.graph.capped, want.graph.capped)
                assert_equal(got.graph.size(), want.graph.size())
                for i in range(want.graph.size()):
                    assert_equal(got.graph.states[i].key(), want.graph.states[i].key())


def test_an_over_budget_child_is_never_materialised() raises:
    # sigma(0) = 0^N, sigma(1) = 1^N: the seed (01, 10) inflates to the single
    # irreducible block (0^N 1^N, 1^N 0^N) of length 2N. With max_length = 2 the
    # bounded inflation reads max_length + 1 letters per side and stops; it
    # never builds the 2N-letter child.
    var n = 1 << 21
    var zeros = List[Int](length=n, fill=0)
    var ones = List[Int](length=n, fill=1)
    var sigma = sub([zeros^, ones^])
    var seed = normalise(seed_states(2)[0])
    var cs = bounded_children(sigma, seed, 2)
    assert_true(cs.over_budget)
    assert_equal(len(cs.children), 0)
    assert_equal(cs.letters_read, 3)
    var bounded = build_bounded(sigma, 100, 2)
    assert_equal(bounded.exhausted, BUDGET_LENGTH)
    assert_true(bounded.graph.capped)
    assert_equal(bounded.graph.size(), 1)
    assert_equal(bounded.longest_state, 2)
    # Same answer when the state budget is the one that is already spent.
    assert_equal(build_bounded(sigma, 1, 2).exhausted, BUDGET_STATES)


def main() raises:
    test_the_numeration_automaton_is_the_fixed_point()
    print("[PASS] test_the_numeration_automaton_is_the_fixed_point")
    test_counts_are_image_lengths_and_incidence_entries()
    print("[PASS] test_counts_are_image_lengths_and_incidence_entries")
    test_prolongable_points_are_the_first_letter_cycles()
    print("[PASS] test_prolongable_points_are_the_first_letter_cycles")
    test_a_slowly_growing_fixed_point_is_read_past_any_fixed_level()
    print("[PASS] test_a_slowly_growing_fixed_point_is_read_past_any_fixed_level")
    test_an_unrelated_letter_cannot_overflow_a_query()
    print("[PASS] test_an_unrelated_letter_cannot_overflow_a_query")
    test_levels_to_cover_is_the_level_of_the_digits_table()
    print("[PASS] test_levels_to_cover_is_the_level_of_the_digits_table")
    test_levels_to_cover_streams_over_a_large_alphabet()
    print("[PASS] test_levels_to_cover_streams_over_a_large_alphabet")
    test_impossible_queries_are_refused()
    print("[PASS] test_impossible_queries_are_refused")
    test_barge_class_alphabet3_fixtures()
    print("[PASS] test_barge_class_alphabet3_fixtures")
    test_barge_class_other_alphabets()
    print("[PASS] test_barge_class_other_alphabets")
    test_bounded_builder_matches_the_canonical_one()
    print("[PASS] test_bounded_builder_matches_the_canonical_one")
    test_bounded_children_is_the_in_budget_prefix_of_children()
    print("[PASS] test_bounded_children_is_the_in_budget_prefix_of_children")
    test_bounded_builder_agrees_with_the_materialising_one()
    print("[PASS] test_bounded_builder_agrees_with_the_materialising_one")
    test_an_over_budget_child_is_never_materialised()
    print("[PASS] test_an_over_budget_child_is_never_materialised")
    print("14 numeration, Barge-class and bounded-builder Mojo tests passed.")
