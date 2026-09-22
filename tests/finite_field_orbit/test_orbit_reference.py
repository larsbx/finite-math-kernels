"""Laws of the ``orbit-census-v1`` reference and drift of its golden vectors."""

from __future__ import annotations

import random
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from orbit_census_reference import (  # noqa: E402
    EMPTY, FIELDS, Agg, Block, census, decode, digest, encode, leaf, merge, replay_verdict, rho, tamper, trajectory,
    tree_census,
)

VECTORS = ROOT / "fixtures" / "orbit_census_v1.txt"
SMALL_PRIMES = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 101)


def vector_cases(kind: str) -> list[list[str]]:
    rows = [line.split("\t") for line in VECTORS.read_text(encoding="utf-8").splitlines() if not line.startswith("#")]
    return [row[1:] for row in rows if row[0] == kind]


def by_definition(p: int, c: int, cap: int, seed: int) -> tuple[int, int] | None:
    """Section 3.2 read literally: the least j whose term already occurred."""
    xs = trajectory(p, c, seed, p)
    j = next(j for j in range(1, p + 1) if xs[j] in xs[:j])
    return (xs.index(xs[j]), j - xs.index(xs[j])) if j <= cap else None


def test_hand_computed_orbit():
    # f(x) = x^2 + 3 on F_7: 0 -> 3 -> 5 -> 0, and 1 -> 4 -> 5 -> 0 -> 3 -> 5.
    assert rho(7, 3, 7, 0) == (0, 3)
    assert rho(7, 3, 7, 1) == (2, 3)
    assert rho(7, 3, 4, 1) is None and rho(7, 3, 5, 1) == (2, 3)


@pytest.mark.parametrize("p", SMALL_PRIMES)
def test_rho_is_the_definition(p):
    for c in range(p):
        for cap in (0, 1, 2, p // 2, p):
            assert all(rho(p, c, cap, s) == by_definition(p, c, cap, s) for s in range(p))


def test_cap_at_least_p_resolves_everything_and_cap_zero_nothing():
    for p in SMALL_PRIMES:
        assert census(Block(p, 1, p, 0, p)).resolved == p
        assert census(Block(p, 1, 0, 0, p)) == Agg(n=p)


def random_aggs(rng: random.Random, k: int) -> list[Agg]:
    p = rng.choice(SMALL_PRIMES)
    b = Block(p, rng.randrange(p), rng.randrange(p + 1), 0, p)
    return [leaf(b, rng.randrange(p)) for _ in range(k)]


def test_monoid_laws():
    rng = random.Random(20260922)
    for _ in range(500):
        a, b, c = random_aggs(rng, 3)
        assert merge(EMPTY, a) == a == merge(a, EMPTY)
        assert merge(a, merge(b, c)) == merge(merge(a, b), c)
        assert merge(a, b) == merge(b, a)


def test_partition_invariance():
    rng = random.Random(4093)
    for _ in range(200):
        p = rng.choice((101, 257, 1009))
        b = Block(p, rng.randrange(p), rng.randrange(p + 1), 0, p)
        cuts = [rng.randrange(p + 1) for _ in range(rng.randrange(8))]
        assert tree_census(b, cuts) == census(b)


def test_witness_is_the_longest_rho_with_smallest_seed():
    b = Block(101, 7, 101, 0, 101)
    a = census(b)
    rhos = {s: rho(b.p, b.c, b.cap, s) for s in range(b.lo, b.hi)}
    best = max(mu + lam for mu, lam in rhos.values())
    seed = min(s for s, (mu, lam) in rhos.items() if mu + lam == best)
    assert (a.has_w, a.w_seed, (a.w_mu, a.w_lambda)) == (1, seed, rhos[seed])


def test_census_vectors_round_trip_and_replay():
    for (line,) in vector_cases("census"):
        b, a = decode(line)
        assert encode(b, a) == line
        assert census(b) == a
        assert replay_verdict(b, a) == "accepted"
        assert a.sum_mu + a.sum_lambda < 2**24 or b.p > 4093


def test_tampered_vectors_name_the_first_differing_field():
    rows = vector_cases("tampered")
    assert {reason for reason, _ in rows} == {f"mismatch:{f}" for f in FIELDS}
    for reason, line in rows:
        assert replay_verdict(*decode(line)) == reason


def test_malformed_requests_and_lines_are_refused_by_field():
    for field, request in vector_cases("request-malformed"):
        with pytest.raises(ValueError, match=f"^malformed:{field}$"):
            census(Block(*map(int, request.split(" "))))
    for field, line in vector_cases("decode-malformed"):
        with pytest.raises(ValueError, match=f"^malformed:{field}$"):
            decode(line)


def test_tamper_changes_exactly_one_field():
    a = census(Block(7, 3, 7, 0, 7))
    assert all(sum(x != y for x, y in zip(vars(tamper(a, f)).values(), vars(a).values())) == 1 for f in FIELDS)


def test_digest_is_over_newline_terminated_lines():
    assert digest([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    assert digest(["a", "b"]) != digest(["ab"])


def test_vectors_have_not_drifted():
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "make_orbit_vectors.py"), "--check"],
                            capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
