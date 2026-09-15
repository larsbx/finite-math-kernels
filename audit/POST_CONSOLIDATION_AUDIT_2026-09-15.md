# Post-consolidation package audit — 2026-09-15

Status: audit of `main` at `807ae7ed5461af9fe07b1cbbca96f680a105e0e7`.

Scope: the `finite-math-kernels` monorepo and the six source repositories
`finite_exact`, `interval_q`, `finite_linear_algebra`,
`substitution_dynamics`, `finite_proof_records`, and
`claim_governance_tools`.

This is an audit record, not a proof-status change. It proves no mathematical
statement, accepts no certificate, and does not change NLAP-JT or PSC theorem
status.

## Executive result

The consolidation has the intended package decomposition, fail-closed
arithmetic boundaries, consumer-owned claim policy, compiled Mojo coverage, and
a green GitHub Actions run on the audited head. It is not yet ready to be
treated as a fully governed release because three high-priority gaps remain:

1. proof-record identity and dependency semantics lag the corrected contract;
2. migration provenance does not pin immutable source commits and trees;
3. the advertised stable facades are not tested as the consumer-facing API.

Five medium-priority release-governance, documentation, and boundary gaps
are also listed below.

## Evidence examined

- root package layout and public README;
- `pixi.toml` and `.github/workflows/ci.yml`;
- package implementations and stable facade modules;
- Mojo and Python tests, replay vectors, and property oracle;
- `audit/CONSOLIDATION_PROVENANCE.md`;
- the in-tree `docs/proof-records-specification.md`;
- `larsbx/NLAP-JT` `docs/finite-proof-records-spec.md` at commit
  `e10c665` ("Make proof-record identity and dependency use explicit"), the
  contract that FMK-AUDIT-001 measures against;
- the six source repositories' current `main` branches;
- GitHub Actions run 35019844042, which succeeded for the audited head.

## High-priority findings

### FMK-AUDIT-001 — Proof-record dependencies are not proposition-bound

Severity: high.

`proof_records/records.mojo` and the Python reference model represent
`depends_on` as an ordered list of bare record identifiers. A dependency does
not carry the expected claim, the consumer use site, the required scope
relation, or the required validation outcome. The closure validator therefore
cannot establish that a structurally valid referenced record matches the
premise for which it is used.

Record identity is also caller-supplied. `canonical_bytes` includes the
caller-provided `id`, while `digest` is calculated separately; validation
does not recompute a non-circular identity preimage and verify the identifier.

This conforms to the in-tree `docs/proof-records-specification.md`
(section 2: `depends_on` is an ordered tuple of bare identifiers; `id` is
caller-supplied). It is weaker than the corrected contract in
`larsbx/NLAP-JT` `docs/finite-proof-records-spec.md` at commit `e10c665`,
which defines identity-bearing dependency edges (`dependency_record_id`,
expected claim, use site, scope relation, outcome; section 3) and a record-ID
preimage that excludes `record_id` (section 8). The finding is therefore
specification drift between the two repositories, and the repair must update
the in-tree specification together with both implementations.

Required repair:

- introduce identity-bearing dependency edges;
- bind each edge to expected claim, use site, scope relation, and outcome;
- define a record-ID preimage that excludes `record_id`;
- verify the consumer-selected digest identifier against that preimage;
- retain canonical identity for structurally well-formed incomplete, open, and
  bounded records;
- extend Python/Mojo golden vectors and negative closure tests.

Do not migrate consumer proof ledgers to this package until this repair lands.

### FMK-AUDIT-002 — Consolidation provenance is mutable and incomplete

Severity: high.

`audit/CONSOLIDATION_PROVENANCE.md` names repositories, source packages, and
`claude/...` branches, but records no source commit SHA, source subtree SHA,
destination tree/blob digest, or import transformation. Branch names are
mutable and cannot establish which reviewed source snapshot produced the
monorepo.

Required repair:

- pin the exact source commit and subtree SHA for every imported package;
- record destination tree or per-file blob hashes;
- distinguish byte-for-byte copies, relocations, renamed facades, and generated
  files;
- add an automated provenance verifier that fails on unexplained divergence.

### FMK-AUDIT-003 — Stable facades are outside direct compatibility coverage

Severity: high.

The README advertises `rational.mojo`, `closed_interval.mojo`,
`matrix.mojo`, `matrix3.mojo`, and `rational_elimination.mojo` as stable
entry points. Most primary tests continue to import compatibility modules such
as `rat_q`, `mat3`, `qlinalg`, `scalar`, and `w3` directly. A broken
re-export can therefore pass the current suite.

Required repair:

- add a compiled consumer-style test importing only stable public modules;
- instantiate and exercise every exported type/function promised by each
  facade;
- keep implementation-module tests as internal coverage, not API coverage.

## Medium-priority findings

### FMK-AUDIT-004 — Property oracle is skip-guarded, not required

Severity: medium.

`pixi.toml` defines the `property` task, and the aggregate `test` task does
not depend on it. The same Mojo-versus-Python comparison does run under
`pixi run test`, through `test-python`:
`tests/finite_exact/test_property_oracle.py::test_mojo_probe_agrees_with_python_oracle`
executes the `zq` probe and compares it with the oracle. That test is guarded
by `pytest.mark.skipif(shutil.which("mojo") is None)`, so a CI environment
without `mojo` on `PATH` reports green while skipping the strongest arithmetic
cross-check. The gap is that the check is conditional, not that it is absent.

Required repair: make the probe unconditional under `pixi run test` (fail,
not skip, when `mojo` is missing), or add `property` to the `test`
dependency closure.

### FMK-AUDIT-005 — Relocation left stale paths and commands

Severity: medium.

Examples:

- proof-record comments refer to nonexistent `docs/specification.md`;
- the proof-record specification refers to
  `finite_proof_records/records.mojo` instead of `proof_records/records.mojo`;
- it names `pixi run replay`, which is not defined in `pixi.toml`;
- `finite_exact/__init__.mojo` refers to nonexistent
  `docs/vendoring-protocol.md`;
- test headers name nonexistent `pixi run smoke` tasks and old paths;
- `docs/exact-arithmetic-public-boundary.md` and
  `docs/rational-interval-arithmetic-spec.md` cite
  `tests/test_finite_exact.mojo` (now `tests/finite_exact/test_finite_exact.mojo`)
  and `pixi run smoke`.

Required repair: add an automated local-link/task-reference audit and correct
all relocated references.

### FMK-AUDIT-006 — Source repositories do not declare retirement

Severity: medium.

Each source repository's `main` branch currently contains only a title-only
README. The repositories are unarchived and do not identify the monorepo,
the preserved code-bearing branch, the frozen source commit, or the consumer
migration gate. This leaves multiple apparently authoritative repositories.

Required repair:

- replace each stub with a migration notice and immutable source provenance;
- direct issues and new development to `finite-math-kernels`;
- archive only after consumers pin a released monorepo commit.

### FMK-AUDIT-007 — Main has no enforced status gate

Severity: medium.

At audit time, GitHub reported branch protection disabled and no required
status checks for `main`. A direct update can bypass the otherwise-green CI
workflow.

Required repair: require the complete CI gate before merge and prevent direct
unreviewed updates to the release branch, or document the external canonical
merge authority and verify mirrored commit/tree identity.

### FMK-AUDIT-008 — `BigZ` field mutation bypasses fail-closed arithmetic

Severity: medium.

`BigZ.sign` and `BigZ.limbs` are public mutable fields
(`finite_exact/bigint_z.mojo`). Operations assume constructor invariants and
do not validate them: `bigz_add` with a zero operand returns the other
operand by copy, so a value with `sign = 2` or non-normalized limbs
propagates unchanged and unrejected. `docs/exact-arithmetic-public-boundary.md`
does not currently exclude field mutation from the boundary.

Required repair: either state in the public-boundary document that values
are only valid when constructor-produced and field mutation is undefined, or
validate `sign` and limb normalization at operation entry and route
violations through the existing rejection carrier.

## Positive findings

- Package boundaries match the consolidation plan.
- `BigZ` and `Q` remain exact and fail closed for constructor-produced
  values. The claim does not extend to a `BigZ` whose public `sign` or
  `limbs` fields a consumer has mutated: `bigz_add` returns such a value by
  copy without validation, and no operation carries a rejection for it. The
  public-boundary contract must state that direct field mutation is outside
  the boundary, or the operations must validate their inputs; see the
  boundary note in FMK-AUDIT-008.
- Closed rational intervals remain conservative filters and do not promote
  unknown results.
- The interval API is consolidated under `finite_exact`, avoiding a second
  rational implementation.
- Linear algebra remains finite-dimensional and makes no spectral or theorem
  claims.
- Capped balanced-pair automata are explicitly inconclusive.
- Claim-governance policy remains consumer supplied.
- Mojo implementations exist for the reusable mathematical kernels.
- Proof records have Python/Mojo replay-vector comparison.
- The audited head's GitHub Actions run completed successfully.

## Remediation order

1. Repair proof-record identity and dependency semantics.
2. Pin immutable migration provenance and automate its verification.
3. Compile and test stable public facades.
4. Make the arithmetic property oracle unconditional under `pixi run test`.
5. Repair relocated links, paths, and task names.
6. Close the `BigZ` field-mutation boundary (FMK-AUDIT-008).
7. Publish source-repository migration notices, then archive after consumer
   migration.
8. Enforce the canonical status gate and commit/tree readback.

## Release judgment

The arithmetic, interval, linear-algebra, substitution-dynamics, and
claim-governance packages are suitable for continued integration testing.
Proof-record consumer migration and formal retirement of the source
repositories should remain blocked until FMK-AUDIT-001 through
FMK-AUDIT-003 are resolved.
