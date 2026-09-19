# Consolidation provenance

The monorepo was assembled from the code-bearing branches of six source
repositories, and later took two packages back from a consumer. This document
names the immutable snapshots; the
machine-readable pin is `audit/provenance.json`, and `tools/provenance.py`
verifies the working tree against it on every CI run (`pixi run test`
depends on `test-provenance`).

## Pinned source snapshots

| Source repository | Branch | Commit | Imported subtree | Subtree id |
| --- | --- | --- | --- | --- |
| `larsbx/finite_exact` | `claude/extract-psc-nlap-packages-v5l1zl` | `5c0763a2fb4fa868b4b6d8b39adfbd9fbf14b35f` | `finite_exact/` | `e9cf76cf32aeb99ce1c7646ad599b022b51a4c66` |
| `larsbx/interval_q` | `claude/extract-psc-nlap-packages-v5l1zl` | `8a3366c37e55efd1f0150046fd94dba185180b06` | `interval_q/` | `ec4255c75628a851cc002a4f56b0064831c00f05` |
| `larsbx/finite_linear_algebra` | `claude/extract-psc-nlap-packages-v5l1zl` | `fe366a597a5c12ab6e62e2d226717cce646771f2` | `finite_linear_algebra/` | `95b609b37631eed0c5e96bb3285fb2c8354294c5` |
| `larsbx/substitution_dynamics` | `claude/extract-psc-nlap-packages-v5l1zl` | `778789ff2e12d3a9f8f9ec35599b7b2ac241fa05` | `substitution_dynamics/` | `a29a195b0fcff7f40ce10cc411b3ae5b56aa46cd` |
| `larsbx/finite_proof_records` | `claude/extract-psc-nlap-packages-v5l1zl` | `746b550877149edf512d4d2a81889aeb5c3da9c3` | `finite_proof_records/` | `1f54d3075c7d4cfad8b4a1d01eb047b0a5922fe9` |
| `larsbx/claim_governance_tools` | `claude/mojo-finite-proof-records-zrimg2` | `b084303cdb9df2f5c3a166c5e5297536efde30db` | `claim_governance/` | `a04df88d10b1ecbeb6da265fac4270db6d046b19` |
| `larsbx/finite-mandelbrot-research` | `main` | `cea36ccba8a2a4d5e3c08ecce05c95f6c2bbb351` | `src/`, `tools/` | `58daaf3a6295d0f3076c3c976d6b43b06191253b`, `ce44d6ed7ed9d66b39594c334884bf42a159f604` |

Subtree ids are git tree ids at the pinned commit (`git rev-parse <commit>:<path>`
in the source repository). `audit/provenance.json` also records the tree id
of every other top-level directory of each snapshot (docs, tests, tools, CI),
so the whole reviewed snapshot is pinned, not only the package directory.
The source repositories' `main` branches contained README stubs at the time
of consolidation; the code-bearing branches are the snapshots above.

## Destination mapping

| Destination | Source | Source path |
| --- | --- | --- |
| `finite_exact/` (except `closed_q.mojo`) | `finite_exact` | `finite_exact/` |
| `finite_exact/closed_q.mojo` | `interval_q` | `interval_q/closed_q.mojo` |
| `finite_linear_algebra/` | `finite_linear_algebra` | `finite_linear_algebra/` |
| `substitution_dynamics/` | `substitution_dynamics` | `substitution_dynamics/` |
| `proof_records/` | `finite_proof_records` | `finite_proof_records/` |
| `audit/claim_governance/`, `audit/docs/` | `claim_governance_tools` | `claim_governance/`, `docs/` |
| `docs/` | `finite_exact`, `finite_proof_records` | `docs/` |
| `tests/<package>/`, `tools/` | the package's source | `tests/`, `tools/` |
| `quadratic_orbit/` | `finite_mandelbrot_research` | `src/interval_orbit.mojo` |
| `mojo_smoke/` | `finite_mandelbrot_research` | `src/smoke_report.mojo` |
| `vendoring/` | `finite_mandelbrot_research` | `tools/check_vendored_sync.py` |

The last three destinations run the other way from the first six. They were
not extracted from a library repository into the monorepo; they grew inside a
consumer, `larsbx/finite-mandelbrot-research`, and were lifted back here once
a second consumer needed them. Their relation is `modified`, because
generalizing the orbit to an arbitrary seed and making the vendoring checker
indifferent to its own depth are changes, not relocations.

`finite_exact/` was vendored byte-for-byte in `interval_q` and
`finite_linear_algebra` too; the three copies were identical at the pinned
commits, and the manifest attributes the monorepo copy to `finite_exact`.

## Relations

Every tracked file carries one relation in `audit/provenance.json`:

| Relation | Meaning | Verifier rule |
| --- | --- | --- |
| `copy` | byte-for-byte identical to the pinned source blob, whatever the path | current blob equals `source_blob` |
| `modified` | imported from the pinned source and changed here | current blob equals the recorded blob and differs from `source_blob` |
| `facade` | a stable re-export module written for the monorepo (`rational`, `closed_interval`, `matrix`, `matrix3`, `rational_elimination`) | current blob equals the recorded blob |
| `authored` | written in the monorepo | current blob equals the recorded blob |
| `generated` | written by a tool from other tracked inputs | current blob equals the recorded blob; `generator` named |

Relocations are copies under another path; the source path is recorded.
Blob ids are git blob ids (SHA-1 over `blob <size>\0` and the bytes), so a
source pin can be checked against `git ls-tree -r <commit>` in the source
repository without this tool.

## Verifying and updating

```bash
pixi run test-provenance                 # part of `pixi run test`
python tools/provenance.py --check       # exit 1 on any unexplained divergence
python tools/provenance.py --update      # after editing tracked files
```

The verifier fails on a file the manifest does not list, a listed file that
is missing, a blob that differs from the manifest, a `copy` that no longer
equals its source blob, a `modified` file that has drifted back to its
source, and any imported file without a pinned source. `--update` refreshes
blobs, re-decides `copy` versus `modified` against the pinned source blobs,
adds new files as `authored`, and drops deleted files; it never recomputes
source pins, which were derived once from the snapshots above and are
reviewed as data. A file that should be `facade` or `generated` is
reclassified by hand in the manifest.

## Retirement

No source repository is deleted or archived by this change. Retirement is a
separate operation after consumers pin a released monorepo commit.
