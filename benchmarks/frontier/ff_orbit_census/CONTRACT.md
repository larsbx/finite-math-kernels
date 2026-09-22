# `u32-prime-field-orbit-v1`: Apollonian word census mod p

Status: semantic contract for Lane A (`ff_orbit_census`, rank 1 in
`docs/frontier-math-compute-candidates.md`).
Authority: performance evidence only. The census counts words, not orbit
points, and a count proves nothing about the orbit.

## Frontier question and finite subproblem

The frontier question belongs to `larsbx/giant-fibers-finite-fields-thin-groups`
(Priority 4: the Apollonian orbit mod p against the ambient Descartes quadric).
The finite subproblem fixed here is: apply every reduced word of length `L` in
the Apollonian generators to one root quadruple over `F_p`, and reduce the
endpoints to a small deterministic record.

## Arithmetic

- `p` is an odd prime with `p < 2^32`; every residue is a `u32` in `[0, p)`.
- No signed or floating arithmetic appears.
- Generator `S_i` (`i` in `0..3`) replaces coordinate `i` of `v = (v0, v1, v2, v3)`
  by `(2 * (sum_{j != i} v_j) - v_i) mod p`. Only the residue is specified. The
  reference computes `(2 * s + 2 * p - v_i) mod p` with `s = (sum_{j != i} v_j) mod p`
  in unbounded integers. The kernels reach the same residue by conditional
  subtraction, which needs no division and, in Bend, no type wider than `u32`.
- Each `S_i` is an involution and preserves `Q(v) = (sum v)^2 - 2 * sum v^2`
  mod p; replay checks `Q(endpoint) = Q(seed)`.

## Corpus

A corpus is `{contract, p, length, seed, sample_stride}`, with `seed` given as
four integers reduced mod p (so the root quadruple `(-1, 2, 2, 3)` is allowed).
Its identity is the SHA-256 of its canonical JSON (sorted keys, no whitespace).
The shipped corpora live in `benchmarks/frontier/ff_orbit_census/corpora.toml`.

## Word indexing

`W(L) = 4 * 3^(L-1)` reduced words (no letter twice in a row). Index `w` in
`[0, W(L))` decodes as

```text
letter[0] = w mod 4;  q = w div 4
letter[k] = r + (r >= letter[k-1]),  r = q mod 3;  q = q div 3   (k = 1..L-1)
```

and the endpoint is `S_{letter[L-1]}( ... S_{letter[0]}(seed))`. The map is a
bijection onto reduced words. Implementations may enumerate in any order,
share prefixes, or split the index range; only the record is compared.

## Reductions

Per endpoint `e = (e0, e1, e2, e3)`:

```text
h = 0x9E3779B9
h = mix32(h xor e_k)   for k = 0..3
mix32(x): x ^= x >> 16; x *= 0x7FEB352D; x ^= x >> 15; x *= 0x846CA68B; x ^= x >> 16   (u32 wrapping)
```

The record aggregates, all commutative and associative so any partition is valid:

- `zero_hits[k]`: number of words whose endpoint has `e_k = 0`;
- `first_zero`: least `w` whose endpoint has some `e_k = 0`, else `none`;
- `hash_sum`: sum of `h` mod 2^32; `hash_xor`: xor of `h`;
- samples: the endpoint of every `w` with `w mod sample_stride = 0`.

## Canonical record

ASCII, `\n`-terminated lines, in exactly this order, decimal integers:

```text
contract u32-prime-field-orbit-v1
p <p>
length <L>
words <W(L)>
zero_hits <z0> <z1> <z2> <z3>
first_zero <w|none>
hash_sum <u32>
hash_xor <u32>
sample <w> <e0> <e1> <e2> <e3>      (ascending w)
```

The output digest is the SHA-256 of these bytes. Two implementations agree
exactly when their digests are equal. A kernel reports its own timed region on
stderr as `kernel_ns <n>`; formatting the record is outside that region.

## Replay

`benchmarks/frontier/ff_orbit_census/reference.py` is the spec oracle. It
recomputes the full record for small corpora and, for any corpus, recomputes
every sample from its index and checks the quadric invariant. It has no
acceptance authority over the domain question; it decides only whether a
record satisfies this contract.
