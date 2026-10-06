"""Every named object moved into a module of its own is still the same object
at its old import path.

Run with `pixi run test-named-modules`. Each moved name is imported twice, from
its named module and from the generic module it left (which re-exports it),
and the two are checked to agree. A struct is checked by type: a value built
through the new path is bound to a variable typed through the old one, which
compiles only if the two names denote one type. A function is checked on
fixed inputs. The behaviour of each object is pinned by its own package's
tests, which still import the old paths unchanged.
"""

from std.testing import assert_equal, assert_false, assert_true

from finite_exact.bigint_z import BigZ, bigz_eq, bigz_from_i64
from finite_exact.closed_interval import ComplexIQ, IQ
from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_vec

from finite_linear_algebra.cauchy_bound import root_bound
from finite_linear_algebra.faddeev_leverrier import charpoly
from finite_linear_algebra.sturm_sequence import (
    RootBracket,
    largest_root_bracket,
    refused_bracket,
    sign_variations,
    sturm_chain,
    variation_difference,
)
from finite_linear_algebra.qpoly import (
    RootBracket as OldRootBracket,
    charpoly as old_charpoly,
    largest_root_bracket as old_largest_root_bracket,
    refused_bracket as old_refused_bracket,
    root_bound as old_root_bound,
    sign_variations as old_sign_variations,
    sturm_chain as old_sturm_chain,
    variation_difference as old_variation_difference,
)
from finite_linear_algebra.wielandt_bound import wielandt_bound
from finite_linear_algebra.integer_matrix import wielandt_bound as old_wielandt_bound
from finite_linear_algebra.smith_normal_form import minor_gcds, smith_invariants
from finite_linear_algebra.madic_ball import minor_gcds as old_minor_gcds, smith_invariants as old_smith_invariants
from finite_linear_algebra.hermite_normal_form import row_hnf, row_hnf_equal
from finite_linear_algebra.integer_module import (
    i64_row,
    row_hnf as old_row_hnf,
    row_hnf_equal as old_row_hnf_equal,
)

from rational_dynamics.continued_fractions import (
    ContinuedFractionResult,
    ConvergentsResult,
    continued_fraction,
    convergents,
    rejected_cf,
    rejected_convergents,
)
from rational_dynamics.farey import farey_adjacent, farey_determinant
from rational_dynamics.rational import (
    ContinuedFractionResult as OldContinuedFractionResult,
    ConvergentsResult as OldConvergentsResult,
    continued_fraction as old_continued_fraction,
    convergents as old_convergents,
    farey_adjacent as old_farey_adjacent,
    farey_determinant as old_farey_determinant,
    fraction_from_i64,
    rejected_cf as old_rejected_cf,
    rejected_convergents as old_rejected_convergents,
)

from quadratic_orbit.krawczyk_operator import isolates_preperiodic_point, krawczyk_image
from quadratic_orbit.preperiodic import (
    isolates_preperiodic_point as old_isolates_preperiodic_point,
    krawczyk_image as old_krawczyk_image,
)

from finite_polynomial.cyclotomic_polynomial import (
    cyclotomic_degree,
    cyclotomic_polynomial,
    cyclotomic_product_identity,
)
from finite_polynomial.polynomial_z import (
    PolyZ,
    cyclotomic_degree as old_cyclotomic_degree,
    cyclotomic_polynomial as old_cyclotomic_polynomial,
    cyclotomic_product_identity as old_cyclotomic_product_identity,
    poly_equal,
)
from finite_polynomial.euler_totient import euler_phi
from finite_polynomial.moebius_function import mobius_mu
from finite_polynomial.cyclotomic_field import euler_phi as old_euler_phi, mobius_mu as old_mobius_mu

from finite_automata.dfa import Dfa, minimised as old_minimised, project as old_project, same_language
from finite_automata.moore_minimisation import minimised
from finite_automata.subset_construction import project

from projective_limits.mobius_transformation import Mobius, MobiusOver, mobius, mobius_apply, mobius_compose
from projective_limits.line import (
    Mobius as OldMobius,
    MobiusOver as OldMobiusOver,
    mobius as old_mobius,
    mobius_apply as old_mobius_apply,
    mobius_compose as old_mobius_compose,
    p1_affine,
    p1_equal,
    p1_infinity,
)
from projective_limits.spread_polynomial import spread_polynomial
from projective_limits.rotor import spread_polynomial as old_spread_polynomial
from finite_exact.field import QField


def poly(c: List[Int]) -> List[Q]:
    return q_vec(c)


def same_q_list(a: List[Q], b: List[Q]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if not a[i].eq(b[i]):
            return False
    return True


def same_bigz_list(a: List[BigZ], b: List[BigZ]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if not bigz_eq(a[i], b[i]):
            return False
    return True


def test_qpoly_named_modules() raises:
    var golden = poly([-1, -1, 1])  # x^2 - x - 1
    assert_true(root_bound(golden).eq(old_root_bound(golden)))
    var chain = sturm_chain(golden)
    var old_chain = old_sturm_chain(golden)
    assert_equal(len(chain), len(old_chain))
    for i in range(len(chain)):
        assert_true(same_q_list(chain[i], old_chain[i]))
    assert_equal(sign_variations(chain, Q(0, 1)), old_sign_variations(old_chain, Q(0, 1)))
    assert_equal(
        variation_difference(chain, Q(-2, 1), Q(2, 1)),
        old_variation_difference(old_chain, Q(-2, 1), Q(2, 1)),
    )
    var bracket: OldRootBracket = largest_root_bracket(golden, Q(1, 1024), 64)
    var old_bracket: RootBracket = old_largest_root_bracket(golden, Q(1, 1024), 64)
    assert_true(bracket.found and old_bracket.found)
    assert_true(bracket.lo.eq(old_bracket.lo) and bracket.hi.eq(old_bracket.hi))
    var refused: OldRootBracket = refused_bracket()
    assert_false(refused.found or old_refused_bracket().found)
    var m = List[List[Q]]()
    m.append(q_vec([0, 1, 0]))
    m.append(q_vec([0, 0, 1]))
    m.append(q_vec([1, 1, 1]))
    assert_true(same_q_list(charpoly(m), old_charpoly(m)))


def test_integer_matrix_and_module_named_modules() raises:
    for n in range(1, 6):
        assert_equal(wielandt_bound(n), old_wielandt_bound(n))
    var a = List[List[Q]]()
    a.append(q_vec([2, 0]))
    a.append(q_vec([0, 4]))
    assert_true(same_bigz_list(minor_gcds(a), old_minor_gcds(a)))
    assert_true(same_bigz_list(smith_invariants(a), old_smith_invariants(a)))
    var rows = List[List[BigZ]]()
    rows.append(i64_row([4, 6]))
    rows.append(i64_row([2, 3]))
    var hnf = row_hnf(rows, 2)
    var old_hnf = old_row_hnf(rows, 2)
    assert_equal(len(hnf), len(old_hnf))
    for i in range(len(hnf)):
        assert_true(same_bigz_list(hnf[i], old_hnf[i]))
    assert_true(row_hnf_equal(rows, old_hnf, 2) and old_row_hnf_equal(rows, hnf, 2))


def test_rational_dynamics_named_modules() raises:
    var x = fraction_from_i64(13, 8)
    var cf: OldContinuedFractionResult = continued_fraction(x)
    var old_cf: ContinuedFractionResult = old_continued_fraction(x)
    assert_true(same_bigz_list(cf.terms, old_cf.terms))
    var cv: OldConvergentsResult = convergents(x)
    var old_cv: ConvergentsResult = old_convergents(x)
    assert_true(same_bigz_list(cv.numerators, old_cv.numerators))
    assert_true(same_bigz_list(cv.denominators, old_cv.denominators))
    var rc: OldContinuedFractionResult = rejected_cf()
    var rv: OldConvergentsResult = rejected_convergents()
    assert_true(rc.rejected and rv.rejected and old_rejected_cf().rejected and old_rejected_convergents().rejected)
    var left = fraction_from_i64(1, 3)
    var right = fraction_from_i64(1, 2)
    assert_true(bigz_eq(farey_determinant(left, right).value, old_farey_determinant(left, right).value))
    assert_true(farey_adjacent(left, right) and old_farey_adjacent(left, right))


def test_krawczyk_named_module() raises:
    var c = ComplexIQ.singleton(Q.zero(), Q.zero())
    var z = ComplexIQ(IQ(Q(7, 8), Q(9, 8)), IQ(Q(-1, 8), Q(1, 8)))
    var image = krawczyk_image(z, c, 0, 1)
    var old_image = old_krawczyk_image(z, c, 0, 1)
    assert_true(image.re.lo.eq(old_image.re.lo) and image.re.hi.eq(old_image.re.hi))
    assert_true(image.im.lo.eq(old_image.im.lo) and image.im.hi.eq(old_image.im.hi))
    assert_true(isolates_preperiodic_point(z, c, 0, 1))
    assert_true(old_isolates_preperiodic_point(z, c, 0, 1))


def test_finite_polynomial_named_modules() raises:
    for n in range(1, 13):
        var phi: PolyZ = cyclotomic_polynomial(n)
        assert_true(poly_equal(phi, old_cyclotomic_polynomial(n)))
        assert_equal(cyclotomic_degree(n), old_cyclotomic_degree(n))
        assert_true(cyclotomic_product_identity(n) and old_cyclotomic_product_identity(n))
        assert_equal(euler_phi(n), old_euler_phi(n))
        assert_equal(mobius_mu(n), old_mobius_mu(n))


def test_finite_automata_named_modules() raises:
    # Two tracks over {0, 1}: accept words whose letters all have track 0 equal to 1.
    var delta: List[Int] = [1, 0, 1, 0, 1, 1, 1, 1]
    var accepting: List[Bool] = [True, False]
    var a = Dfa(4, delta, accepting)
    var p: Dfa = project(a, 2, 1)
    var old_p: Dfa = old_project(a, 2, 1)
    assert_true(same_language(p, old_p))
    assert_equal(p.states(), old_p.states())
    var m: Dfa = minimised(a)
    var old_m: Dfa = old_minimised(a)
    assert_true(same_language(m, old_m))
    assert_equal(m.states(), old_m.states())


def test_projective_limits_named_modules() raises:
    var m: OldMobius = mobius(Q(1, 1), Q(2, 1), Q(0, 1), Q(1, 1))
    var old_m: Mobius = old_mobius(Q(1, 1), Q(2, 1), Q(0, 1), Q(1, 1))
    var n: OldMobiusOver[QField] = mobius_compose(m, old_m)
    var old_n: MobiusOver[QField] = old_mobius_compose(old_m, m)
    var t = p1_affine(Q(3, 1))
    assert_true(p1_equal(mobius_apply(n, t), old_mobius_apply(old_n, t)))
    assert_true(p1_equal(mobius_apply(m, p1_infinity()), old_mobius_apply(old_m, p1_infinity())))
    for k in range(-3, 6):
        assert_true(spread_polynomial(k, Q(1, 4)).eq(old_spread_polynomial(k, Q(1, 4))))


def main() raises:
    test_qpoly_named_modules()
    print("[PASS]", "test_qpoly_named_modules")
    test_integer_matrix_and_module_named_modules()
    print("[PASS]", "test_integer_matrix_and_module_named_modules")
    test_rational_dynamics_named_modules()
    print("[PASS]", "test_rational_dynamics_named_modules")
    test_krawczyk_named_module()
    print("[PASS]", "test_krawczyk_named_module")
    test_finite_polynomial_named_modules()
    print("[PASS]", "test_finite_polynomial_named_modules")
    test_finite_automata_named_modules()
    print("[PASS]", "test_finite_automata_named_modules")
    test_projective_limits_named_modules()
    print("[PASS]", "test_projective_limits_named_modules")
    print("7 named-module re-export tests passed.")
