# Standalone Julia Oracle Lab

Status: proposed repository-creation contract  
Proposed repository: `larsbx/julia-oracle-lab`

## Decision

Create a standalone Julia repository for shared research-oracle infrastructure and
cross-repository experiments. Domain claims and fixtures remain owned by their
domain repositories. The new repository is not a trusted kernel, proof authority,
certificate acceptor, authorization service, or deployment authority.

## Responsibility split

| Location | Responsibility |
|---|---|
| `finite-math-kernels` | Canonical reusable finite computation and designated validation |
| `julia-oracle-lab` | Independent recomputation, witness generation, differential testing, and spikes |
| Domain repository | Claim definition, domain fixtures, interpretation, authoritative-checker binding |
| Lean package | Machine-checked proof or interpretation where applicable |

The lab may emit only `agrees`, `disagrees`, `inconclusive`, or
`oracle_error`. It must not emit `accepted`, `proved`, or `authorized`.

## Initial layout

```text
julia-oracle-lab/
├── Project.toml
├── Manifest.toml
├── packages/
│   ├── BoundaryEnvelopes/
│   ├── ExactFiniteAlgebra/
│   ├── DifferentialHarness/
│   └── Reproducibility/
├── domains/
│   ├── nlap/
│   ├── finite_mandelbrot/
│   ├── finite_julia/
│   ├── psc/
│   ├── multiplication_fibers/
│   ├── thin_groups/
│   └── height_pairings/
├── registry/
│   ├── oracles.toml
│   └── oracle-entry.schema.json
├── spikes/
├── test/vectors/
└── docs/authority-boundary.md
```

## Registry contract

Every registered oracle must declare:

- stable oracle identifier and semantic version;
- owning domain repository and claim identifier;
- authoritative checker repository, boundary identifier, and version;
- accepted input schema and deterministic output schema;
- exactness class: `exact`, `interval`, `numerical`, or `mixed`;
- Julia and manifest versions;
- seed and precision requirements;
- canonicalization and digest rules;
- supported result vocabulary;
- promotion status and maintainers.

An oracle entry is invalid if it lacks an authoritative-checker binding. A spike
is never registered as an oracle.

## Reproducibility envelope

Every run records:

- oracle ID and source commit;
- Julia version and `Manifest.toml` digest;
- input artifact digest;
- random seed, even when no randomness is expected;
- precision and rounding mode when applicable;
- platform metadata relevant to reproducibility;
- output artifact digest;
- comparison result against an authoritative vector or checker.

Exact computations must use exact Julia types where the domain permits them.
Numerical evidence must remain explicitly numerical and cannot be relabelled as
an exact witness.

## Domain adapters

The domain repositories retain thin `oracles/julia/` adapters and their own
fixtures. Those adapters invoke a pinned lab version and bind its generic
infrastructure to a domain claim. The lab must not redefine domain claims.

Initial consumers:

1. `NLAP-JT`
2. `finite-math-kernels`
3. `finite-mandelbrot-research`
4. `finite-julia-set-research`
5. `pisot-substitution-conjecture-research`
6. `giant-fibers-finite-fields-thin-groups`
7. `closure-fiber-of-multiplication-research`
8. `height-pairings-bsd-interfaces`

Height-pairing and BSD work may treat Julia as its primary research engine, but
not as proof authority. Finite Mandelbrot and Julia-set adapters must preserve
their finite-only terminology and arithmetic policies; numerical or
transcendental spikes must be isolated and cannot feed certificate acceptance.

## Spike lifecycle

Every spike must state:

1. question and hypothesis;
2. inputs, seed, precision, and dependency lock;
3. time or evidence budget;
4. success, failure, and deletion criteria;
5. intended promotion target.

A successful spike is promoted either into a reviewed oracle package or into an
authoritative implementation behind the domain boundary. Abandoned spikes are
deleted after their result or counterexample is archived.

## CI and authority

- Forgejo is canonical source and merge authority.
- Woodpecker is canonical CI.
- GitHub is a review mirror.
- Julia CI validates reproducibility, registry conformance, deterministic
  fixtures, and differential agreement.
- Passing Julia CI is evidence, not certificate acceptance.
- A Julia disagreement blocks promotion but does not independently invalidate
  an authoritative result; it creates an investigation obligation.

## Bootstrap sequence

1. Create `larsbx/julia-oracle-lab` with Forgejo as canonical remote.
2. Add the authority document and closed registry schema.
3. Implement `BoundaryEnvelopes` and `Reproducibility` without domain logic.
4. Port one exact, deterministic NLAP vector as the first vertical slice.
5. Replay the vector through the authoritative Mojo checker.
6. Add a deliberate disagreement fixture and prove fail-closed handling.
7. Only then migrate shared code from repository-local Julia lanes.
8. Add height-pairing support as the first independent research-engine domain.

## Acceptance criteria

The standalone repository is ready for domain adoption only when:

- the registry rejects unknown critical fields;
- every oracle binds to an authoritative checker;
- a clean environment reproduces the golden exact vector;
- an intentionally corrupted vector yields `disagrees`;
- no API can return proof, acceptance, authorization, or deployment verdicts;
- domain repositories can pin a lab release without importing unreviewed spikes;
- canonical Forgejo and Woodpecker reconciliation is documented and tested.

## Non-goals

This proposal does not move the finite kernel into Julia, centralize domain
claims, replace Lean proofs, replace Mojo certificate checking, or authorize
production use of experimental computations.
