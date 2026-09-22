"""The spec oracle for u32-prime-field-orbit-v1 obeys the contract's laws."""

from __future__ import annotations

import itertools
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "benchmarks" / "frontier" / "ff_orbit_census"))

import reference as ref  # noqa: E402

SMOKE = ref.Corpus(p=101, length=6, seed=(-1, 2, 2, 3), sample_stride=97)


def test_word_count_is_four_times_powers_of_three():
    assert [ref.word_count(n) for n in (1, 2, 3, 15)] == [4, 12, 36, 4 * 3**14]


@pytest.mark.parametrize("length", [1, 2, 3, 5])
def test_decoding_is_a_bijection_onto_reduced_words(length):
    words = [ref.decode(w, length) for w in range(ref.word_count(length))]
    reduced = {t for t in itertools.product(range(4), repeat=length) if all(a != b for a, b in zip(t, t[1:]))}
    assert set(words) == reduced and len(words) == len(reduced)


def test_generators_on_the_root_quadruple():
    """(-1, 2, 2, 3): S0 -> 15, S1 and S2 -> 6, S3 fixes it (2 * 3 - 3 = 3)."""
    v = ref.reduce((-1, 2, 2, 3), 101)
    assert [ref.step(v, i, 101) for i in range(4)] == [(15, 2, 2, 3), (100, 6, 2, 3), (100, 2, 6, 3), v]


def test_generators_are_involutions_preserving_the_descartes_form():
    p = 4294967291
    v = ref.reduce((-1, 2, 2, 3), p)
    for i in range(4):
        assert ref.step(ref.step(v, i, p), i, p) == v
        assert ref.quadric(ref.step(v, i, p), p) == ref.quadric(v, p)
    assert ref.step((p - 1, p - 1, p - 1, p - 1), 0, p) == (5 * (p - 1) % p, p - 1, p - 1, p - 1)


def test_mix32_is_pinned():
    assert ref.mix32(0) == 0
    assert [ref.mix32(x) for x in (1, 2, 0xDEADBEEF)] == [1753845952, 3507691905, 3861431939]


def test_record_is_partition_invariant():
    whole = ref.census(SMOKE)
    n = ref.word_count(SMOKE.length)
    parts = [ref.census_range(SMOKE, lo, min(lo + 100, n)) for lo in range(0, n, 100)]
    assert ref.merge(parts) == whole


def test_record_text_shape():
    lines = ref.render(ref.census(SMOKE)).decode("ascii").splitlines()
    assert lines[:4] == ["contract u32-prime-field-orbit-v1", "p 101", "length 6", "words 972"]
    assert [line.split()[0] for line in lines[4:8]] == ["zero_hits", "first_zero", "hash_sum", "hash_xor"]
    assert [int(line.split()[1]) for line in lines[8:]] == list(range(0, 972, 97))


def test_replay_accepts_the_reference_and_rejects_tampering():
    text = ref.render(ref.census(SMOKE))
    assert ref.replay(SMOKE, text, full=True) == []
    tampered = text.replace(b"sample 97 ", b"sample 98 ")
    assert ref.replay(SMOKE, tampered, full=False) != []
    lines = text.split(b"\n")
    lines[6] = b"hash_sum 0"
    assert ref.replay(SMOKE, b"\n".join(lines), full=False) == []
    assert ref.replay(SMOKE, b"\n".join(lines), full=True) != []


def test_corpus_identity_is_canonical_json():
    assert ref.Corpus.from_mapping(ref.load_corpora()["smoke"]) == SMOKE
    assert len(SMOKE.sha256()) == 64 and SMOKE.sha256() != ref.Corpus(101, 6, (-1, 2, 2, 3), 98).sha256()
