"""Regressions for the alphabet-generic `substitution_dynamics` package.

The two- and four-letter automaton counts below are pinned to the
independent Python oracle `src/psc_research/bpa.py` of
`larsbx/pisot-substitution-conjecture-research`, whose
`tests/test_substitution_dynamics_oracle.py` asserts the same constants,
so the package and the oracle agree off the alphabet-3 corpus. Run with
`pixi run test`.
"""

from std.testing import assert_equal, assert_false, assert_true

from substitution_dynamics.automaton import build, nonproductive_states, recurrent_noncoincident_sccs, sccs
from substitution_dynamics.balanced_pairs import coincidence_boundaries, children, decompose, normalise, seed_states
from substitution_dynamics.discrepancy import discrepancy, max_reachable_discrepancy, swap_walk_profile
from substitution_dynamics.substitution import Substitution, validate_word
from substitution_dynamics.words import Pair, checked_pair, idx3, is_balanced, is_zero, k1, k2, k3, n2, n3, parikh


def fibonacci() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [0]]
    return Substitution.checked(images)


def four_letter() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [0, 2], [0, 3], [0]]
    return Substitution.checked(images)


def tribonacci() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [0, 2], [0]]
    return Substitution.checked(images)


def _sum(xs: List[Int]) -> Int:
    var out = 0
    for i in range(len(xs)):
        out += xs[i]
    return out


def test_boundary_rejects_bad_letters_and_erasing_images() raises:
    var bad_letter: List[List[Int]] = [[0, 2], [0]]
    var caught = False
    try:
        _ = Substitution.checked(bad_letter)
    except:
        caught = True
    assert_true(caught)

    var erasing: List[List[Int]] = [[0, 1], []]
    caught = False
    try:
        _ = Substitution.checked(erasing)
    except:
        caught = True
    assert_true(caught)

    var empty = List[List[Int]]()
    caught = False
    try:
        _ = Substitution.checked(empty)
    except:
        caught = True
    assert_true(caught)

    caught = False
    try:
        _ = checked_pair([0, 1], [1], 2)
    except:
        caught = True
    assert_true(caught)

    caught = False
    try:
        validate_word([0, 1, 5], 3)
    except:
        caught = True
    assert_true(caught)


def test_substitution_maps_and_incidence() raises:
    var s = fibonacci()
    assert_equal(s.size, 2)
    assert_equal(len(s.apply_n([0], 5)), 13)
    assert_equal(parikh(s.apply_n([0], 5), 2), [8, 5])
    assert_equal(s.incidence(), [1, 1, 1, 0])
    assert_equal(s.prefix_endpoint_map(), [0, 0])
    assert_equal(s.suffix_endpoint_map(), [1, 0])
    assert_equal(s.image_prefix_lengths([0, 1, 0]), [0, 2, 3, 5])
    var f = four_letter()
    assert_equal(f.incidence(), [1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0])


def test_generic_streaming_counts() raises:
    # Alphabet 2: every pair and triple of positions is counted exactly once.
    var w: List[Int] = [0, 1, 1, 0, 1]
    assert_equal(_sum(n2(w, 2)), 10)
    assert_equal(_sum(n3(w, 2)), 10)
    assert_equal(n2(w, 2), [1, 4, 2, 3])
    # Alphabet 4 uses the lex index (size*a + b)*size + c.
    assert_equal(idx3(1, 2, 3, 4), 27)
    assert_equal(idx3(2, 1, 0, 3), 21)
    var x: List[Int] = [3, 0, 3]
    var t = n3(x, 4)
    assert_equal(len(t), 64)
    assert_equal(t[idx3(3, 0, 3, 4)], 1)
    assert_equal(_sum(t), 1)


def test_pairs_and_invariants_over_two_letters() raises:
    var p = checked_pair([0, 1, 1, 0], [1, 0, 0, 1], 2)
    assert_true(is_balanced(p, 2))
    assert_true(is_zero(k1(p, 2)))
    # 0110 and 1001 share every scattered pair count; the triples differ.
    assert_true(is_zero(k2(p, 2)))
    assert_equal(len(k3(p, 2)), 8)
    assert_false(is_zero(k3(p, 2)))
    assert_equal(coincidence_boundaries(p.u, p.v, 2), [0, 2, 4])
    assert_equal(len(decompose(p.u, p.v, 2)), 2)
    assert_equal(normalise(Pair([1, 0], [0, 1])).key(), "01|10")
    assert_equal(discrepancy(p, 2), 1)
    var unbalanced = Pair([0, 0], [0, 1])
    assert_false(is_balanced(unbalanced, 2))


def test_four_letter_boundaries_and_seeds() raises:
    assert_equal(coincidence_boundaries([0, 1, 2, 3], [3, 2, 1, 0], 4), [0, 4])
    assert_equal(len(seed_states(4)), 6)
    assert_equal(len(seed_states(2)), 1)
    var s = four_letter()
    var kids = children(s, Pair([0, 3], [3, 0]))
    assert_true(len(kids) >= 1)
    for i in range(len(kids)):
        assert_true(is_balanced(kids[i], 4))


def test_fibonacci_automaton_matches_oracle() raises:
    var a = build(fibonacci(), 1000)
    assert_false(a.capped)
    assert_equal(a.alphabet, 2)
    assert_equal(a.size(), 2)
    assert_equal(len(sccs(a)), 2)
    assert_equal(len(recurrent_noncoincident_sccs(a)), 1)
    assert_equal(len(nonproductive_states(a)), 0)
    assert_equal(max_reachable_discrepancy(a), 1)


def test_four_letter_automaton_matches_oracle() raises:
    var a = build(four_letter(), 1000)
    assert_false(a.capped)
    assert_equal(a.size(), 15)
    assert_equal(len(sccs(a)), 6)
    assert_equal(len(recurrent_noncoincident_sccs(a)), 1)
    assert_equal(len(nonproductive_states(a)), 0)


def test_tribonacci_agrees_with_the_alphabet3_kernel() raises:
    var a = build(tribonacci(), 20000)
    assert_false(a.capped)
    assert_equal(a.size(), 6)
    assert_equal(len(sccs(a)), 3)
    assert_equal(len(recurrent_noncoincident_sccs(a)), 1)
    var profile = swap_walk_profile(tribonacci(), 6)
    for n in range(len(profile)):
        assert_equal(profile[n], 1)


def test_capped_build_is_flagged_not_answered() raises:
    var a = build(four_letter(), 4)
    assert_true(a.capped)
    assert_true(a.size() <= 4)
    # A capped prefix has no edges; productivity and components are undefined.
    var caught = False
    try:
        _ = nonproductive_states(a)
    except:
        caught = True
    assert_true(caught)
    caught = False
    try:
        _ = recurrent_noncoincident_sccs(a)
    except:
        caught = True
    assert_true(caught)


def test_keys_are_injective_on_large_alphabets() raises:
    # Over 13 letters, digit concatenation would confuse these two pairs.
    var a = Pair([0, 12], [12, 0])
    var b = Pair([0, 1, 2], [1, 2, 0])
    assert_true(a.key() != b.key())
    assert_equal(a.key(), "0[12]|[12]0")
    assert_equal(b.key(), "012|120")
    # The confusable pair is reachable: sigma(0)=0, sigma(1)=12 over 13 letters.
    var images = List[List[Int]]()
    images.append([0])
    images.append([1, 2])
    for a2 in range(2, 13):
        images.append([a2 - 1])
    var s = Substitution.checked(images)
    var kids = children(s, Pair([0, 1], [1, 0]))
    assert_equal(len(kids), 1)
    assert_equal(kids[0].key(), "012|120")
    assert_true(kids[0] == b)
    # Interning by key keeps the two pairs apart.
    var index = Dict[String, Int]()
    index[a.key()] = 0
    index[kids[0].key()] = 1
    assert_equal(len(index), 2)


def main() raises:
    test_boundary_rejects_bad_letters_and_erasing_images()
    print("[PASS] test_boundary_rejects_bad_letters_and_erasing_images")
    test_substitution_maps_and_incidence()
    print("[PASS] test_substitution_maps_and_incidence")
    test_generic_streaming_counts()
    print("[PASS] test_generic_streaming_counts")
    test_pairs_and_invariants_over_two_letters()
    print("[PASS] test_pairs_and_invariants_over_two_letters")
    test_four_letter_boundaries_and_seeds()
    print("[PASS] test_four_letter_boundaries_and_seeds")
    test_fibonacci_automaton_matches_oracle()
    print("[PASS] test_fibonacci_automaton_matches_oracle")
    test_four_letter_automaton_matches_oracle()
    print("[PASS] test_four_letter_automaton_matches_oracle")
    test_tribonacci_agrees_with_the_alphabet3_kernel()
    print("[PASS] test_tribonacci_agrees_with_the_alphabet3_kernel")
    test_capped_build_is_flagged_not_answered()
    print("[PASS] test_capped_build_is_flagged_not_answered")
    test_keys_are_injective_on_large_alphabets()
    print("[PASS] test_keys_are_injective_on_large_alphabets")
    print("10 substitution-dynamics Mojo tests passed.")
