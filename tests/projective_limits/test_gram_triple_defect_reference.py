"""Check unrestricted triple spread against independent Gram-side arithmetic.

All field computations are exact. Finite test samples certify the bounded
implementation, NOT a symbolic identity over arbitrary fields or novelty.
"""
from itertools import product

from reference.gram_geometry_reference import (
    gram3, gram_predicted_defect, norm, planar_defect, rank_le_two,
    spread, unrestricted_defect,
)


def add(p, *vs):
    return tuple(sum(v[i] for v in vs) % p for i in range(8))


def scale(p, c, x):
    return tuple(c * a % p for a in x)


def axis(i):
    return tuple(int(i == j) for j in range(8))


def norm_one(p, i):
    return add(p, axis(i), scale(p, pow(2, -1, p), axis(i + 4)))


def test_gram_prediction_for_all_selected_nonnul_triples():
    for p in (3, 5, 7):
        x, y, z = (norm_one(p, i) for i in range(3))
        vectors = (
            x, y, z,
            add(p, x, axis(1)),
            add(p, scale(p, -1, x), scale(p, 2, axis(5))),
            add(p, x, y, axis(2)),
            add(p, x, y),
            add(p, y, z),
        )
        checked = 0
        for a, b, c in product(vectors, repeat=3):
            left = unrestricted_defect(p, a, b, c)
            right = gram_predicted_defect(p, a, b, c)
            assert left == right
            if left is not None:
                checked += 1
                # Every rank <= 2 triple is automatically Gram-null.
                if rank_le_two(p, a, b, c):
                    assert left == 0
                    assert planar_defect(p, a, b, c) == 0
        assert checked > 150


def test_nonplanar_zero_defect_is_not_the_planar_identity():
    for p in (3, 5, 7):
        x = norm_one(p, 0)
        y = add(p, x, axis(1))
        z = add(p, scale(p, -1, x), scale(p, 2, axis(5)))
        assert tuple(norm(p, v) for v in (x, y, z)) == (1, 1, 1)
        assert not rank_le_two(p, x, y, z)
        assert gram3(p, x, y, z) == (-4) % p
        assert (spread(p, x, y), spread(p, y, z), spread(p, z, x)) == (0, 0, 0)
        assert unrestricted_defect(p, x, y, z) == 0
        assert gram_predicted_defect(p, x, y, z) == 0
        assert planar_defect(p, x, y, z) is None


def test_orthogonal_nonplanar_and_null_domain():
    for p in (3, 5, 7):
        x, y, z = (norm_one(p, i) for i in range(3))
        assert not rank_le_two(p, x, y, z)
        assert unrestricted_defect(p, x, y, z) == p - 1
        assert gram_predicted_defect(p, x, y, z) == p - 1
        assert unrestricted_defect(p, axis(0), y, z) is None
        assert gram_predicted_defect(p, axis(0), y, z) is None
