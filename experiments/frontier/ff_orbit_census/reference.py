#!/usr/bin/env python3
"""Spec oracle for ``u32-prime-field-orbit-v1`` (see ``CONTRACT.md`` here).

Written for clarity, not speed: it is the executable reading of the contract
and the replay predicate, never a timed baseline.

Usage:
    reference.py <corpus-name>                         print the canonical record
    reference.py --kernel <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>
                                                       the kernel interface, for harness tests
"""

from __future__ import annotations

import hashlib
import json
import sys
import time
import tomllib
from dataclasses import dataclass
from functools import reduce as fold
from pathlib import Path

CONTRACT = "u32-prime-field-orbit-v1"
CORPORA = Path(__file__).resolve().with_name("corpora.toml")
MASK = 0xFFFFFFFF
H0 = 0x9E3779B9

Vec = tuple[int, int, int, int]


@dataclass(frozen=True)
class Corpus:
    p: int
    length: int
    seed: tuple[int, ...]
    sample_stride: int

    @staticmethod
    def from_mapping(m: dict) -> Corpus:
        if m.get("contract") != CONTRACT:
            raise ValueError(f"corpus contract {m.get('contract')!r} is not {CONTRACT}")
        corpus = Corpus(int(m["p"]), int(m["length"]), tuple(int(x) for x in m["seed"]), int(m["sample_stride"]))
        if not (2 < corpus.p < 2**32 and corpus.p % 2 and corpus.length >= 1 and len(corpus.seed) == 4 and corpus.sample_stride >= 1):
            raise ValueError(f"corpus outside the contract: {corpus}")
        return corpus

    def canonical_json(self) -> bytes:
        body = {"contract": CONTRACT, "p": self.p, "length": self.length, "seed": list(self.seed), "sample_stride": self.sample_stride}
        return json.dumps(body, sort_keys=True, separators=(",", ":")).encode("ascii")

    def sha256(self) -> str:
        return hashlib.sha256(self.canonical_json()).hexdigest()

    @property
    def work(self) -> int:
        """Units of work the corpus asks for: the number of words."""
        return word_count(self.length)

    def args(self) -> list[str]:
        """The positional arguments every kernel takes: p length s0 s1 s2 s3 stride, residues reduced."""
        return [str(x) for x in (self.p, self.length, *reduce(self.seed, self.p), self.sample_stride)]


@dataclass(frozen=True)
class Record:
    p: int
    length: int
    words: int
    zero_hits: Vec
    first_zero: int | None
    hash_sum: int
    hash_xor: int
    samples: tuple[tuple[int, Vec], ...]


def load_corpora(path: Path = CORPORA) -> dict[str, dict]:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def reduce(v: tuple[int, ...], p: int) -> Vec:
    return tuple(x % p for x in v)  # type: ignore[return-value]


def word_count(length: int) -> int:
    return 4 * 3 ** (length - 1)


def decode(w: int, length: int) -> tuple[int, ...]:
    letters, q = [w % 4], w // 4
    for _ in range(1, length):
        q, r = divmod(q, 3)
        letters.append(r + (r >= letters[-1]))
    return tuple(letters)


def step(v: Vec, i: int, p: int) -> Vec:
    s = (sum(v) - v[i]) % p
    return v[:i] + ((2 * s + 2 * p - v[i]) % p,) + v[i + 1:]  # type: ignore[return-value]


def endpoint(corpus: Corpus, w: int) -> Vec:
    return fold(lambda v, i: step(v, i, corpus.p), decode(w, corpus.length), reduce(corpus.seed, corpus.p))


def quadric(v: Vec, p: int) -> int:
    return (sum(v) ** 2 - 2 * sum(x * x for x in v)) % p


def mix32(x: int) -> int:
    x ^= x >> 16
    x = (x * 0x7FEB352D) & MASK
    x ^= x >> 15
    x = (x * 0x846CA68B) & MASK
    return x ^ (x >> 16)


def endpoint_hash(e: Vec) -> int:
    return fold(lambda h, x: mix32(h ^ x), e, H0)


def census_range(corpus: Corpus, lo: int, hi: int) -> Record:
    ends = [(w, endpoint(corpus, w)) for w in range(lo, hi)]
    hashes = [endpoint_hash(e) for _, e in ends]
    return Record(
        p=corpus.p,
        length=corpus.length,
        words=hi - lo,
        zero_hits=tuple(sum(e[k] == 0 for _, e in ends) for k in range(4)),  # type: ignore[arg-type]
        first_zero=min((w for w, e in ends if 0 in e), default=None),
        hash_sum=sum(hashes) & MASK,
        hash_xor=fold(int.__xor__, hashes, 0),
        samples=tuple((w, e) for w, e in ends if w % corpus.sample_stride == 0),
    )


def census(corpus: Corpus) -> Record:
    return census_range(corpus, 0, word_count(corpus.length))


def merge(parts: list[Record]) -> Record:
    """Combine records of disjoint index ranges; every aggregate is commutative."""
    firsts = [r.first_zero for r in parts if r.first_zero is not None]
    return Record(
        p=parts[0].p,
        length=parts[0].length,
        words=sum(r.words for r in parts),
        zero_hits=tuple(sum(r.zero_hits[k] for r in parts) for k in range(4)),  # type: ignore[arg-type]
        first_zero=min(firsts, default=None),
        hash_sum=sum(r.hash_sum for r in parts) & MASK,
        hash_xor=fold(int.__xor__, (r.hash_xor for r in parts), 0),
        samples=tuple(sorted(s for r in parts for s in r.samples)),
    )


def render(r: Record) -> bytes:
    lines = [
        f"contract {CONTRACT}",
        f"p {r.p}",
        f"length {r.length}",
        f"words {r.words}",
        "zero_hits " + " ".join(map(str, r.zero_hits)),
        f"first_zero {'none' if r.first_zero is None else r.first_zero}",
        f"hash_sum {r.hash_sum}",
        f"hash_xor {r.hash_xor}",
        *(f"sample {w} " + " ".join(map(str, e)) for w, e in r.samples),
    ]
    return ("\n".join(lines) + "\n").encode("ascii")


def replay(corpus: Corpus, text: bytes, full: bool) -> list[str]:
    """Every way ``text`` fails the contract for ``corpus``; empty means accepted.

    ``full`` recomputes the whole record; otherwise the header and every
    sample are recomputed from their indices and the quadric is checked.
    """
    if full:
        expected = render(census(corpus))
        return [] if text == expected else ["record differs from the full recomputation"]
    lines = text.decode("ascii", errors="replace").split("\n")
    header = [f"contract {CONTRACT}", f"p {corpus.p}", f"length {corpus.length}", f"words {word_count(corpus.length)}"]
    errors = [f"header line {i}: {got!r} != {want!r}" for i, (got, want) in enumerate(zip(lines, header)) if got != want]
    samples = [line.split() for line in lines if line.startswith("sample ")]
    want_ws = list(range(0, word_count(corpus.length), corpus.sample_stride))
    if [int(s[1]) for s in samples] != want_ws:
        errors.append("sample indices differ from the stride")
    q0 = quadric(reduce(corpus.seed, corpus.p), corpus.p)
    for s in samples:
        w, e = int(s[1]), tuple(int(x) for x in s[2:])
        if w < word_count(corpus.length) and e != endpoint(corpus, w):
            errors.append(f"sample {w}: endpoint differs")
        elif len(e) == 4 and quadric(e, corpus.p) != q0:  # type: ignore[arg-type]
            errors.append(f"sample {w}: quadric not preserved")
    return errors


def main(argv: list[str]) -> None:
    if argv[0] == "--kernel":
        p, length, *seed, stride, _threads = map(int, argv[1:])
        corpus = Corpus.from_mapping({"contract": CONTRACT, "p": p, "length": length, "seed": seed, "sample_stride": stride})
    else:
        corpus = Corpus.from_mapping(load_corpora()[argv[0]])
    start = time.perf_counter_ns()
    record = census(corpus)
    elapsed = time.perf_counter_ns() - start
    sys.stdout.buffer.write(render(record))
    print(f"kernel_ns {elapsed}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
