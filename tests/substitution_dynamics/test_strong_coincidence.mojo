"""Regressions for `substitution_dynamics.strong_coincidence`.

The module is generic over the caller's `DifferenceBound`; the PSC research
kernel (`larsbx/pisot-substitution-conjecture-research`,
`kernel/psc/coincidence_formula.mojo`) supplies the exact Perron-field
reserve. Here the bound is a coordinate box, which is *not* sound in general
and is used only because every answer below is checked against something that
does not depend on it:

* the least level against the definition carried out by substituting
  (`least_level_by_images`), on three letters and on two and four;
* on the four alphabet-3 specimens the PSC kernel pins (least levels 1, 3, 14,
  15), the shortest witness word, the minimised automaton and Parikh-relation
  sizes, and the coaccessible state count it reports with its reserve. Those
  are independent of the pruning as long as it keeps every coaccessible
  state: the breadth-first order of coaccessible states does not depend on
  which non-coaccessible ones are cut. So agreement is the generic core
  reproducing the alphabet-3 outputs, not a re-statement of them;
* the elimination route (`coincidence_by_elimination`) against the direct
  automaton, by language equality.

Run with `pixi run test-substitution`.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_automata.dfa import minimised, same_language, witness
from substitution_dynamics.strong_coincidence import (
    CheckedIncidence,
    DifferenceBound,
    balanced_proper_prefix_pairs,
    coincidence_automaton,
    coincidence_by_elimination,
    coincidence_level,
    coincidence_witness,
    coincident_positions,
    depth_bound,
    first_letter_merge_level,
    pair_paths,
    parikh_equality_automaton,
    path_letter,
    path_prefix_parikh,
    reaching_one_letter,
    worst_depth_bound,
    PairDepthBound,
)
from substitution_dynamics.balanced_pairs import sync_after
from substitution_dynamics.endpoint_maps import all_maps
from substitution_dynamics.dumont_thomas import max_image_length
from substitution_dynamics.substitution import Substitution


struct Box(DifferenceBound):
    """`M x + s` kept inside `[-bound, bound]^d`: a test bound, not a sound one."""

    var step: CheckedIncidence
    var bound: Int

    def __init__(out self, sigma: Substitution, bound: Int):
        self.step = CheckedIncidence(sigma)
        self.bound = bound

    def advance(self, delta: List[Int], contribution: List[Int]) raises -> List[Int]:
        return self.step.advance(delta, contribution)

    def admits(self, delta: List[Int]) raises -> Bool:
        for i in range(len(delta)):
            if delta[i] > self.bound or delta[i] < -self.bound:
                return False
        return True


comptime BOX = 6


def specimens() raises -> List[Substitution]:
    return [
        Substitution.checked([[0, 1], [0, 2], [0]]),
        Substitution.checked([[1], [0, 1, 2], [0, 1, 0]]),
        Substitution.checked([[1], [2], [0, 1]]),
        Substitution.checked([[2], [0], [0, 1]]),
    ]


def least_level_by_images(sigma: Substitution, top: Int, bottom: Int, max_level: Int) -> Int:
    """The definition: the least `k` at which `sigma^k(top)` and
    `sigma^k(bottom)` carry one letter at one position after prefixes of one
    Parikh vector."""
    var above: List[Int] = [top]
    var below: List[Int] = [bottom]
    for level in range(max_level + 1):
        var counted_above = List[Int](length=sigma.size, fill=0)
        var counted_below = List[Int](length=sigma.size, fill=0)
        var shorter = len(above) if len(above) < len(below) else len(below)
        for p in range(shorter):
            if counted_above == counted_below and above[p] == below[p]:
                return level
            counted_above[above[p]] += 1
            counted_below[below[p]] += 1
        above = sigma.apply(above)
        below = sigma.apply(below)
    return -1


def word_text(w: List[Int]) -> String:
    var out = String("")
    for i in range(len(w)):
        out += String(w[i]) + ","
    return out


def test_alphabet3_witnesses_and_sizes() raises:
    var corpus = specimens()
    # Per specimen, the nine ordered pairs (i, j) in row-major order.
    var words: List[List[String]] = [
        ["", "0,", "0,", "0,", "", "0,", "0,", "0,", ""],
        ["", "3,5,0,", "3,5,0,", "1,7,0,", "", "0,", "1,7,0,", "0,", ""],
        [
            "", "0,2,1,0,0,0,0,1,0,1,0,0,2,", "0,0,1,2,0,0,0,0,2,0,2,0,0,1,",
            "0,1,2,0,0,0,0,2,0,2,0,0,1,", "", "2,1,0,0,0,0,1,0,1,0,0,2,",
            "0,0,2,1,0,0,0,0,1,0,1,0,0,2,", "1,2,0,0,0,0,2,0,2,0,0,1,", "",
        ],
        [
            "", "0,1,2,0,0,2,1,0,2,0,0,2,0,1,0,", "2,1,0,0,1,2,0,1,0,0,1,0,2,0,",
            "0,2,1,0,0,1,2,0,1,0,0,1,0,2,0,", "", "0,",
            "1,2,0,0,2,1,0,2,0,0,2,0,1,0,", "0,", "",
        ],
    ]
    var minimal: List[List[Int]] = [
        [4, 6, 5, 6, 4, 5, 5, 5, 4],
        [4, 546, 546, 546, 4, 546, 546, 546, 4],
        [4, 68, 68, 68, 4, 68, 68, 68, 4],
        [4, 61, 61, 61, 4, 5, 61, 5, 4],
    ]
    var parikh: List[List[Int]] = [
        [4, 4, 4, 4, 4, 4, 4, 4, 4],
        [4, 546, 546, 546, 4, 546, 546, 546, 4],
        [4, 68, 68, 68, 4, 68, 68, 68, 4],
        [4, 60, 60, 60, 4, 4, 60, 4, 4],
    ]
    var coaccessible: List[List[Int]] = [
        [3, 5, 4, 5, 3, 4, 4, 4, 3],
        [3, 695, 695, 695, 3, 695, 695, 695, 3],
        [3, 67, 67, 67, 3, 67, 67, 67, 3],
        [3, 67, 67, 67, 3, 4, 67, 4, 3],
    ]
    var levels: List[Int] = [1, 3, 14, 15]
    for s in range(len(corpus)):
        ref sigma = corpus[s]
        var box = Box(sigma, BOX)
        var pairs = List[PairDepthBound]()
        for i in range(3):
            for j in range(3):
                var k = 3 * i + j
                var found = coincidence_witness(sigma, i, j, box)
                assert_false(found.empty)
                assert_equal(word_text(found.word), words[s][k])
                var whole = coincidence_automaton(sigma, i, j, box)
                assert_equal(minimised(whole).states(), minimal[s][k])
                assert_equal(minimised(parikh_equality_automaton(sigma, i, j, box)).states(), parikh[s][k])
                var bound = depth_bound(whole)
                assert_equal(bound.coaccessible, coaccessible[s][k])
                assert_equal(bound.upper, coaccessible[s][k] - 1)
                if i < j:
                    pairs.append(bound^)
        var worst = worst_depth_bound(pairs)
        assert_equal(worst.level, levels[s])
        assert_false(worst.empty)


def test_merge_and_prefix_pair_fixtures() raises:
    var corpus = specimens()
    # (0,1), (0,2), (1,2) per specimen.
    var merges: List[List[Int]] = [[1, 1, 1], [-1, -1, 1], [-1, -1, -1], [-1, -1, 1]]
    var prefix_pairs: List[List[Int]] = [[1, 0, 0], [0, 0, 2], [0, 0, 0], [0, 0, 0]]
    for s in range(len(corpus)):
        var k = 0
        for i in range(3):
            for j in range(i + 1, 3):
                assert_equal(first_letter_merge_level(corpus[s], i, j), merges[s][k])
                assert_equal(balanced_proper_prefix_pairs(corpus[s], i, j), prefix_pairs[s][k])
                k += 1
    var free = Substitution.checked([[1], [2, 2], [0, 1, 2]])
    for a in range(3):
        for b in range(3):
            if a != b:
                assert_equal(balanced_proper_prefix_pairs(free, a, b), 0)


def test_the_merge_bound_is_exact_on_small_alphabets() raises:
    """`first_letter_merge_level` stops after `d` iterates; on every self-map of
    one to four letters that is the exact merge time `sync_after` decides."""
    for size in range(1, 5):
        var maps = all_maps(size)
        for m in range(len(maps)):
            var images = List[List[Int]]()
            for a in range(size):
                images.append([maps[m][a]])
            var sigma = Substitution(images^, size)
            for a in range(size):
                for b in range(size):
                    assert_equal(first_letter_merge_level(sigma, a, b), sync_after(maps[m], a, b))


def test_levels_match_the_definition_on_other_alphabets() raises:
    var cases: List[Substitution] = [
        Substitution.checked([[0, 1], [0]]),
        Substitution.checked([[0, 1], [0, 2], [0, 3], [0]]),
        Substitution.checked([[1], [0, 1, 2], [0, 1, 0]]),
    ]
    for c in range(len(cases)):
        ref sigma = cases[c]
        var box = Box(sigma, BOX)
        var radix = max_image_length(sigma)
        for i in range(sigma.size):
            for j in range(sigma.size):
                var level = coincidence_level(sigma, i, j, box)
                assert_equal(level, least_level_by_images(sigma, i, j, 12))
                var found = coincidence_witness(sigma, i, j, box)
                var paths = pair_paths(radix, found.word)
                assert_equal(path_letter(sigma, i, paths[0]), path_letter(sigma, j, paths[1]))
                assert_equal(
                    path_prefix_parikh(sigma, box, i, paths[0]),
                    path_prefix_parikh(sigma, box, j, paths[1]),
                )
                var built = witness(coincidence_automaton(sigma, i, j, box))
                assert_equal(len(built.word), len(found.word))


def test_elimination_is_the_direct_automaton() raises:
    var cases: List[Substitution] = [
        Substitution.checked([[0, 1], [0]]),
        Substitution.checked([[0, 1], [0, 2], [0, 3], [0]]),
        Substitution.checked([[0, 1], [0, 2], [0]]),
        Substitution.checked([[1], [0, 1, 2], [0, 1, 0]]),
    ]
    for c in range(len(cases)):
        ref sigma = cases[c]
        var box = Box(sigma, BOX)
        for i in range(sigma.size):
            for j in range(sigma.size):
                var eliminated = coincidence_by_elimination(
                    sigma, i, j, parikh_equality_automaton(sigma, i, j, box)
                )
                assert_true(same_language(eliminated, minimised(coincidence_automaton(sigma, i, j, box))))
    var trib = cases[2].copy()
    var positions = coincident_positions(
        coincidence_by_elimination(trib, 0, 1, parikh_equality_automaton(trib, 0, 1, Box(trib, BOX)))
    )
    assert_equal(positions.states(), 6)
    var middling = cases[3].copy()
    var deep = coincident_positions(
        coincidence_by_elimination(middling, 0, 1, parikh_equality_automaton(middling, 0, 1, Box(middling, BOX)))
    )
    assert_equal(deep.states(), 616)


def test_malformed_input_raises() raises:
    var sigma = specimens()[0].copy()
    var box = Box(sigma, BOX)
    var flags = List[Bool](length=7, fill=False)
    try:
        _ = coincidence_automaton(sigma, 0, 3, box)
    except:
        flags[0] = True
    try:
        _ = coincidence_automaton(sigma, 0, 1, box, 1)
    except:
        flags[1] = True
    try:
        _ = coincidence_automaton(specimens()[3].copy(), 0, 1, Box(specimens()[3].copy(), BOX), 8)
    except:
        flags[2] = True
    try:
        _ = coincidence_witness(specimens()[3].copy(), 0, 1, Box(specimens()[3].copy(), BOX), 4)
    except:
        flags[3] = True
    try:
        _ = pair_paths(3, [9])
    except:
        flags[4] = True
    try:
        _ = path_prefix_parikh(sigma, box, 2, [1])
    except:
        flags[5] = True
    try:
        _ = reaching_one_letter(sigma, -1, 0)
    except:
        flags[6] = True
    for i in range(len(flags)):
        assert_true(flags[i])


def main() raises:
    test_alphabet3_witnesses_and_sizes()
    print("[PASS] test_alphabet3_witnesses_and_sizes")
    test_merge_and_prefix_pair_fixtures()
    print("[PASS] test_merge_and_prefix_pair_fixtures")
    test_the_merge_bound_is_exact_on_small_alphabets()
    print("[PASS] test_the_merge_bound_is_exact_on_small_alphabets")
    test_levels_match_the_definition_on_other_alphabets()
    print("[PASS] test_levels_match_the_definition_on_other_alphabets")
    test_elimination_is_the_direct_automaton()
    print("[PASS] test_elimination_is_the_direct_automaton")
    test_malformed_input_raises()
    print("[PASS] test_malformed_input_raises")
    print("6 strong-coincidence Mojo tests passed.")
