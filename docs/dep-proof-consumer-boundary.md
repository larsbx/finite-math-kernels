# Dep–Proof consumer boundary

**Status:** integration note for `proof_records`.

**Consumer:** `larsbx/crypto-composer`.

## Purpose

`crypto-composer` is introducing a scheme-indexed dependency/proof system (“Dep–Proof”) whose semantic objects include dependency specifications, satisfaction propositions, verification conditions, proof plans, and cryptographic certificates.

This does **not** move cryptographic proof semantics into `finite-math-kernels`.

The existing `proof_records` package remains the generic evidence substrate.

## Ownership boundary

`finite-math-kernels/proof_records` owns:

- finite proof/evidence record kinds and required metadata;
- canonical serialization;
- content-derived record identity;
- identity-bearing dependency edges;
- generic closure validation;
- evidence-vocabulary translation;
- typed relationship-graph export.

It continues to treat statements and scopes as opaque.

`crypto-composer` owns:

- the dependency DSL (`DepSpec`);
- scheme-indexed semantics `Sat(S,D)`;
- cryptographic game, observable, witness, and reduction semantics;
- well-formedness of those domain objects;
- P0/P1 normalization and verification-condition generation;
- checkable-vs-uncheckable proposition classification;
- proof-plan and obligation-graph semantics;
- tool/proof-kernel adapters;
- the claim that a particular evidence artifact proves a particular cryptographic proposition.

## Required non-implication

A complete proof-record closure must **not** be interpreted as:

```text
Proof(Sat(S,D))
```

by this repository.

A complete closure means only that all named records are structurally valid, satisfy identity/edge/scope/outcome requirements, and are accepted by the supplied consumer policy.

The consumer remains responsible for proving that those records are adequate evidence for its proposition.

## Adapter direction

The intended adapter is one-way at the semantic boundary:

```text
crypto-composer proof/check result
          │
          │ translate to/from declared evidence vocabulary
          ▼
finite-math-kernels/proof_records
          │
          ├── canonical identity
          ├── dependency closure
          ├── provenance
          └── typed relationship graph
```

An external record identifier may be carried as evidence/provenance. It must not be silently reused as the identity of a different Dep–Proof object.

## Relationship to the existing evidence vocabulary map

`docs/evidence-vocabulary-map.md` already records the estate-level direction that `crypto-composer` should consume the proof-record closure validator for its constraint findings.

Dep–Proof makes that integration more precise:

1. a constraint or verifier result is first interpreted by `crypto-composer` under its own semantics and TCB;
2. the resulting evidence may be serialized as a generic proof record;
3. `proof_records` can then validate identity, metadata, dependency linkage, and closure;
4. when imported again, `crypto-composer` must still check the semantic correspondence between the record and the obligation it is meant to discharge.

No generic translation step is allowed to promote evidence authority.

## Stable interface expectations

The future adapter should rely only on stable generic concepts:

- record identifier;
- record kind/outcome;
- statement and scope;
- identity-bearing dependency edge;
- evidence key/value pairs;
- tags;
- closure result and missing-link reasons.

Dep–Proof-specific fields such as:

- `Sat` terms,
- VC ASTs,
- binders/continuations,
- security games,
- reduction witnesses,
- leakage models,
- probabilistic-independence models,

must remain consumer payloads or consumer-owned structures unless they are later generalized independently for more than one domain.

## Review invariant

The boundary can be checked with one rule:

> `finite-math-kernels` may attest that an evidence graph is faithfully represented and structurally complete; it must not decide that a cryptographic proposition is true.

This keeps the reusable package domain-neutral while allowing `crypto-composer` to build stronger, typed certificates on top of it.
