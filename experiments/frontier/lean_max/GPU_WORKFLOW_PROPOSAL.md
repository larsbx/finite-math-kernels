# Proposed GPU acceptance workflow — approval required

This is a review proposal only. No workflow file is installed, no hardware is
registered, and no remote job is dispatched. Local acceptance does not require
a GitHub workflow change. After host validation, the following manual-only lane
could run the same command on an explicitly approved host.

Proposed execution boundary:

| Setting | Proposed value |
| --- | --- |
| Trigger | Manual workflow dispatch only; no PR or push trigger |
| Source | Operator-supplied reviewed full commit SHA; checkout without credentials |
| Runner | Ephemeral single-use Linux x64 host, isolated to this repository |
| Labels | self-hosted, linux, x64, lean-max-gpu-approved |
| GPU | One physical NVIDIA GPU; no shared hardware or MIG |
| Environment | lean-max-gpu-acceptance, with owner approval required before dispatch starts |
| Permissions | Repository contents read only; no secrets available to source code |
| Time/cost | 60-minute timeout, one job at a time, at most one GPU-hour per dispatch; provider price must be approved before paid execution |
| Tools | Preinstalled pinned Pixi environment, Lean 4.35.0, approved Nsight and compatible NVIDIA driver |
| Artifacts | Complete evidence directory, including rejected receipts and raw reports; 14-day retention |
| Promotion | None; receipt remains conformance evidence |

The runner label and environment do not currently exist by virtue of this
proposal. Provisioning, access restrictions, environment reviewer settings,
network/secret isolation, exact host identity/price and cleanup must be reviewed
before registration. An arbitrary workflow can bypass environment names, so
repository-scoped ephemeral runner access must be enforced outside this YAML.
The owner must trust the reviewed source executed on the GPU host.

Proposed workflow content (place under the workflows directory only after
approval, with actions pinned to the immutable commits shown below):

```yaml
name: Lean-MAX GPU hardware acceptance
on:
  workflow_dispatch:
    inputs:
      revision:
        description: Reviewed full 40-character source commit
        required: true
        type: string
permissions:
  contents: read
concurrency:
  group: lean-max-gpu-hardware-acceptance
  cancel-in-progress: false
jobs:
  hardware:
    environment: lean-max-gpu-acceptance
    runs-on: [self-hosted, linux, x64, lean-max-gpu-approved]
    timeout-minutes: 60
    env:
      REVIEWED_REVISION: ${{ inputs.revision }}
      EVIDENCE_DIR: ${{ runner.temp }}/lean-max-${{ github.run_id }}-${{ github.run_attempt }}
    steps:
      - name: Validate revision syntax
        shell: bash
        run: |
          set -euo pipefail
          [[ "$REVIEWED_REVISION" =~ ^[0-9a-f]{40}$ ]]
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
        with:
          ref: ${{ inputs.revision }}
          persist-credentials: false
      - name: Run local fail-closed gate
        shell: bash
        run: |
          set -euo pipefail
          pixi run python -m experiments.frontier.lean_max.hardware_acceptance \
            --expected-revision "$REVIEWED_REVISION" \
            --gpu-runner "$EVIDENCE_DIR/gpu-candidates" \
            --cpu-runner "$EVIDENCE_DIR/cpu-candidates" \
            --out "$EVIDENCE_DIR"
      - name: Preserve complete evidence even after refusal
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
        with:
          name: lean-max-gpu-${{ github.run_id }}-${{ github.run_attempt }}
          path: ${{ env.EVIDENCE_DIR }}
          if-no-files-found: error
          retention-days: 14
```

Approval would authorize installing this manual lane and the agreed isolated
runner/environment configuration. The action pins were resolved from the
upstream v4 refs on November 6, 2026 and remain part of the proposed review scope.
It would not authorize a job dispatch, paid compute, shared hardware access,
merging the prototype into main or promotion. A specific reviewed SHA, host,
tool versions and price still have to be approved for a run. Failure to obtain a
hardware receipt leaves hardware acceptance pending.
