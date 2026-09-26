# Estate Repository Template v1

Status: shared estate architecture contract.

## Purpose

Estate Repository Template v1 gives repositories a common, machine-auditable answer
to four questions:

1. what is authoritative;
2. what domain owns an artifact;
3. which language implements that role; and
4. whether an artifact is canonical, supporting evidence, experimental, generated,
   or vendored.

The ordering is **authority first, domain second, language third**. A language name
must never be the top-level reason an artifact is trusted.

Each consumer owns one root `estate.toml`. The shared tooling validates structure
and authority declarations; it does not own domain theorem status, certificate
acceptance, effect authorization, or persisted operational state.

## Standard planes

Only applicable planes are created. Empty silos are forbidden.

| Plane | Default target | Meaning |
| --- | --- | --- |
| policy | `policy/` | governance, repository authority, backend and acceptance policy |
| kernel | `kernel/` | canonical executable validation owned by the repository |
| proof | `proof/` | theorem/claim state, formal proof packages, proof records and models |
| reference | `reference/` | independently executable semantics and golden-vector generation |
| oracles | `oracles/` | non-authoritative differential checking and research engines |
| experiments | `experiments/` | disposable spikes with explicit promotion/deletion criteria |
| schemas | `schemas/` | versioned boundary and serialization contracts |
| conformance | `conformance/` | accepted, rejected, malformed and boundary vectors |
| vendor | `vendor/` | pinned external code, distinct from local ownership |
| tools | `tools/` | audits, generators and repository maintenance only |
| docs | `docs/` | exposition, research notes, handoffs and audits |
| paper | `paper/` | publication artifacts |
| examples | `examples/` | worked examples that are not proof authority |

A repository may omit irrelevant planes. It may add domain-specific planes only
when their authority uses a declared v1 authority class.

## Authority rules

1. Every acceptance or effect boundary has exactly one canonical implementation.
2. A second implementation is a reference, oracle, formal refinement, generated
   adapter, or conformance checker until an explicit authority migration says otherwise.
3. Cross-language disagreement fails closed.
4. Experiments and oracles never issue acceptance verdicts.
5. Generated surfaces are derived artifacts and name their source.
6. Vendored code is pinned external code and is visibly non-local.
7. A computation is not a theorem merely because it is deterministic or exhaustive.
8. Moving a file cannot change mathematical or operational authority.

## Language rule

`estate.toml` records roles, not language prestige. v1 requires exactly one
canonical language declaration for the repository's kernel boundary. Supporting
languages may not declare `acceptance_authority = true`.

## Transitional adoption

Existing repositories use `layout_status = "transitional"`. Each required plane
records its future target plus existing `current` paths or `current_globs`.
This permits architecture enforcement before disruptive moves.

Migration order:

1. declare authority without changing it;
2. add the shared estate audit to CI;
3. separate canonical, reference, oracle, experiment, vendor and generated roles;
4. move one bounded context at a time;
5. update imports and tests in the same change;
6. delete compatibility mappings only after CI proves the new boundary.

Mass tree reshuffles are discouraged because they obscure semantic changes.

## Shared tooling

The canonical v1 mechanism lives in this directory:

- `audit_estate_layout.py` — dependency-free CLI, parameterized by consumer root;
- `estate.template.toml` — copyable manifest skeleton;
- `action.yml` — GitHub composite action for mirror CI;
- `tests/` — mechanism conformance tests.

Consumers pin the shared mechanism by immutable 40-hex commit revision in two
places: the CI/action reference and the consumer-owned `[estate_tooling]` table in
`estate.toml`. The shared action compares those values and fails closed on drift.
Consumers retain their own `estate.toml`, `ARCHITECTURE.md`, and domain-specific
policy.

Example:

```toml
[estate_tooling]
repository = "larsbx/finite-math-kernels"
path = "audit/estate_repository/v1"
revision = "<40-hex commit SHA>"
```

The shared mechanism does **not** require a consumer to copy this contract into its
own repository. A local copy may remain temporarily during migration, but is derived
documentation rather than authority.

## Required audit

The v1 audit checks at minimum:

- valid repository identity and default branch declaration;
- unique plane identifiers and target paths;
- required current mappings exist;
- authority values and language roles are valid;
- exactly one canonical language owns the kernel role;
- supporting languages cannot claim acceptance authority;
- a declared shared-tooling pin is an immutable 40-hex commit SHA and, when the shared action supplies its executing identity, the repository/path/revision match exactly;
- `ARCHITECTURE.md` exists;
- Pixi workspace identity agrees with the repository identity when Pixi is present;
- a polyglot manifest, when present, names the same repository and links to
  `estate.toml`.

Domain-specific checks belong in the consumer and compose with this audit.
