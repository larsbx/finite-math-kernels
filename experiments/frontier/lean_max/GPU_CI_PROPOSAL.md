# GPU workflow proposal — not applied

Status: proposed configuration only. The implementation changes no workflow,
environment, runner labels, access settings or shared-hardware registration.
No remote execution has been requested. Local approved-host reproduction needs
no GitHub configuration change.

Before applying this proposal, obtain user approval for the exact workflow,
GPU UUID/host, access boundary, maximum duration, and cost cap. First collect
independently reproducible local hardware evidence under
[HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md). An offline green suite cannot
authorize remote execution. A workflow installed later on main cannot execute
the acceptance module until the selected reviewed revision contains it.

Proposed runner setup: one ephemeral Linux NVIDIA host restricted to this
repository, label `lean-max-gpu-approved`, with the pinned Pixi environment,
Lean 4.35.0, Nsight Systems and driver preinstalled. The environment
`lean-max-gpu-acceptance` must require human approval and restrict permitted
refs to reviewed branches. No fork/PR/push/scheduled triggers. No credentials
available to tested code; read-only repository token. At most one job at a
time, no retries, 90-minute wall cap. The monetary cap and approved physical
host remain decisions for the user; no provisioning is proposed here.

Proposed `.github/workflows/lean-max-gpu-acceptance.yml` (documentation only):

```yaml
name: Lean-MAX GPU hardware acceptance
on:
  workflow_dispatch:
    inputs:
      revision:
        description: Reviewed full commit SHA
        required: true
        type: string
      gpu_uuid:
        description: Approved physical GPU UUID
        required: true
        type: string
permissions:
  contents: read
concurrency:
  group: lean-max-gpu-hardware
  cancel-in-progress: false
jobs:
  hardware-acceptance:
    runs-on: [self-hosted, linux, x64, lean-max-gpu-approved]
    environment: lean-max-gpu-acceptance
    timeout-minutes: 90
    steps:
      - name: Validate reviewed revision
        env:
          REVIEWED_REVISION: ${{ inputs.revision }}
        run: |
          python3 -c 'import os,re; assert re.fullmatch("[0-9a-f]{40}", os.environ["REVIEWED_REVISION"])'
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.revision }}
          persist-credentials: false
      - name: Run strict local acceptance
        env:
          REVIEWED_REVISION: ${{ inputs.revision }}
          APPROVED_GPU_UUID: ${{ inputs.gpu_uuid }}
        run: |
          pixi run python -m experiments.frontier.lean_max.hardware_acceptance \
            --expected-revision "$REVIEWED_REVISION" \
            --gpu-uuid "$APPROVED_GPU_UUID" \
            --gpu-runner "$RUNNER_TEMP/lean-max-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT/mojo_gpu" \
            --out "$RUNNER_TEMP/lean-max-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: lean-max-hardware-${{ inputs.revision }}-${{ github.run_attempt }}
          path: ${{ runner.temp }}/lean-max-${{ github.run_id }}-${{ github.run_attempt }}
          if-no-files-found: error
          retention-days: 14
```

This proposal does not add a required branch-protection check or automate
promotion. Action references must be reviewed and pinned to approved immutable
action SHAs before installation. The eventual host must enforce its approved
GPU UUID rather than let arbitrary dispatchers allocate other devices. The
workflow's ordinary nonzero command exit is essential: do not add
`continue-on-error`, `|| true`, a skip allowance or a cached successful receipt.
