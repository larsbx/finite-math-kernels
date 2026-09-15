# Consolidation provenance

The monorepo was assembled from the code-bearing branch
`claude/extract-psc-nlap-packages-v5l1zl` in the following repositories.
The source repositories' `main` branches contained README stubs at the time of
consolidation.

| Destination | Source repository | Source package |
| --- | --- | --- |
| `finite_exact/` | `larsbx/finite_exact` | `finite_exact/` |
| `finite_exact/closed_q.mojo` | `larsbx/interval_q` | `interval_q/closed_q.mojo` |
| `finite_linear_algebra/` | `larsbx/finite_linear_algebra` | `finite_linear_algebra/` |
| `substitution_dynamics/` | `larsbx/substitution_dynamics` | `substitution_dynamics/` |
| `proof_records/` | `larsbx/finite_proof_records` | `finite_proof_records/` |
| `audit/claim_governance/` | `larsbx/claim_governance_tools` | `claim_governance/` |

The original implementation filenames remain temporarily available. Stable
facades use `rational.mojo`, `closed_interval.mojo`, `matrix.mojo`,
`matrix3.mojo`, and `rational_elimination.mojo`. This lets existing consumers
migrate independently without creating two arithmetic implementations.

The first five sources use branch `claude/extract-psc-nlap-packages-v5l1zl`;
`claim_governance_tools` uses branch `claude/mojo-finite-proof-records-zrimg2`.

No source repository is deleted or archived by this change. Retirement is a
separate operation after consumers pin a released monorepo commit.
