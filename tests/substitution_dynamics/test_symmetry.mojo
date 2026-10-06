"""Regressions for `substitution_dynamics.symmetry` and `.endpoint_maps`.

The three-letter fixtures are the ones the PSC research kernel
(`larsbx/pisot-substitution-conjecture-research`,
`kernel/tests/test_census_library.mojo` and
`kernel/tests/test_endpoint_core.mojo`) pins on its own
alphabet-3 views of these modules, with identical expected values, so the
generalisation cannot have moved an alphabet-3 answer. The other alphabets
check what the generalisation adds: conjugacy class counts of self-maps of
one, two and four letters (OEIS A001372: 1, 3, 7, 19), canonical forms on
four letters, and keys that stay injective past ten letters. Run with
`pixi run test-substitution`.
"""

from std.testing import assert_equal, assert_false, assert_true

from substitution_dynamics.endpoint_maps import (
    LetterPair,
    all_maps,
    canonical_map,
    class_of,
    classify_maps,
    functional_cycle_lengths,
    is_recurrent_pair,
    nonsynchronizing_pairs,
    pairs_key,
    recurrent_nonsynchronizing_core,
    steps_to_recurrent_core,
    synchronization_partition,
    synchronization_quotient_permutation,
    synchronizes,
    validate_map,
)
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.symmetry import (
    canonical_pair,
    canonical_substitution,
    conjugated_substitution,
    inverse_permutation,
    normalised_pair,
    parse_substitution_key,
    permutations,
    relabel,
    reversed_pair,
    reversed_substitution,
    reversed_word,
    substitution_key,
    word_key,
    word_less,
)
from substitution_dynamics.words import Pair


def test_alphabet3_normal_forms() raises:
    assert_equal(len(permutations(3)), 6)
    assert_equal(len(permutations(4)), 24)
    assert_equal(word_key(permutations(3)[0]), "012")
    assert_equal(word_key(inverse_permutation([1, 2, 0])), "201")
    var perm: List[Int] = [1, 2, 0]
    assert_equal(word_key(relabel([0, 0, 2], perm)), "110")
    assert_equal(word_key(reversed_word([0, 1, 2])), "210")

    var u: List[Int] = [1, 0]
    var v: List[Int] = [0, 1]
    assert_equal(normalised_pair(u, v).key(), "01|10")
    assert_equal(canonical_pair(Pair(u, v), 3).key(), "01|10")
    assert_equal(reversed_pair(Pair(u, v)).key(), "01|10")

    var sigma = parse_substitution_key("011/2/120", 3)
    assert_equal(substitution_key(sigma), "011/2/120")
    assert_equal(substitution_key(canonical_substitution(sigma)), "011/2/120")
    assert_equal(substitution_key(reversed_substitution(sigma)), "110/2/021")
    var conjugated = conjugated_substitution(sigma, perm)
    assert_equal(substitution_key(conjugated_substitution(conjugated, inverse_permutation(perm))), "011/2/120")
    for p in range(6):
        var image = conjugated_substitution(sigma, permutations(3)[p])
        assert_equal(substitution_key(canonical_substitution(image)), "011/2/120")

    var malformed = False
    try:
        _ = parse_substitution_key("01/2", 3)
    except:
        malformed = True
    assert_true(malformed)
    var outside = False
    try:
        _ = parse_substitution_key("01/3/0", 3)
    except:
        outside = True
    assert_true(outside)


def test_other_alphabets() raises:
    # Permutations are lexicographic and complete.
    var perms = permutations(4)
    for i in range(1, len(perms)):
        assert_true(word_less(perms[i - 1], perms[i]))
    assert_equal(word_key(perms[23]), "3210")
    assert_equal(len(permutations(1)), 1)
    # A two-letter pair: swapping the letters of (110, 011) gives the least form.
    assert_equal(canonical_pair(Pair([1, 1, 0], [0, 1, 1]), 2).key(), "001|100")
    # A four-letter substitution and a relabelling of it share one canonical form.
    var sigma = parse_substitution_key("01/2/3/0", 4)
    var relabelled = conjugated_substitution(sigma, [2, 0, 3, 1])
    assert_equal(substitution_key(canonical_substitution(sigma)), substitution_key(canonical_substitution(relabelled)))
    assert_equal(substitution_key(canonical_substitution(sigma)), "01/2/3/0")


def test_keys_are_injective_past_ten_letters() raises:
    var w: List[Int] = [1, 0, 11]
    assert_equal(word_key(w), "10[11]")
    assert_true(word_key([1, 0]) != word_key([10]))
    var images = List[List[Int]]()
    for a in range(12):
        images.append([(a + 1) % 12, a])
    var key = substitution_key(images)
    var back = parse_substitution_key(key, 12)
    assert_equal(len(back), 12)
    for a in range(12):
        assert_true(back[a] == images[a])
    var unclosed = False
    try:
        _ = parse_substitution_key("[1", 2)
    except:
        unclosed = True
    assert_true(unclosed)


def test_three_letter_maps_have_seven_conjugacy_classes() raises:
    var classes = classify_maps(3)
    var expected: List[String] = ["000", "001", "002", "012", "021", "100", "120"]
    var sizes: List[Int] = [3, 6, 6, 1, 3, 6, 2]
    var cores: List[String] = [
        "",
        "",
        "(0,2) (2,0)",
        "(0,1) (0,2) (1,0) (1,2) (2,0) (2,1)",
        "(0,1) (0,2) (1,0) (1,2) (2,0) (2,1)",
        "(0,1) (1,0)",
        "(0,1) (0,2) (1,0) (1,2) (2,0) (2,1)",
    ]
    assert_equal(len(classes), len(expected))
    var members = 0
    var syncing = List[String]()
    for i in range(len(classes)):
        assert_equal(word_key(classes[i].representative), expected[i])
        assert_equal(classes[i].size(), sizes[i])
        assert_equal(pairs_key(classes[i].recurrent_core), cores[i])
        if classes[i].globally_synchronizing():
            syncing.append(word_key(classes[i].representative))
        members += classes[i].size()
    assert_equal(members, 27)
    assert_equal(len(all_maps(3)), 27)
    var synchronizing: List[String] = ["000", "001"]
    assert_equal(syncing, synchronizing)


def test_three_letter_cores_and_entry_times() raises:
    var h: List[Int] = [0, 0, 2]
    assert_false(synchronizes(h, 1, 2))
    assert_true(LetterPair(1, 2) in nonsynchronizing_pairs(h))
    assert_false(is_recurrent_pair(h, LetterPair(1, 2)))
    assert_true(is_recurrent_pair(h, LetterPair(0, 2)))
    assert_equal(pairs_key(recurrent_nonsynchronizing_core(h)), "(0,2) (2,0)")
    assert_equal(steps_to_recurrent_core(h, 1, 2), 1)
    assert_equal(steps_to_recurrent_core(h, 0, 2), 0)
    var maps = all_maps(3)
    for m in range(len(maps)):
        assert_equal(word_key(class_of(maps[m]).representative), word_key(canonical_map(maps[m])))
        var partition = synchronization_partition(maps[m])
        assert_equal(len(synchronization_quotient_permutation(maps[m])), len(partition))
        for a in range(3):
            for b in range(3):
                if a != b:
                    var steps = steps_to_recurrent_core(maps[m], a, b)
                    assert_true(steps <= 1)
                    assert_equal(steps < 0, synchronizes(maps[m], a, b))
    assert_equal(word_key(canonical_map([1, 0, 0])), "100")
    assert_equal(word_key(canonical_map([2, 2, 1])), "100")
    var shapes: List[List[Int]] = [[0, 0, 0], [0, 0, 2], [0, 1, 2], [0, 2, 1], [1, 0, 0], [1, 2, 0]]
    var lengths: List[String] = ["1", "11", "111", "12", "2", "3"]
    for i in range(len(shapes)):
        assert_equal(word_key(functional_cycle_lengths(shapes[i])), lengths[i])


def test_class_counts_on_other_alphabets() raises:
    """Conjugacy classes of self-maps: 1, 3, 7, 19 for 1..4 letters, and every
    map lands in exactly one class."""
    var counts: List[Int] = [1, 3, 7, 19]
    for size in range(1, 5):
        var classes = classify_maps(size)
        assert_equal(len(classes), counts[size - 1])
        var members = 0
        for i in range(len(classes)):
            members += classes[i].size()
        var total = 1
        for _ in range(size):
            total *= size
        assert_equal(members, total)
    # On four letters the 4-cycle synchronizes nothing and its core is every
    # ordered distinct pair.
    var cycle: List[Int] = [1, 2, 3, 0]
    assert_equal(len(recurrent_nonsynchronizing_core(cycle)), 12)
    assert_equal(len(synchronization_partition(cycle)), 4)
    var bad = False
    try:
        validate_map([0, 4, 1, 2])
    except:
        bad = True
    assert_true(bad)


def test_endpoint_maps_read_the_image_ends() raises:
    var sigma = Substitution.checked(parse_substitution_key("011/2/120", 3))
    assert_equal(word_key(sigma.prefix_endpoint_map()), "021")
    assert_equal(word_key(sigma.suffix_endpoint_map()), "120")


def main() raises:
    test_alphabet3_normal_forms()
    print("[PASS] test_alphabet3_normal_forms")
    test_other_alphabets()
    print("[PASS] test_other_alphabets")
    test_keys_are_injective_past_ten_letters()
    print("[PASS] test_keys_are_injective_past_ten_letters")
    test_three_letter_maps_have_seven_conjugacy_classes()
    print("[PASS] test_three_letter_maps_have_seven_conjugacy_classes")
    test_three_letter_cores_and_entry_times()
    print("[PASS] test_three_letter_cores_and_entry_times")
    test_class_counts_on_other_alphabets()
    print("[PASS] test_class_counts_on_other_alphabets")
    test_endpoint_maps_read_the_image_ends()
    print("[PASS] test_endpoint_maps_read_the_image_ends")
    print("7 symmetry and endpoint-map Mojo tests passed.")
