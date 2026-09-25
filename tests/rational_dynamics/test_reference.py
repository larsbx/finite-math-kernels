from __future__ import annotations

from math import gcd
import random

import pytest

from tools.rational_dynamics_reference import (
    ReducedFraction,
    continued_fraction,
    convergents,
    double_mod_one,
    farey_adjacent,
    farey_determinant,
    mod_inverse,
    signed_mod_inverse,
)


def test_pinned_r1_vectors():
    assert ReducedFraction.make(2, 4) == ReducedFraction(1, 2)
    assert double_mod_one(ReducedFraction.make(1, 3)) == ReducedFraction(2, 3)
    assert double_mod_one(ReducedFraction.make(2, 3)) == ReducedFraction(1, 3)
    assert double_mod_one(ReducedFraction.make(3, 2)) == ReducedFraction(0, 1)
    assert mod_inverse(ReducedFraction.make(2, 5)) == ReducedFraction(3, 5)
    assert signed_mod_inverse(ReducedFraction.make(3, 7)) == (-2, 7)
    assert continued_fraction(ReducedFraction.make(3, 7)) == (0, 2, 3)
    assert convergents(ReducedFraction.make(3, 7)) == ((0, 1), (1, 2), (3, 7))
    assert farey_determinant(ReducedFraction.make(1, 3), ReducedFraction.make(2, 5)) == -1
    assert farey_adjacent(ReducedFraction.make(1, 3), ReducedFraction.make(2, 5))


@pytest.mark.parametrize("bad", [(-1, 3), (1, 0), (1, -3)])
def test_boundary_rejects_malformed_fractions(bad):
    with pytest.raises(ValueError):
        ReducedFraction.make(*bad)


def test_zero_residue_has_no_modular_inverse():
    with pytest.raises(ValueError):
        mod_inverse(ReducedFraction.make(0, 1))
    with pytest.raises(ValueError):
        mod_inverse(ReducedFraction.make(2, 1))


def test_random_reduced_fractions_obey_all_r1_invariants():
    rng = random.Random(0x524154494F4E414C)
    cases: list[tuple[int, int]] = []
    while len(cases) < 500:
        q = rng.randint(2, 5000)
        p = rng.randint(1, q - 1)
        if gcd(p, q) == 1:
            cases.append((p, q))

    for p, q in cases:
        value = ReducedFraction.make(p, q)
        inverse = mod_inverse(value)
        assert (p * inverse.num) % q == 1

        centered, den = signed_mod_inverse(value)
        assert den == q
        assert -q / 2 < centered <= q / 2
        assert (p * centered) % q == 1

        expansion = continued_fraction(value)
        conv = convergents(value)
        assert conv[-1] == (p, q)
        assert expansion[-1] >= 2

        # For 0 < p < q in canonical continued-fraction form, the denominator
        # of the penultimate convergent is the magnitude of the centered
        # inverse. This is the arithmetic identity the Ford-bulb project uses
        # for x*; this test supplies evidence for the shared finite kernel only.
        assert len(conv) >= 2
        assert conv[-2][1] == abs(centered)


def test_farey_mediant_neighbors_are_adjacent():
    left = ReducedFraction.make(2, 5)
    right = ReducedFraction.make(3, 7)
    assert farey_adjacent(left, right)
    mediant = ReducedFraction.make(left.num + right.num, left.den + right.den)
    assert farey_adjacent(left, mediant)
    assert farey_adjacent(mediant, right)
