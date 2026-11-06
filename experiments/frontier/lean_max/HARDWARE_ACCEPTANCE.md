# Lean-MAX GPU hardware acceptance

Status: implemented acceptance orchestration and offline fault tests; **not run
on hardware**. Mojo compilation, Nsight integration and Lean acceptance of this
implementation remain pending. This extends the prototype underlying draft
PR #92 and issue #91. The ordinary hardware pytest module retains its visible
missing-runner skips. Its successful exit is not a hardware acceptance receipt.

## Local acceptance command

Use an already approved, isolated Linux host with **one physical NVIDIA GPU**,
compatible driver, Nsight Systems CLI (`nsys`) and `nvidia-smi`. This first
observer adapter does not accept AMD, multi-GPU or MIG configurations. It makes
no changes to runner registration, device permissions, workflows or scheduling.
The adapter must itself be validated against the approved host's Nsight export
schema; unknown schemas refuse rather than silently reducing observation.

Install the repository's pinned Pixi environment before running. The gate
checks installed Conda package records for all nine pinned Mojo/Modular/MAX
packages, Mojo `1.1.0.dev2026090805`, and actual Lean **4.35.0** on PATH. Lean is
separate from Pixi; select the installed pinned toolchain in the host's Lean
installation first. No toolchain download is performed by the acceptance CLI.

From a clean checkout of the reviewed implementation commit:

```sh
# Replace this literal with the approved full 40-character implementation SHA.
reviewed_sha=REPLACE_WITH_APPROVED_COMMIT_SHA
# This directory must not exist and must be outside the repository.
evidence_dir=/tmp/lean-max-hardware-acceptance

pixi run python -m experiments.frontier.lean_max.hardware_acceptance \
  --expected-revision "$reviewed_sha" \
  --gpu-runner "$evidence_dir/gpu-candidates" \
  --cpu-runner "$evidence_dir/cpu-candidates" \
  --out "$evidence_dir"
```

Explicit runner paths are **fresh build destinations**, not trusted prebuilt
binaries. Both must be distinct direct children of the new evidence directory.
The command always rebuilds both from this checkout. Use `--mojo`, `--lean`,
`--nsys` or `--smi` to select approved local tool executables. It never substitutes
Python output for an unavailable runner. Missing arguments, binaries, devices,
package pins, failed compilation, profiling, parity, replay or Lean checks
return nonzero. After a run has started, failures leave a rejected
hardware-receipt.json. Argument errors, an existing output directory or an
invalid destination can fail before a receipt exists. A prior receipt is never
reused. An interrupted process or incomplete artifact directory is not acceptance.

## Required evidence

The gate requires all of the following; there are no allow-missing switches.

1. The supplied full Git revision equals HEAD. The checkout is clean, including
   untracked files. Every tracked source file's actual bytes and executable mode
   match HEAD, even if marked assume-unchanged. SHA-256 covers the entire source
   tree, including corpus generator, checker, toolchain manifest and tests.
   The same revision and hashes are checked again after execution.
2. Actual version probes, installed package records, local tool paths/hashes,
   positive and negative Lean controls, CPU/GPU compiler invocations, logs and
   freshly built binary hashes are retained. These identities are checked again
   at completion. Compilation refusal cannot turn into an accepted receipt.
3. The existing 34-problem corpus is serialized in its original order with
   SHA-256 `c21b0cb4215c490a825d7972db4efef3a176b8ecffff0ee7d84c535b0f891aa3`.
   Records/rounds remain 64/32 and repetitions are fixed at three.
4. Each case and repetition runs a nonempty candidate probe **and the complete
   bounded GPU search** under Nsight. Even a seed-only goal must exercise the
   device. Raw bounded stdout/stderr and the frozen frontier are saved for every
   candidate call. The parent independently checks all slots and CPU candidate
   parity again. The final complete search result must equal Python's result.
5. Raw Nsight reports and SQLite exports must contain positive-duration
   `candidates_kernel` device events. Their exact count must equal all candidate
   calls' launch counts. GPU UUID/name in the profiler must match the single
   GPU inventoried by the driver. Missing tables, names, identity or activity
   reject. Runner-reported counters alone cannot establish a device launch.
6. Every derived profiled result is independently replayed, encoded, decoded,
   reconstructed as Lean and checked by actual pinned Lean. All records are
   replayed, including records not needed by the final goal. Canonical wire
   version one remains unchanged (44-byte header, 12-byte records).
7. The existing standalone benchmark then runs unprofiled using the same newly
   built runners: Python, Mojo CPU, Mojo GPU and Lean grind, three repetitions
   of all 34 problems. Every one of the 28 expected derivations per construction
   lane and repetition must pass Lean, with exact retained trace/source parity.
   The six expected unsuccessful searches must match Python's full refusal
   result and remain unsuccessful searches. They are not mathematical
   counterexamples. No partial, duplicate, skipped or missing lane is accepted.
8. The receipt hashes every retained evidence artifact, including report,
   corpus, profiler data, traces, Lean files and check logs. A successful process
   exit requires `accepted: true` in the dedicated hardware receipt. The
   benchmark's comparison receipt alone has no hardware acceptance status.

Nsight collection/export and device event tables follow NVIDIA's official
[CLI guide](https://docs.nvidia.com/nsight-systems/UserGuide/) and
[SQLite analysis guide](https://docs.nvidia.com/nsight-systems/AnalysisGuide/).
Raw profiles are retained so the event interpretation can be independently
reviewed with the installed NVIDIA tools. Unknown or incompatible tooling is an
acceptance blocker, not evidence of absent GPU work.

## Offline verification

```sh
python -m pytest -q tests/frontier/test_lean_max_hardware_acceptance.py \
  tests/frontier/test_lean_max_gpu.py tests/frontier/test_lean_max_benchmark.py
```

These tests use simulated compiler/runner failures, synthetic protocol packets,
synthetic comparison rows and tiny synthetic SQLite fixtures. They exercise
missing runners/tools/accelerators, compiler errors and absent binaries, wrong
pins, negative controls, missing launches, wrong kernel/UUID, zero-duration
activity, schema failures, corrupt candidate output, failed independent parity,
partial/duplicate corpus rows, wrong traces, missing Lean acceptance, timeouts,
interruptions and stale receipt directories. Passing them establishes rejection
logic only. They do not compile Mojo, execute a GPU or kernel-check a proof.

## Review, reproducibility and authority

Archive the entire evidence directory, not just the receipt. Reproduce by
running the same command against the same approved revision in a second clean
checkout on an approved host and compare corpus/source/binary identities and
canonical trace digests. Timings and profiler timestamps will differ. Independently
re-run pinned Lean on the saved proof files; the gate also recomputes their
contents from the complete retained version-one traces.

The receipt assumes a trusted local host, driver, installed compiler/Lean and
profiler. It is not remote attestation and does not authenticate an adversarial
contributor's operating system or fabricated receipt. A public research exchange
must independently replay/check submitted mathematical artifacts; submitted
compute, launch telemetry and even an accepted local conformance receipt do not
raise theorem status or grant library/compute credits automatically.

The benchmark retains valid-proof p50/p95, throughput including failures,
compile, transfer, allocation, reconstruction and Lean checking costs. Nsight
runs are separate from the unprofiled timing comparison. Caches, whole-device
peak memory, energy, rental cost and a mature optimized CPU baseline remain
outside this acceptance gate. Its successful receipt would establish bounded
hardware conformance and Lean-accepted constructions, not acceleration or
promotion. Shared registration, remote execution and promotion require separate
authorization and independently reproducible evidence.

## Implementation validation — November 6, 2026

Local checks passed: 236 tests across Frontier, claim audit, reference checks
and toolchain-pin tests, with 17 visible skips and 16 passing unittest subtests;
seven additional provenance tests; direct reference/provenance checks; Python
compilation and Git whitespace checks. The new acceptance test module accounts
for 48 offline tests. Running it beside the unchanged development hardware
module yields 48 passes and ten visible hardware skips.

All six required Pixi task commands were attempted but unavailable because Pixi
is absent. The direct independent property oracle exited 2 because Mojo is
absent. Full aggregate, native Mojo, polyglot, actual profiler/GPU execution and
Lean acceptance must still run on the approved implementation revision. There
is no accepted hardware receipt or acceleration result from this environment.

## Workflow/runner proposal, not applied

See [the separate approval proposal](GPU_WORKFLOW_PROPOSAL.md). No active
workflow or host configuration is changed by this implementation.
