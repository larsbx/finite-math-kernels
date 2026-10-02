# Canonical embedded module normal form

## Purpose

This package layer canonicalizes finitely generated additive subgroups in a
fixed exact coordinate basis. Its first consumer is the loop-gain subgroup of
the PSC Tier 2 Growth Bridge, but the implementation is domain-neutral.

## Non-goals

The following are deliberately insufficient and must not be exposed as module
identity:

- rational rank;
- rational row/column span;
- Smith invariant factors alone;
- determinant/index alone.

Those can agree for distinct embedded subgroups.

## Integer contract

Generators are **rows**. `row_hnf(rows, dimension)` takes a list of rows, each
of length `dimension` = d, and canonicalizes the subgroup L <= Z^d they
generate:

    L = { sum_i c_i * rows[i] : c_i in Z }.

An input whose generators are stored as columns must be transposed by the
caller; `row_hnf` rejects any row whose length differs from `dimension`
rather than guessing an orientation.

The output is the unique nonzero row Hermite normal form H of L:

- generators are rows, one per output row, each of length d;
- pivot columns increase strictly from top to bottom;
- every pivot is positive;
- entries below each pivot are zero;
- entries above a pivot lie in the residue interval [0, pivot);
- zero rows are dropped, so len(H) = rank(L) for rank-deficient input;
- the zero lattice (no generators, only zero generators, or d = 0) is the
  empty list;
- H is returned as the ordered row list above; deterministic byte
  serialization of that list is not yet provided and remains required.

Equal generated subgroups must produce identical canonical presentations.

## Rational contract

For normalized exact rational generators in Q^d:

1. reject any invalid exact scalar;
2. compute D = lcm of all positive denominators;
3. scale every generator by D into Z^d;
4. canonicalize the integer lattice;
5. retain a normalized denominator/presentation pair;
6. remove any common scalar factor that would otherwise make presentation
   depend on a nonminimal D.

The result denotes the embedded subgroup in the declared coordinate basis, not
an abstract isomorphism class.

## Required adversarial examples

The test suite must include two rank-two sublattices with equal index and equal
Smith invariants but different embeddings, and require unequal normal forms.

It must also include:

- generator permutations;
- redundant generators;
- replacing a generator by itself plus an integer multiple of another;
- sign changes;
- zero and rank-deficient lattices;
- rational generator sets with different presentations of the same subgroup;
- rejected exact rationals.

## Dependency

This branch is stacked on the weighted cycle-gain generator work. Do not merge
it before the cycle-gain graph/gain contract is green and stable.
