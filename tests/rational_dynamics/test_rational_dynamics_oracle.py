"""The vendorable Python ``rational_dynamics_py`` package (oracles/rational_dynamics_py).

Golden values and invariants are ported from the consumers the package
replaces, each cited where it is used: larsbx/mandelbrot-bulbs-and-ford-circles-research
tests/test_cf.py, test_wake.py, test_cycles.py, test_flank_lemma.py and
test_spectral.py; larsbx/math-vizops tests/test_atlas.py; and
larsbx/finite-mandelbrot-research reference/python/c1/misiurewicz_catalogue_reference.py
(its ``main`` regression) and reference/python/atlas/structure_names_reference.py.
Where a consumer computed the same object by a different algorithm, that
algorithm is reproduced here as an independent oracle rather than trusted.
"""

from __future__ import annotations

import random
from fractions import Fraction as F
from math import gcd

import pytest

import rational_dynamics_py as rd
from rational_dynamics_py import (
    address,
    binary_block,
    binary_digits,
    binary_expansion,
    continued_fraction,
    convergents,
    dedekind_sum,
    doubling_orbit,
    exact_type,
    farey_parents,
    farey_sequence,
    from_continued_fraction,
    mechanical_word,
    mediant,
    moebius,
    order_of_two,
    period,
    preperiod,
    ramanujan_sum,
    rotation_cycle,
    rotation_number,
    signed_mod_inverse,
    units,
    wake,
)

PAIRS_16 = [(p, q) for q in range(2, 17) for p in units(q)]
PAIRS_60 = [(p, q) for q in range(3, 61) for p in units(q)]


def double(t: F) -> F:
    return 2 * t % 1


# --- one definition ------------------------------------------------------------


def test_the_r1_reference_is_a_re_export_not_a_copy():
    import rational_dynamics_reference as ref

    assert ref.address is rd.address and ref.Address is rd.Address
    assert ref.convergents is rd.convergents and ref.farey_adjacent is rd.farey_adjacent


def test_the_package_is_standard_library_only():
    import ast
    from pathlib import Path

    allowed = {"__future__", "collections", "dataclasses", "fractions", "math"}
    for path in Path(rd.__file__).parent.glob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                assert {a.name.split(".")[0] for a in node.names} <= allowed, path
            elif isinstance(node, ast.ImportFrom) and node.level == 0:
                assert node.module.split(".")[0] in allowed, (path, node.module)


# --- continued fractions (bulbs tests/test_cf.py) ---------------------------------


def test_continued_fraction_round_trip():
    for q in range(2, 60):
        for p in units(q):
            a = continued_fraction(address(p, q))
            assert from_continued_fraction(a) == F(p, q)
            assert len(a) == 1 or a[-1] >= 2


def test_from_continued_fraction_accepts_non_canonical_and_negative_head():
    assert from_continued_fraction([0, 1, 1]) == F(1, 2)
    assert from_continued_fraction([3]) == 3
    assert from_continued_fraction([-2, 1, 3]) == F(-5, 4)
    assert from_continued_fraction([1, 2, 2, 2, 2]) == F(41, 29)


@pytest.mark.parametrize("bad", [[], [1, 0], [0, 2, -1]])
def test_from_continued_fraction_refuses_undefined_expansions(bad):
    with pytest.raises(ValueError):
        from_continued_fraction(bad)


def test_x_star_is_the_previous_convergent_denominator():
    """bulbs: x*(p/q) = ||p^{-1} mod q|| / q = q_{n-1} / q."""
    for q in range(2, 60):
        for p in units(q):
            conv = convergents(address(p, q))
            assert conv[-1].denominator == q
            assert abs(signed_mod_inverse(address(p, q))) == conv[-2].denominator


# --- units, mediants, Farey ----------------------------------------------------------


def test_units_count_euler_phi_and_match_bulbs_from_two_on():
    phi = {1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 2, 7: 6, 8: 4, 9: 6, 10: 4, 12: 4, 30: 8}
    for q, value in phi.items():
        assert len(units(q)) == value
    assert units(1) == (0,)
    for q in range(2, 50):
        assert units(q) == tuple(p for p in range(1, q) if gcd(p, q) == 1)
    with pytest.raises(ValueError):
        units(0)


def test_mediant_is_taken_in_lowest_terms():
    assert mediant(F(1, 3), F(1, 2)) == F(2, 5)
    assert mediant(F(2, 4), F(1, 1)) == F(2, 3)
    assert mediant(address(0, 1), 1) == F(1, 2)
    with pytest.raises(TypeError):
        mediant(0.5, F(1))


def test_farey_sequence_full_and_interior():
    assert farey_sequence(1) == (F(0), F(1))
    assert farey_sequence(1, interior=True) == ()
    assert farey_sequence(5) == tuple(
        F(x) for x in ("0", "1/5", "1/4", "1/3", "2/5", "1/2", "3/5", "2/3", "3/4", "4/5", "1")
    )
    for n in range(1, 25):
        brute = tuple(sorted({F(p, q) for q in range(1, n + 1) for p in range(q + 1)}))
        assert farey_sequence(n) == brute
        # bulbs wake.farey(n): the interior fractions only.
        assert farey_sequence(n, interior=True) == tuple(
            sorted({F(p, q) for q in range(2, n + 1) for p in range(1, q)})
        )
        full = farey_sequence(n)
        assert all(b.numerator * a.denominator - a.numerator * b.denominator == 1 for a, b in zip(full, full[1:]))
    with pytest.raises(ValueError):
        farey_sequence(0)


def mandelbrot_farey_neighbours(r: F) -> tuple[F | None, F | None]:
    """finite-mandelbrot-research structure_names_reference.farey_neighbours, verbatim."""
    p, q = r.numerator, r.denominator
    below = next((F(a, b) for b in range(1, q) for a in range(b + 1) if p * b - a * q == 1), None)
    above = next((F(a, b) for b in range(1, q + 1) for a in range(b + 1) if a * q - p * b == 1), None)
    return (below if r > 0 else None, above if r < 1 else None)


def test_farey_parents_agree_with_the_mandelbrot_search_inside_the_unit_interval():
    for r in farey_sequence(40, interior=True):
        left, right = farey_parents(r)
        assert (left, right) == mandelbrot_farey_neighbours(r)
        assert left < r < right and mediant(left, right) == r
        assert left.denominator + right.denominator == r.denominator


def test_farey_parents_refuse_the_boundary_where_mandelbrot_answered_none():
    assert mandelbrot_farey_neighbours(F(0)) == (None, F(1))
    assert mandelbrot_farey_neighbours(F(1)) == (None, None)
    for r in (F(0), F(1), F(3, 2), F(-1, 2)):
        with pytest.raises(ValueError):
            farey_parents(r)


# --- preperiod and period ----------------------------------------------------------


def orbit_type(t: F) -> tuple[int, int]:
    """Mandelbrot structure_names_reference.exact_type: the orbit's first repeat."""
    seen: dict[F, int] = {}
    point, step = t % 1, 0
    while point not in seen:
        seen[point] = step
        point, step = double(point), step + 1
    return seen[point], step - seen[point]


def test_exact_type_agrees_with_the_first_repeat_of_the_orbit():
    for q in range(1, 200):
        for p in range(q):
            assert exact_type(F(p, q)) == orbit_type(F(p, q)), (p, q)


@pytest.mark.parametrize(
    "theta, expected",
    [(F(1, 7), (0, 3)), (F(1, 3), (0, 2)), (F(1, 2), (1, 1)), (F(0), (0, 1)), (F(1, 6), (1, 2)),
     (F(1, 58), (1, 28)), (F(1, 50), (1, 20)), (F(9, 7), (0, 3)), (F(-1, 3), (0, 2))],
)
def test_pinned_types(theta, expected):
    """vizops test_period_under_doubling ((1/7, 3), (1/3, 2)) and the Mandelbrot catalogue's examples."""
    assert exact_type(theta) == expected


def test_vizops_period_of_is_the_periodic_case_of_period():
    """vizops answered None for 1/2 (preperiodic); here that is preperiod > 0."""
    assert preperiod(F(1, 2)) == 1 and period(F(1, 2)) == 1


def test_the_period_has_no_cap():
    """vizops capped its search at 32; ord_m(2) is exact at any size."""
    assert period(F(1, 2**61 - 1)) == 61
    assert period(F(1, 2**127 - 1)) == 127
    assert period(F(3, 2**89 - 1)) == 89
    assert order_of_two(10007) == 5003  # past the direct-powering threshold
    assert period(F(5, 2**7 * 10007)) == 5003 and preperiod(F(5, 2**7 * 10007)) == 7
    rng = random.Random(0x0D0B11)
    for _ in range(40):
        m = rng.randrange(3, 10**6, 2)
        k, power = 1, 2 % m
        while power != 1:
            power, k = power * 2 % m, k + 1
        assert order_of_two(m) == k, m


def test_order_of_two_refuses_a_non_unit():
    for m in (0, -3, 2, 12):
        with pytest.raises(ValueError):
            order_of_two(m)


def test_floats_are_refused_not_converted():
    with pytest.raises(TypeError):
        period(0.25)


def catalogue_count(l: int, k: int) -> int:
    """Mandelbrot misiurewicz_catalogue_reference: 2^(l-1) sum_{d|k} mu(k/d)(2^d - 1)."""
    return (1 << (l - 1)) * sum(moebius(k // d) * ((1 << d) - 1) for d in range(1, k + 1) if k % d == 0)


def test_the_misiurewicz_catalogue_count_identity():
    """Mandelbrot's round-one angle-count regression, for every type with 1 <= l, k <= 7."""
    for l in range(1, 8):
        for k in range(1, 8):
            den = (1 << l) * ((1 << k) - 1)
            found = [num for num in range(den) if exact_type(F(num, den)) == (l, k)]
            assert len(found) == catalogue_count(l, k), (l, k)
    catalogue = lambda l, k: [n for n in range((1 << l) * ((1 << k) - 1)) if exact_type(F(n, (1 << l) * ((1 << k) - 1))) == (l, k)]  # noqa: E731
    assert catalogue(1, 1) == [1] and catalogue(2, 1) == [1, 3]
    assert catalogue(1, 2) == [1, 5] and catalogue(1, 3) == [1, 3, 5, 9, 11, 13]


# --- binary expansions -------------------------------------------------------------


def test_binary_expansion_is_minimal_and_reproduces_the_angle():
    for q in range(1, 120):
        for p in range(q):
            t = F(p, q)
            prefix, block = binary_expansion(t)
            assert (len(prefix), len(block)) == exact_type(t)
            l, k = len(prefix), len(block)
            head = F(int(prefix, 2) if prefix else 0, 2**l)
            tail = F(int(block, 2), (2**k - 1) * 2**l)
            assert head + tail == t
    assert binary_expansion(F(0)) == ("", "0")
    assert binary_expansion(F(1, 2)) == ("1", "0")
    assert binary_expansion(F(1, 3)) == ("", "01")
    assert binary_expansion(F(1, 6)) == ("0", "01")
    assert binary_block(F(9, 31)) == "01001"
    assert binary_digits(F(1, 7), 7) == "0010010"
    assert binary_digits(F(3, 4), 4) == "1100"


# --- rotation cycles and wakes (bulbs tests/test_wake.py, test_flank_lemma.py) --------


def bulbs_rotation_cycle(p: int, q: int) -> tuple[F, ...]:
    """bulbs wake.rotation_cycle: the doubling orbit of c(0), sorted."""
    bits = "".join("1" if k * p % q >= q - p else "0" for k in range(q))
    orbit = [F(int(bits, 2), 2**q - 1)]
    for _ in range(q - 1):
        orbit.append(double(orbit[-1]))
    return tuple(sorted(orbit))


def bulbs_wake(p: int, q: int) -> tuple[F, F]:
    cycle = bulbs_rotation_cycle(p, q)
    return min(zip(cycle, cycle[1:]), key=lambda pair: pair[1] - pair[0])


def mandelbrot_rotation_angles(r: F) -> tuple[F, F]:
    """structure_names_reference.rotation_angles: every period-q cycle enumerated."""
    p, q = r.numerator, r.denominator
    den = 2**q - 1
    turn = lambda t, i: t * 2**i % 1  # noqa: E731
    cycles = {tuple(sorted(turn(F(k, den), i) for i in range(q))) for k in range(1, den)}
    rotating = [c for c in cycles if len(set(c)) == q and all(double(c[i]) == c[(i + p) % q] for i in range(q))]
    assert len(rotating) == 1
    cyc = rotating[0]
    gaps = sorted(((cyc[(i + 1) % q] - cyc[i]) % 1, i) for i in range(q))
    i = gaps[0][1]
    return cyc[i], cyc[(i + 1) % q]


@pytest.mark.parametrize(
    "p,q,expected",
    [(1, 2, (F(1, 3), F(2, 3))), (1, 3, (F(1, 7), F(2, 7))), (2, 3, (F(5, 7), F(6, 7))),
     (1, 4, (F(1, 15), F(2, 15))), (2, 5, (F(9, 31), F(10, 31)))],
)
def test_known_wakes(p, q, expected):
    assert wake(p, q) == expected


@pytest.mark.parametrize("p,q", PAIRS_16)
def test_rotation_cycle_and_characteristic_arc(p, q):
    cycle = rotation_cycle(p, q)
    lo, hi = wake(p, q)
    assert cycle == bulbs_rotation_cycle(p, q)
    assert (lo, hi) == bulbs_wake(p, q)
    assert len(set(cycle)) == q and all((2**q - 1) % x.denominator == 0 for x in cycle)
    assert all(double(x) == cycle[(i + p) % q] for i, x in enumerate(cycle))
    assert hi - lo == F(1, 2**q - 1)
    assert 1 + cycle[0] - cycle[-1] > hi - lo
    assert wake(q - p, q) == (1 - hi, 1 - lo)
    assert rotation_number([int(x * (2**q - 1)) for x in cycle], 2**q - 1) == F(p, q)


def test_wake_agrees_with_mandelbrot_enumeration_of_every_cycle():
    for q in range(2, 11):
        for p in units(q):
            assert wake(p, q) == mandelbrot_rotation_angles(F(p, q)), (p, q)


@pytest.mark.parametrize("n", [5, 8, 12])
def test_wakes_are_disjoint_and_ordered_like_farey_fractions(n):
    wakes = [wake(x.numerator, x.denominator) for x in farey_sequence(n, interior=True)]
    assert all(a[1] < b[0] for a, b in zip(wakes, wakes[1:]))


@pytest.mark.parametrize("n", [4, 7, 10])
def test_mediant_wake_sits_in_the_gap_between_farey_neighbours(n):
    seq = farey_sequence(n, interior=True)
    for a, b in zip(seq, seq[1:]):
        m = mediant(a, b)
        assert wake(a.numerator, a.denominator)[1] < wake(m.numerator, m.denominator)[0]
        assert wake(m.numerator, m.denominator)[1] < wake(b.numerator, b.denominator)[0]


def test_out_of_domain_rotation_number_is_refused():
    for p, q in [(0, 3), (3, 3), (2, 4), (-1, 5)]:
        with pytest.raises(ValueError):
            rotation_cycle(p, q)
        with pytest.raises(ValueError):
            wake(p, q)
        with pytest.raises(ValueError):
            mechanical_word(p, q, 0)


@pytest.mark.parametrize("p,q", PAIRS_60)
def test_flank_lemma_steps_on_mechanical_words(p, q):
    """bulbs test_flank_lemma: steps i, iii, v and P7, in integers for q <= 60."""
    big = 2**q - 1
    shift = lambda x, s: x * pow(2, s, big) % big  # noqa: E731
    pbar = pow(p, -1, q)
    words = [mechanical_word(p, q, r) for r in range(q)]
    for r in range(q):
        assert shift(words[r], 1) == words[(r + p) % q]
        assert shift(words[r], pbar) == words[(r + 1) % q]
    assert all(x < y for x, y in zip(words, words[1:]))
    assert [r for r in range(q - 1) if words[r + 1] - words[r] == 1] == [p - 1]
    x = (words[(p - 2) % q] + 1) % big
    y = (words[(p + 1) % q] - 1) % big
    assert y == shift(x, pbar)
    assert len(doubling_orbit(x, big)) == q and y in doubling_orbit(x, big)
    if p == 1:
        assert words == [2**r for r in range(q)]


# --- doubling orbits and rotation numbers (bulbs tests/test_cycles.py) -----------------


def test_rotation_number_of_an_angle_orbit():
    assert rotation_number((1, 2, 4), 7) == F(1, 3)
    assert rotation_number((3, 6, 12, 9), 15) is None
    assert rotation_number((0,), 7) == 0


@pytest.mark.parametrize("angles, modulus", [((), 7), ((1, 2), 7), ((1, 8), 7), ((1, 2, 4), 0)])
def test_rotation_number_refuses_a_set_it_cannot_read(angles, modulus):
    with pytest.raises(ValueError):
        rotation_number(angles, modulus)


def test_every_rotation_number_of_denominator_seven_occurs_once():
    """bulbs test_rotation_cycles_of_the_same_denominator_are_all_present, without the floats."""
    big, seen, found = 2**7 - 1, set(), []
    for j in range(big):
        if j in seen:
            continue
        orbit = doubling_orbit(j, big)
        seen.update(orbit)
        rho = rotation_number(orbit, big)
        if len(orbit) == 7 and rho is not None:
            found.append(rho)
    assert sorted(found) == [F(k, 7) for k in range(1, 7)]


def test_doubling_orbit_reduces_and_refuses_even_moduli():
    assert doubling_orbit(1, 7) == (1, 2, 4)
    assert doubling_orbit(8, 7) == (1, 2, 4)
    assert doubling_orbit(0, 1) == (0,)
    assert len(doubling_orbit(2 ** 62 + 1, 2**64 - 1)) == 64
    for modulus in (0, 8, -7):
        with pytest.raises(ValueError):
            doubling_orbit(1, modulus)


# --- Moebius, Dedekind, Ramanujan ----------------------------------------------------


def test_moebius_values():
    assert [moebius(n) for n in range(1, 21)] == [1, -1, -1, 0, -1, 1, -1, 0, 0, 1, -1, 0, -1, 1, 1, 0, -1, 0, -1, 0]
    assert moebius(2 * 3 * 5 * 7 * 11) == -1 and moebius(10007**2) == 0
    for n in (0, -1):
        with pytest.raises(ValueError):
            moebius(n)


def sawtooth(x: F) -> F:
    return F(0) if x.denominator == 1 else x - (x.numerator // x.denominator) - F(1, 2)


def dedekind_by_definition(h: int, k: int) -> F:
    return sum((sawtooth(F(r, k)) * sawtooth(F(h * r, k)) for r in range(1, k)), F(0))


def test_dedekind_sum_matches_its_definition_and_reciprocity():
    for k in range(1, 40):
        for h in range(-k, 2 * k + 1):
            assert dedekind_sum(h, k) == dedekind_by_definition(h, k), (h, k)
    for k in range(2, 60):
        for h in range(1, 60):
            if gcd(h, k) == 1:
                assert dedekind_sum(h, k) + dedekind_sum(k, h) == F(h * h + k * k + 1, 12 * h * k) - F(1, 4)
        assert dedekind_sum(1, k) == F((k - 1) * (k - 2), 12 * k)
    assert dedekind_sum(1, 1009) == F(1008 * 1007, 12 * 1009)
    with pytest.raises(ValueError):
        dedekind_sum(1, 0)


def test_dedekind_sum_divides_out_a_common_factor():
    """bulbs bridges_spike.dedekind ran reciprocity without reducing and gave
    s(2, 4) = -1/32 and s(2, 6) = 5/144; the definition gives s(1, 2) and s(1, 3)."""
    assert dedekind_sum(2, 4) == dedekind_by_definition(2, 4) == 0
    assert dedekind_sum(2, 6) == dedekind_by_definition(2, 6) == dedekind_sum(1, 3) == F(1, 18)


def test_ramanujan_sum_values():
    """bulbs test_ramanujan_sum_values: c_q(1) = mu(q), c_q(q) = c_q(2q) = phi(q), q <= 30."""
    for q in range(1, 31):
        phi = len(units(q))
        assert ramanujan_sum(q, 1) == moebius(q)
        assert ramanujan_sum(q, q) == ramanujan_sum(q, 2 * q) == ramanujan_sum(q, 0) == phi


def test_ramanujan_sum_is_von_sterneck():
    """c_q(m) = mu(q/g) phi(q) / phi(q/g), g = gcd(q, m): an independent closed form."""
    phi = lambda n: len(units(n))  # noqa: E731
    for q in range(1, 40):
        for m in range(-40, 41):
            g = gcd(q, m)
            assert ramanujan_sum(q, m) * phi(q // g) == moebius(q // g) * phi(q)
    with pytest.raises(ValueError):
        ramanujan_sum(0, 1)


# --- the integer domain is enforced, never coerced ---------------------------------------


@pytest.mark.parametrize("call", [
    lambda: rd.moebius(4.5), lambda: rd.moebius(3.0), lambda: rd.moebius(True),
    lambda: rd.dedekind_sum(1.0, 3), lambda: rd.dedekind_sum(1, 3.0),
    lambda: rd.ramanujan_sum(3.0, 1), lambda: rd.ramanujan_sum(3, 1.5),
    lambda: rd.units(4.0), lambda: rd.farey_sequence(3.0), lambda: rd.order_of_two(3.0),
    lambda: rd.binary_digits(F(1, 3), 2.0), lambda: rd.mechanical_word(1, 3, 0.0),
    lambda: rd.rotation_cycle(1.0, 3), lambda: rd.wake(1, 3.0), lambda: rd.doubling_orbit(1, 7.0),
    lambda: rd.rotation_number([1.0, 2], 7), lambda: rd.rotation_number([1, 2], 7.0),
    lambda: rd.address(1.0, 2), lambda: rd.address(1, True),
])
def test_a_non_integer_where_an_integer_is_required_is_refused(call):
    with pytest.raises(TypeError):
        call()


@pytest.mark.parametrize("bad", [4.5, 3.0, True, False, F(3), "3", None])
@pytest.mark.parametrize("field", ["numerator", "denominator"])
def test_direct_address_construction_refuses_non_integer_fields(bad, field):
    fields = {"numerator": 1, "denominator": 3, field: bad}
    with pytest.raises(TypeError):
        rd.Address(**fields)


def test_direct_integer_addresses_keep_exact_arithmetic():
    value = rd.Address(1, 3)
    assert rd.continued_fraction(value) == (0, 3)
    assert rd.farey_determinant(value, rd.Address(1, 2)) == -1


@pytest.mark.parametrize("fields", [(1, 0), (0, 0), (1, -2), (-1, 2)])
def test_direct_address_construction_enforces_the_factory_domain(fields):
    with pytest.raises(ValueError):
        rd.Address(*fields)
    with pytest.raises(ValueError):
        rd.address(*fields)


@pytest.mark.parametrize("fields", [(2, 4), (0, 17), (6, 3)])
def test_direct_address_construction_reduces_like_the_factory(fields):
    value = rd.Address(*fields)
    assert value == rd.address(*fields)
    assert (value.numerator, value.denominator) == (F(*fields).numerator, F(*fields).denominator)
    assert rd.continued_fraction(value) == rd.continued_fraction(rd.address(*fields))


def test_direct_unreduced_address_has_the_correct_farey_predicate():
    assert rd.farey_adjacent(rd.Address(2, 4), rd.Address(1, 3))
