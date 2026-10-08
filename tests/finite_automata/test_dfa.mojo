"""Regressions for the finite_automata kernel.

The kernel is the engine a decision procedure over a numeration system needs,
so what is pinned here is its algebra: complement is exact because transitions
are total, intersection and union are the synchronous product, projection is
the subset construction that discharges one existential quantifier, and
minimisation identifies exactly the automata with one language. Counts of
accepted words are BigZ, so a count past the machine range is still exact.

The Dumont-Thomas numeration tests that drive this kernel through a
substitution stay with that numeration, in
`larsbx/pisot-substitution-conjecture-research`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_add, bigz_eq, bigz_from_i64, bigz_mul, bigz_zero
from finite_automata.dfa import (
    Dfa,
    accepted_count,
    complement,
    cylinder,
    intersection,
    is_empty,
    minimised,
    project,
    same_language,
    union,
    widened,
    with_sink,
    witness,
)

def counts(value: Int) raises -> BigZ:
    """The exact count a test expects, as the unbounded integer it is."""
    return bigz_from_i64(Int64(value))


def even_ones() raises -> Dfa:
    """An even number of ones over `{0, 1}`."""
    var delta: List[Int] = [0, 1, 1, 0]
    var accepting: List[Bool] = [True, False]
    return Dfa(2, delta, accepting)


def test_the_kernel_is_a_boolean_algebra_of_languages() raises:
    var even = even_ones()
    var odd = complement(even)
    var one: List[Int] = [1]
    var two: List[Int] = [1, 1]
    assert_true(even.accepts(two))
    assert_false(even.accepts(one))
    assert_true(odd.accepts(one))
    # Total transitions make complement exact: no word is accepted by both, and
    # every word by one.
    assert_true(is_empty(intersection(even, odd)))
    assert_true(is_empty(complement(union(even, odd))))
    # 2^(n-1) words of each parity at length n > 0.
    assert_true(bigz_eq(accepted_count(even, 3), counts(4)))
    assert_true(bigz_eq(accepted_count(odd, 3), counts(4)))
    assert_true(bigz_eq(accepted_count(even, 0), counts(1)))
    # The shortest witness of an even count of ones is the empty word.
    assert_equal(len(witness(even).word), 0)
    assert_equal(len(witness(odd).word), 1)


def test_emptiness_reports_the_instance_not_only_the_verdict() raises:
    # A language with one word: 1 0 1. Its witness must be that word.
    # 0 start, 1 read 1, 2 read 10, 3 read 101 and accepting, 4 the sink.
    var delta: List[Int] = [4, 1, 2, 4, 4, 3, 4, 4, 4, 4]
    var accepting: List[Bool] = [False, False, False, True, False]
    var only = Dfa(2, delta, accepting)
    var found = witness(only)
    assert_false(found.empty)
    assert_equal(len(found.word), 3)
    assert_equal(found.word[0], 1)
    assert_equal(found.word[1], 0)
    assert_equal(found.word[2], 1)
    assert_true(only.accepts(found.word))
    # An automaton accepting nothing says so, and hands back no word.
    var nothing = complement(union(only, complement(only)))
    assert_true(is_empty(nothing))
    assert_equal(len(witness(nothing).word), 0)


def test_projection_discharges_one_existential_quantifier() raises:
    """Two tracks over `{0, 1}`, letters packed as `x + 2 y`.

    The language is `y = 1` on every letter. Projecting the `y` track must give
    every word over `x`, since some `y` always completes one; projecting the `x`
    track instead must give exactly the words with `y = 1` throughout, which is
    a smaller language. A projection that ignored which track it drops would
    return the same automaton twice."""
    var delta = List[Int]()
    var accepting: List[Bool] = [True, False]
    for state in range(2):
        for letter in range(4):
            var y = letter // 2
            delta.append(0 if (state == 0 and y == 1) else 1)
    var both = Dfa(4, delta, accepting)
    var over_x: List[Int] = [0, 1]
    var over_y = project(both, 2, 1)          # drop y: anything over x
    var over_second = project(both, 2, 0)     # drop x: keeps y = 1
    assert_equal(over_y.letters, 2)
    assert_true(over_y.accepts(over_x))
    var ones: List[Int] = [1, 1]
    var zeros: List[Int] = [0, 0]
    assert_true(over_second.accepts(ones))
    assert_false(over_second.accepts(zeros))
    assert_false(same_language(over_y, over_second))


def test_minimisation_identifies_exactly_equal_languages() raises:
    var even = even_ones()
    # The same language with a duplicated state and an unreachable one.
    var delta: List[Int] = [2, 1, 1, 0, 0, 1, 3, 3]
    var accepting: List[Bool] = [True, False, True, False]
    var redundant = Dfa(2, delta, accepting)
    assert_true(same_language(even, redundant))
    assert_equal(minimised(redundant).states(), 2)
    assert_equal(minimised(even).states(), 2)
    # Minimisation is idempotent and language-preserving.
    assert_true(same_language(minimised(redundant), redundant))
    assert_equal(minimised(minimised(redundant)).states(), 2)
    # A different language is not identified with it.
    assert_false(same_language(even, complement(even)))


def test_a_partial_table_is_completed_by_one_rejecting_sink() raises:
    var partial: List[Int] = [0, -1]
    var accepting: List[Bool] = [True]
    var completed = with_sink(2, partial, accepting)
    assert_equal(completed.states(), 2)
    var zeros: List[Int] = [0, 0]
    var one: List[Int] = [1]
    assert_true(completed.accepts(zeros))
    assert_false(completed.accepts(one))
    # The sink absorbs: once inadmissible, always inadmissible.
    var back: List[Int] = [1, 0]
    assert_false(completed.accepts(back))


def one_marked_coincidence() raises -> Dfa:
    """Three tracks over `{0, 1}`, a letter packed as `x + 2y + 4z`.

    The language: the `z` track carries exactly one `1`, and it stands at a
    position where `x` and `y` are both `1`. So `z` marks a witness, and the
    marking is only legal where the witness holds.

    States: `0` no mark yet, `1` one legal mark seen, `2` a rejecting sink for
    a second mark or an illegal one.
    """
    var delta = List[Int]()
    var accepting: List[Bool] = [False, True, False]
    for state in range(3):
        for letter in range(8):
            var x = letter % 2
            var y = (letter // 2) % 2
            var z = letter // 4
            var next = 2
            if state == 0:
                next = 0 if z == 0 else (1 if (x == 1 and y == 1) else 2)
            elif state == 1:
                next = 1 if z == 0 else 2
            delta.append(next)
    return Dfa(8, delta, accepting)


def contains_letter(letters: Int, target: Int) raises -> Dfa:
    """Words over `letters` containing `target` at least once."""
    var delta = List[Int]()
    var accepting: List[Bool] = [False, True]
    for state in range(2):
        for letter in range(letters):
            delta.append(1 if (state == 1 or letter == target) else 0)
    return Dfa(letters, delta, accepting)


def packed(xs: List[Int], ys: List[Int], zs: List[Int]) -> List[Int]:
    var out = List[Int]()
    for i in range(len(xs)):
        out.append(xs[i] + 2 * ys[i] + 4 * zs[i])
    return out^


def test_projection_over_three_tracks_eliminates_a_real_quantifier() raises:
    """The marked-witness language, where the quantified track must be guessed.

    Existentially quantifying `z` asks: is there a legal place to put the one
    mark? That is `exists i : x_i = y_i = 1`, and no deterministic reading of
    `(x, y)` alone knows at position `i` whether a later position will do
    instead. The subset construction is what resolves it, and this is the case
    that distinguishes a real projection from dropping a coordinate.
    """
    var marked = one_marked_coincidence()
    var xs: List[Int] = [1, 0, 1]
    var ys: List[Int] = [0, 0, 1]
    var legal: List[Int] = [0, 0, 1]
    var illegal: List[Int] = [1, 0, 0]
    var twice: List[Int] = [0, 0, 0]
    assert_true(marked.accepts(packed(xs, ys, legal)))       # marks position 2
    assert_false(marked.accepts(packed(xs, ys, illegal)))    # marks where y = 0
    assert_false(marked.accepts(packed(xs, ys, twice)))      # marks nothing

    # Drop z. What survives is exactly "some position has x = y = 1", which over
    # the packed pair alphabet is "contains the letter 3".
    var witnessed = project(marked, 3, 2)
    assert_equal(witnessed.letters, 4)
    assert_true(same_language(witnessed, contains_letter(4, 3)))
    var both_ones: List[Int] = [1, 0, 3]
    var never: List[Int] = [1, 2, 1]
    assert_true(witnessed.accepts(both_ones))
    assert_false(witnessed.accepts(never))
    assert_equal(minimised(witnessed).states(), 2)

    # The construction had to merge: at a position with x = y = 1 the mark may
    # be placed or deferred, so the reachable subsets are genuinely sets. A
    # projection that merely renumbered letters could not accept `1 0 3`, whose
    # only legal mark is at the last position.
    assert_true(witnessed.states() >= 2)

    # Dropping a different track is a different language, so the track index is
    # load-bearing: quantifying x instead leaves "z marks one position, and y is
    # 1 there", which rejects a mark where y = 0.
    var over_x = project(marked, 3, 0)
    var y_track: List[Int] = [0, 0, 1]
    var z_track: List[Int] = [0, 0, 1]
    var bad_z: List[Int] = [1, 0, 0]
    var yz = List[Int]()
    var yz_bad = List[Int]()
    for i in range(3):
        yz.append(y_track[i] + 2 * z_track[i])
        yz_bad.append(y_track[i] + 2 * bad_z[i])
    assert_true(over_x.accepts(yz))
    assert_false(over_x.accepts(yz_bad))
    assert_false(same_language(over_x, witnessed))


def test_two_quantifiers_eliminate_in_sequence() raises:
    """`exists x exists z` on the same language, one projection at a time.

    After dropping `z` the tracks renumber to `(x, y)`, so `x` is track 0 of
    the smaller alphabet. What is left is "some position has y = 1": a witness
    can always be marked where `y` holds, by choosing `x` there. Two
    quantifiers, two subset constructions, and a language small enough to check
    by hand.
    """
    var marked = one_marked_coincidence()
    var once = project(marked, 3, 2)
    var twice = project(once, 2, 0)
    assert_equal(twice.letters, 2)
    assert_true(same_language(twice, contains_letter(2, 1)))
    var has_one: List[Int] = [0, 1, 0]
    var all_zero: List[Int] = [0, 0, 0]
    assert_true(twice.accepts(has_one))
    assert_false(twice.accepts(all_zero))
    assert_equal(minimised(twice).states(), 2)
    # Order does not matter for two existentials over the same language.
    var other_order = project(project(marked, 3, 0), 2, 1)
    assert_true(same_language(twice, other_order))


def test_a_count_past_the_machine_range_is_still_exact() raises:
    """`2^63` words, which a machine integer cannot hold.

    One state, two letters, accepting: the language is every binary word, so
    the count at length `n` is exactly `2^n`. At 63 an Int has already left its
    range, and a wrapped answer would be a wrong number presented as a count.
    The check is against `2^n` built by doubling, which shares no step with the
    dynamic programming that produced it."""
    var delta: List[Int] = [0, 0]
    var accepting: List[Bool] = [True]
    var universal = Dfa(2, delta, accepting)
    var two = counts(2)
    var expected = counts(1)
    for n in range(65):
        assert_true(bigz_eq(accepted_count(universal, n), expected))
        expected = bigz_mul(expected, two)


def test_a_track_condition_enters_and_leaves_a_product() raises:
    """`cylinder` is how a condition on one track enters a product, and
    `project` is how a track leaves it. Putting a condition on track zero in and
    then quantifying track one away must give the condition back, over the
    alphabet it started in -- and widening an automaton to a larger alphabet
    must not let it accept a letter it never had."""
    # Over {0, 1}: words with an even number of ones.
    var even = Dfa(2, [0, 1, 1, 0], [True, False])
    var wide = widened(even, 3)
    assert_true(wide.accepts([0, 1, 1]))
    assert_false(wide.accepts([2]))
    assert_false(wide.accepts([1, 1, 2]))

    var lifted = cylinder(wide, 2, 0, 3)
    # Track zero reads the condition; track one is free, so quantifying it away
    # returns the condition itself.
    var back = minimised(project(lifted, 2, 1))
    assert_true(same_language(back, minimised(wide)))

    # Placed on track one instead, the same condition reads the other digit.
    var other = cylinder(wide, 2, 1, 3)
    assert_true(other.accepts([3, 3]))
    assert_false(other.accepts([3, 0]))

    var shrunk = False
    try:
        _ = widened(even, 1)
    except:
        shrunk = True
    assert_true(shrunk)

    var mismatched = False
    try:
        _ = cylinder(even, 2, 0, 3)
    except:
        mismatched = True
    assert_true(mismatched)


def main() raises:
    test_the_kernel_is_a_boolean_algebra_of_languages()
    print("[PASS] test_the_kernel_is_a_boolean_algebra_of_languages")
    test_emptiness_reports_the_instance_not_only_the_verdict()
    print("[PASS] test_emptiness_reports_the_instance_not_only_the_verdict")
    test_projection_discharges_one_existential_quantifier()
    print("[PASS] test_projection_discharges_one_existential_quantifier")
    test_minimisation_identifies_exactly_equal_languages()
    print("[PASS] test_minimisation_identifies_exactly_equal_languages")
    test_a_partial_table_is_completed_by_one_rejecting_sink()
    print("[PASS] test_a_partial_table_is_completed_by_one_rejecting_sink")
    test_projection_over_three_tracks_eliminates_a_real_quantifier()
    print("[PASS] test_projection_over_three_tracks_eliminates_a_real_quantifier")
    test_two_quantifiers_eliminate_in_sequence()
    print("[PASS] test_two_quantifiers_eliminate_in_sequence")
    test_a_count_past_the_machine_range_is_still_exact()
    print("[PASS] test_a_count_past_the_machine_range_is_still_exact")
    test_a_track_condition_enters_and_leaves_a_product()
    print("[PASS] test_a_track_condition_enters_and_leaves_a_product")
    print("9 finite_automata tests passed.")
