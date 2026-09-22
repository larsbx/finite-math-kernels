# Julia exact-arithmetic oracle migration

Status: parallel-validation gate. This document does not retire the Python oracle.

## Scope

The first migration slice covers the `Z` and `Q` layers of
`tests/finite_exact/property_probe.mojo`: 300 integer rows and 200 rational
rows generated from the fixed xorshift64* stream. The Mojo transcript remains
the subject under test and the repository remains the owner of the transcript
grammar, seed, case counts, canonical encoding, and acceptance decision.

The Julia implementation is pinned from `larsbx/julia-oracle-lab` at commit
`d694949a5076cb7ffbd663baac4f536d3afa065e`, oracle identifier
`finite-exact.zq.property-transcript`.

## Parallel gate

`.github/workflows/julia-oracle.yml`:

1. generates one transcript from the canonical Mojo probe;
2. requires the existing Python oracle to agree;
3. requires the pinned Julia oracle to agree independently.

Either disagreement fails closed. Agreement is differential evidence only. It
does not prove an arithmetic theorem, accept a certificate, authorize an
effect, or mutate operational state.

## Retirement gate

`tools/property_oracle.py` must not be removed until a separate PR:

- records successful parallel runs;
- confirms the Julia generator is structurally independent rather than a
  transliteration sharing Mojo implementation code;
- preserves the generator-refinement audit or replaces it with an equal or
  stronger domain-owned check;
- covers the interval extension used by `larsbx/interval_q`;
- updates downstream pins and provenance manifests;
- receives the domain owner's explicit retirement decision.

Until then, Python and Julia are both required evidence paths and Mojo remains
authoritative.
