# Fail-closed GPU hardware acceptance

Status: implementation and offline failure tests only. Real Mojo compilation,
GPU execution, profiler compatibility, Lean acceptance and hardware performance
remain unvalidated. No component promotion, hardware registration or remote job
is authorized by this document.

## Two different modes

Ordinary development retains visible skips:

```sh
python -m pytest -q tests/frontier/test_lean_max_gpu_hardware.py
```

`LEAN_MAX_GPU_REQUIRED=1` disables the missing-runner skip and instead fails
the module's fixture if `LEAN_MAX_GPU_RUNNER` is absent or not executable.
This test switch is useful for diagnosing a host; a passing pytest invocation
alone is **not** a hardware acceptance receipt.

The standalone `hardware_acceptance.py` entry point requires an explicitly
configured GPU runner build destination, the full reviewed commit SHA and a
specific NVIDIA GPU UUID. It builds both runners from that checkout with the
pinned compiler. It never substitutes a CPU runner, a prebuilt executable,
an imported comparison report or a cached profile for the required execution.

## Reproduce locally on an approved host

The first observer implementation supports Linux with NVIDIA CUDA and Nsight
Systems (`nsys`). AMD and profiler schemas lacking the required fields are
rejected. A host administrator must already have installed the pinned Pixi
environment, Lean 4.35.0, the driver, and an appropriate Nsight Systems release.
No host permissions, driver settings or runner registrations are changed by
this command. Do not dispatch it to a remote host without separate approval.

From the repository root, replace the two literal placeholders below with the
reviewed full SHA and the approved host's GPU UUID. Use a new output directory
outside the checkout. The GPU runner path must lie inside that new directory;
it is the destination for a mandatory fresh build, not an existing binary.

```sh
git checkout --detach REVIEWED_FULL_COMMIT_SHA
pixi install
pixi run python -m experiments.frontier.lean_max.hardware_acceptance \
  --expected-revision REVIEWED_FULL_COMMIT_SHA \
  --gpu-uuid GPU-APPROVED-HOST-UUID \
  --gpu-runner /tmp/lean-max-hardware-review-001/mojo_gpu \
  --repeats 3 \
  --out /tmp/lean-max-hardware-review-001
```

`lean`, `mojo`, `nsys`, `nvidia-smi` and `pixi` must be executable in that
environment. The gate checks Mojo `1.1.0.dev2026090805`, installed Modular/MAX
`26.6.0.dev2026090805`, and Lean `4.35.0`. `--lean`, `--mojo` and `--nsys`
can specify absolute executable paths. Nsight/Pixi/driver versions and binary
hashes are recorded rather than inferred from the executable name.

The gate starts with `accepted: false`. Failures return nonzero and preserve
a rejected hardware-acceptance.json plus available logs. A killed process
can leave an incomplete false receipt. Existing output directories are always
refused; a previous success cannot survive a failed rerun at the same location.
No successful receipt is created until every gate completes. Archive the
whole output directory, not just the final JSON. The receipt's SHA-256 artifact
inventory binds the profiles, binaries, complete logs, corpus, traces, theorem
sources and benchmark reports.

## What must pass

1. The full requested commit equals HEAD; tracked and untracked source changes
   are refused. Every tracked file is hashed before execution. Revision, tree,
   source hashes, runner hashes and tool executable hashes must still match
   after all checks. Outputs are kept outside the checkout.
2. The configured toolchain, requested GPU UUID and driver inventory must be
   available. Both CPU and GPU builds must produce fresh executables. Failed
   builds cannot fall through to stale binaries. Lean must reject the forged
   `False` theorem with a checker error, not merely be missing or time out.
3. The existing real-device hardware suite must run with zero skips, errors or
   failures and at least its ten cases. It exercises repeated candidate parity,
   canonical trace equality, maximum buffers and malformed CLI rejection.
4. The existing comparison harness must cover **all 34 problems** in all four
   lanes at 64 records / 32 rounds, for every requested repetition (2–10).
   CPU and GPU results must equal the complete independent Python result.
   Missing, duplicated, timed-out, divergent or unsuccessful expected
   constructions fail acceptance. Lean grind comparisons must also complete.
5. The corpus contains **28 expected constructions and six non-derived
   controls** at these budgets. Every derived Python, Mojo CPU and GPU result
   must have actual Lean acceptance. Each retained version-one trace is decoded,
   completely replayed again, compared byte-for-byte with the independent CPU
   reference, and bound to the exact Lean source checked by the harness.
   The six controls must remain `not_derived` and never count as proofs;
   they are not theorem-falsehood claims. No unexpected refusal is allowed.
6. Every device-dependent search must have successful complete candidate parity
   and launch observations. Host seed-only proofs are explicitly classified;
   at least one accepted construction must actually use device proposals.
7. Nsight Systems profiles the same comparison process tree and exports fresh
   CUPTI activity. Completed `candidates_kernel` intervals must match every
   runner PID and launch count, and each process-local CUDA device must map to
   the approved UUID. Self-reported `METRICS launches` is insufficient.

`gpu_bridge.py` adds host-observed PID, canonical input-argument SHA-256,
output SHA-256 and successful candidate-parity fields to telemetry. The device
protocol and canonical version-one proof trace format remain unchanged.

The profiler reader follows NVIDIA's documented
[SQLite schema, process-ID encoding and GPU-identity mapping](https://docs.nvidia.com/nsight-systems/AnalysisGuide/index.html).
It requires `CUPTI_ACTIVITY_KIND_KERNEL`, `StringIds` and
`TARGET_INFO_CUDA_DEVICE` with the columns named in `validate_profile`.
Missing process/device mappings or incompatible schema changes cause rejection;
they are not silently replaced with inventory IDs. Preserve the `.nsys-rep`
so the observation can be re-exported and independently inspected. Profiling
children across containers/PID namespaces must preserve the PID mapping;
otherwise the host is not supported by this observer yet.

## Offline tests and evidence limits

```sh
python -m pytest -q tests/frontier/test_lean_max*.py
```

The new test module fabricates packets, checker records and SQLite activity
solely to test policy rejection. It tests absent configuration/binaries,
compiler failure, unavailable accelerators, timeouts, missing/skipped suites,
incomplete rows, failed proofs, CPU mismatches, mutated traces/theorem sources,
and absent/inconsistent profiler launches, PIDs and UUIDs. Existing GPU bridge
tests exercise malformed runner framing, candidate values, output caps and
timeouts. No simulated test produces a successful hardware acceptance receipt.

The receipt means bounded hardware **conformance on a trusted approved host**.
It is not remote attestation against a malicious host, mathematical authority
for unrelated problems, or a proof of the compiler/runtime. Public research
exchange submissions must still replay their own traces and run Lean locally;
contributed compute alone never grants verified-result status.

Benchmark wall time, build time, allocation/transfers, launch/synchronization,
replay, Lean checking, RSS and all failed controls remain visible. This first
gate profiles the entire comparison; profiler overhead and uncontrolled driver
caches limit its performance interpretation. Kernel intervals are not SM
utilization, explicit buffers are not whole-device peak memory, and neither
monetary cost nor acceleration is established. Promotion still needs independent
host reproduction, comparable unprofiled measurements, complete device memory
and cost accounting, a mature CPU baseline and review under issue #91.

## Workflow and runner changes

No workflow change is required for an approved **local** host run. The separate
[CI proposal](GPU_CI_PROPOSAL.md) is review material only. Do not install it,
register hardware, dispatch a remote job or promote the component until the
user approves those specific actions after reviewing local hardware evidence.
