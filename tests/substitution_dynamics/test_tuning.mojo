"""Regressions for tuning patterns, directive prefixes, and column coincidence.

Every constant pinned here is also asserted by the independent Python oracle
`tests/substitution_dynamics/test_tuning_reference.py` over
`tools/tuning_reference.py`. Run with `pixi run test-tuning`.
"""

from std.testing import assert_equal, assert_false, assert_true

from substitution_dynamics.coincidence import CoincidenceWitness, column_coincidence, constant_length, is_constant_length
from substitution_dynamics.sadic import apply_directive, compose, directive_composite
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.tuning import TuningPattern, continuation_twist, dgp_twist, kneading_prefix, star_product


def period_doubling() raises -> TuningPattern:
    var prefix: List[Int] = [1]
    return TuningPattern.dgp(prefix)


def thue_morse() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [1, 0]]
    return Substitution.checked(images)


def fibonacci() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [0]]
    return Substitution.checked(images)


def three_letter_depth_two() raises -> Substitution:
    var images: List[List[Int]] = [[0, 1], [2, 0], [2, 1]]
    return Substitution.checked(images)


def same_images(s: Substitution, t: Substitution) -> Bool:
    if s.size != t.size:
        return False
    for a in range(s.size):
        if s.image(a) != t.image(a):
            return False
    return True


def test_boundary_rejects_bad_prefixes() raises:
    var caught = False
    try:
        _ = TuningPattern.checked(List[Int](), False)
    except:
        caught = True
    assert_true(caught)

    var bad: List[Int] = [0, 2]
    caught = False
    try:
        _ = TuningPattern.checked(bad, False)
    except:
        caught = True
    assert_true(caught)

    var ok: List[Int] = [1, 0]
    var p = TuningPattern.checked(ok, True)
    assert_equal(p.prefix, [1, 0])
    assert_true(p.twist)


def test_period_doubling_is_the_dgp_tuning_of_the_period_two_centre() raises:
    var p = period_doubling()
    assert_equal(p.prefix, [1])
    assert_true(p.twist)
    assert_true(dgp_twist(p.prefix))
    assert_equal(p.period(), 2)
    var s = p.substitution()
    assert_equal(s.size, 2)
    assert_equal(s.image(0), [1, 1])
    assert_equal(s.image(1), [1, 0])


def test_star_product_of_period_doubling_with_itself() raises:
    var p = period_doubling()
    var a2 = star_product(p, p)
    assert_equal(a2.prefix, [1, 0, 1])
    assert_false(a2.twist)
    assert_equal(a2.period(), 4)
    var s = a2.substitution()
    assert_equal(s.image(0), [1, 0, 1, 0])
    assert_equal(s.image(1), [1, 0, 1, 1])
    assert_true(same_images(s, compose(p.substitution(), p.substitution())))
    # The DGP parity is closed under the star product.
    assert_equal(dgp_twist(a2.prefix), a2.twist)


def test_feigenbaum_kneading_prefix() raises:
    var p = period_doubling()
    var one = List[TuningPattern]()
    one.append(p.copy())
    assert_equal(kneading_prefix(one), [1])
    var two = List[TuningPattern]()
    two.append(p.copy())
    two.append(p.copy())
    assert_equal(kneading_prefix(two), [1, 0, 1])
    var three = List[TuningPattern]()
    three.append(p.copy())
    three.append(p.copy())
    three.append(p.copy())
    assert_equal(kneading_prefix(three), [1, 0, 1, 1, 1, 0, 1])
    var five = List[TuningPattern]()
    for _ in range(5):
        five.append(p.copy())
    assert_equal(len(kneading_prefix(five)), 31)
    var caught = False
    try:
        _ = kneading_prefix(List[TuningPattern]())
    except:
        caught = True
    assert_true(caught)


def test_star_product_is_composition_for_arbitrary_twists() raises:
    var pa: List[Int] = [0, 1, 1]
    var pb: List[Int] = [1, 0]
    var a = TuningPattern.checked(pa, False)
    var b = TuningPattern.checked(pb, True)
    var ab = star_product(a, b)
    assert_equal(ab.period(), a.period() * b.period())
    assert_true(same_images(ab.substitution(), compose(a.substitution(), b.substitution())))
    var ba = star_product(b, a)
    assert_true(same_images(ba.substitution(), compose(b.substitution(), a.substitution())))
    assert_true(ab.twist)
    assert_true(ba.twist)


def test_directive_composite_and_application_agree() raises:
    var subs = List[Substitution]()
    subs.append(period_doubling().substitution())
    subs.append(thue_morse())
    var third: List[List[Int]] = [[1, 0], [0, 0]]
    subs.append(Substitution.checked(third))
    var comp = directive_composite(subs)
    var w: List[Int] = [0, 1, 1]
    assert_equal(comp.apply(w), apply_directive(subs, w))
    var x: List[Int] = [1]
    assert_equal(comp.apply(x), apply_directive(subs, x))
    # Composition needs one alphabet, not constant length: two-letter
    # Fibonacci composes with Thue-Morse.
    var mixed = compose(thue_morse(), fibonacci())
    assert_equal(mixed.image(0), [0, 1, 1, 0])
    assert_equal(mixed.image(1), [0, 1])
    var three: List[List[Int]] = [[0, 1, 2], [0], [1]]
    var caught = False
    try:
        _ = compose(thue_morse(), Substitution.checked(three))
    except:
        caught = True
    assert_true(caught)
    caught = False
    try:
        _ = directive_composite(List[Substitution]())
    except:
        caught = True
    assert_true(caught)


def test_kneading_prefix_is_a_prefix_of_every_tuning_image() raises:
    var p1: List[Int] = [1, 1, 0]
    var p2: List[Int] = [0]
    var pats = List[TuningPattern]()
    pats.append(TuningPattern.dgp(p1))
    pats.append(TuningPattern.dgp(p2))
    var prefix = kneading_prefix(pats)
    var subs = List[Substitution]()
    subs.append(pats[0].substitution())
    subs.append(pats[1].substitution())
    var comp = directive_composite(subs)
    for s in range(2):
        var img = comp.image(s)
        assert_equal(len(img), len(prefix) + 1)
        for i in range(len(prefix)):
            assert_equal(img[i], prefix[i])


def test_continuation_twist_pinned_values_and_disagreement_with_parity() raises:
    var one: List[Int] = [1]
    var ten: List[Int] = [1, 0]
    var eleven: List[Int] = [1, 1]
    var prim4: List[Int] = [1, 0, 0]
    var sat4: List[Int] = [1, 0, 1]
    assert_true(continuation_twist(one))
    assert_true(continuation_twist(ten))
    assert_true(continuation_twist(eleven))
    assert_true(continuation_twist(prim4))
    assert_false(continuation_twist(sat4))
    # Parity agrees on 1, 10, 100, 101 and disagrees on 11.
    assert_equal(dgp_twist(one), continuation_twist(one))
    assert_equal(dgp_twist(ten), continuation_twist(ten))
    assert_equal(dgp_twist(prim4), continuation_twist(prim4))
    assert_equal(dgp_twist(sat4), continuation_twist(sat4))
    assert_false(dgp_twist(eleven))
    var rabbit = TuningPattern.continuation(eleven)
    assert_equal(rabbit.substitution().image(1), [1, 1, 0])
    assert_equal(rabbit.substitution().image(0), [1, 1, 1])
    # Closure under the star product, on the pinned pairs.
    var ab = star_product(rabbit, TuningPattern.continuation(one))
    assert_equal(ab.prefix, [1, 1, 0, 1, 1])
    assert_equal(continuation_twist(ab.prefix), ab.twist)
    var ba = star_product(TuningPattern.continuation(ten), TuningPattern.continuation(one))
    assert_equal(ba.prefix, [1, 0, 0, 1, 0])
    assert_equal(continuation_twist(ba.prefix), ba.twist)
    var caught = False
    try:
        _ = continuation_twist(List[Int]())
    except:
        caught = True
    assert_true(caught)


def test_every_tuning_substitution_has_a_coincidence_in_its_first_column() raises:
    var p: List[Int] = [0, 1, 1, 0]
    var w = column_coincidence(TuningPattern.checked(p, True).substitution())
    assert_true(w.found)
    assert_equal(w.depth, 1)
    assert_equal(w.columns, [0])
    var w2 = column_coincidence(period_doubling().substitution())
    assert_true(w2.found)
    assert_equal(w2.depth, 1)
    assert_equal(w2.columns, [0])


def test_thue_morse_has_no_column_coincidence() raises:
    var w = column_coincidence(thue_morse())
    assert_false(w.found)
    assert_equal(w.depth, -1)
    assert_equal(len(w.columns), 0)


def test_three_letter_example_needs_depth_two() raises:
    assert_equal(constant_length(three_letter_depth_two()), 2)
    var w = column_coincidence(three_letter_depth_two())
    assert_true(w.found)
    assert_equal(w.depth, 2)
    assert_equal(w.columns, [0, 1])
    var one: List[List[Int]] = [[0]]
    var w1 = column_coincidence(Substitution.checked(one))
    assert_true(w1.found)
    assert_equal(w1.depth, 0)


def test_non_constant_length_is_rejected() raises:
    assert_false(is_constant_length(fibonacci()))
    assert_true(is_constant_length(thue_morse()))
    var caught = False
    try:
        _ = column_coincidence(fibonacci())
    except:
        caught = True
    assert_true(caught)


def main() raises:
    test_boundary_rejects_bad_prefixes()
    print("[PASS] test_boundary_rejects_bad_prefixes")
    test_period_doubling_is_the_dgp_tuning_of_the_period_two_centre()
    print("[PASS] test_period_doubling_is_the_dgp_tuning_of_the_period_two_centre")
    test_star_product_of_period_doubling_with_itself()
    print("[PASS] test_star_product_of_period_doubling_with_itself")
    test_feigenbaum_kneading_prefix()
    print("[PASS] test_feigenbaum_kneading_prefix")
    test_star_product_is_composition_for_arbitrary_twists()
    print("[PASS] test_star_product_is_composition_for_arbitrary_twists")
    test_directive_composite_and_application_agree()
    print("[PASS] test_directive_composite_and_application_agree")
    test_kneading_prefix_is_a_prefix_of_every_tuning_image()
    print("[PASS] test_kneading_prefix_is_a_prefix_of_every_tuning_image")
    test_continuation_twist_pinned_values_and_disagreement_with_parity()
    print("[PASS] test_continuation_twist_pinned_values_and_disagreement_with_parity")
    test_every_tuning_substitution_has_a_coincidence_in_its_first_column()
    print("[PASS] test_every_tuning_substitution_has_a_coincidence_in_its_first_column")
    test_thue_morse_has_no_column_coincidence()
    print("[PASS] test_thue_morse_has_no_column_coincidence")
    test_three_letter_example_needs_depth_two()
    print("[PASS] test_three_letter_example_needs_depth_two")
    test_non_constant_length_is_rejected()
    print("[PASS] test_non_constant_length_is_rejected")
    print("12 tuning Mojo tests passed.")
