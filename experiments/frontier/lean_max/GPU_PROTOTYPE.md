# Lean-MAX bounded GPU candidate prototype

Status: source implemented; offline conformance tested; Mojo compilation and
GPU hardware validation pending. No GPU proof or acceleration result is claimed.
Depends on the version-1 certificate work in draft PR #92 at
`3734d7e4dd0a457311bcbcafbd18ce8c765f56f0`; main inspected at
`4fea04f7c2f88707bca8642d01711331dbeac792`. Follow-up: issue #91.

## Device work and authority

`experiments/frontier/lean_max/mojo/gpu_candidates.mojo` uses a real `DeviceContext`, explicit host/device
copies, compilation and a device kernel launch. `has_accelerator()` refusal is
an error, with no CPU fallback. `--gpu` is mandatory. The source uses the
repository's pinned Mojo `1.1.0.dev2026090805` / Modular
`26.6.0.dev2026090805` GPU API; this pin has not been compiled in this workspace.
The upstream [GPU API documentation](https://docs.modular.com/mojo/manual/gpu/)
describes the device execution model; compiling the pinned source and testing
the actual device remain acceptance requirements.

The host validates a duplicate-free, topologically ordered term DAG before
allocation. Input is the existing CPU lane's indexed DAG and frozen frontier.
Host proof checks establish that the input frontier is valid. The executable
checks structural input bounds; it does not establish premise soundness.
All device arithmetic is bounded integer indexing; no mathematical predicate
uses floating point.

For frontier length `m` and function count `f`, allocate
`m*(1+f) + m*m` slots. Slot `s*(1+f)` is symmetry; the following `f` slots
are congruence in function order. The final `m*m` slots are transitivity in
left-reference-outer, right-reference-inner order. Each thread writes one
entire slot, including absent candidates. There are no atomic appends or
device dependencies between proposals.

Each slot has six signed int32 fields: opcode, lhs, rhs, first reference,
second reference, function ID. Opcodes 2/3/4 mean symmetry/congruence/transitivity.
Unused fields are -1; an absent slot is six -1 values. This is a private device
buffer/protocol, **not a change to the version-1 certificate format**. Final
certificates retain the 44-byte header and 12-byte records from PR #92.

`gpu_bridge.py` rejects malformed framing, padding, integer overflow, invalid
endpoints/functions/references, duplicate full proposal records, missing or
reordered slots, and incomplete batches. It checks every proposal using only
the frozen input references, compares exact slots against the offline model,
and compares the resulting list against independent CPU enumeration. Repeated
equality endpoints from different derivations are legitimate candidates; the
host search keeps the first proof in the established order. This preserves
CPU/Python trace bytes and the existing version-1 decoder and replay gates.

## Resource bounds

| Resource | Limit |
| --- | ---: |
| Atoms / functions / terms / frontier records | 128 / 16 / 128 / 64 |
| Search records / rounds | 64 / 32 (may be lowered) |
| Candidate slots / output bytes on device | 5,184 / 124,416 |
| Input bytes / total explicit device buffers | 2,048 / 126,464 |
| Kernel block size / launches per nonempty frontier | 128 / 1 |
| Each runner call / each stdout and stderr stream | 20 seconds / 1,000,000 bytes |

An empty frontier has a four-byte output allocation and no launch. Compilation
and driver allocations are outside the explicit buffer accounting and must
be measured separately. Timeouts kill the process group. Invalid device
output fails the run. Search exhaustion means `not_derived`; record/round
caps mean `inconclusive`. Neither means theorem falsehood. No cap is relaxed
and no frontier is truncated to make a GPU run succeed.

## Reproduce without a GPU

From the repository root:

```sh
python -m pytest -q tests/frontier/test_lean_max.py tests/frontier/test_lean_max_trace.py tests/frontier/test_lean_max_gpu.py tests/frontier/test_lean_max_benchmark.py
```

The offline model tests 34 fixed problems, including nested applications,
non-derivable goals, trivial goals, multiple derivations and budget refusals.
Full search checks exact trace-byte parity at four record/round budgets.
Boundary coverage reaches 64 frontier records and 16 functions. Mutations cover
indices, forward references, duplicates, overflow, malformed data, ordering,
missing proposals, runner errors, output caps and timeouts. These tests do not
compile or execute the Mojo kernel.

## Reproduce on an approved GPU host

No workflow or runner registration is added by this prototype. Run locally on
an already authorized host with the pinned environment and an actual GPU:

```sh
pixi run mojo build -O3 experiments/frontier/lean_max/mojo/gpu_candidates.mojo -o /tmp/lean-max-gpu-candidates
LEAN_MAX_GPU_RUNNER=/tmp/lean-max-gpu-candidates pixi run python -m pytest -q tests/frontier/test_lean_max_gpu_hardware.py
```

The opt-in hardware suite repeats actual launches, checks deterministic
candidate and trace parity, exercises the maximum slot count, and calls the
compiled driver with malformed inputs. A configured but failing GPU runner
fails tests; a missing runner is a visible skip. This suite establishes
candidate parity only. Complete proof acceptance also requires Lean below.

## End-to-end comparison

The standalone `benchmark.py` follows Frontier's evidence conventions:
contract/corpus SHA-256 binding, source revision and dirty state, implementation
identity, explicit missing-runner/failure rows, resource budgets and independent
replay. It remains outside `candidates.toml`, whose current orbit-census
record/oracle interface does not accept Lean-MAX traces.

Put Lean **4.35.0** on PATH as well as the pinned Pixi environment. For example,
use `elan run leanprover/lean4:v4.35.0` as an outer command if that toolchain
is installed. The harness checks the exact Lean version and requires a forged
`False` theorem to fail before it can count accepted constructions.

```sh
pixi run python -m experiments.frontier.lean_max.benchmark --build --enable-gpu --repeats 3 --out /tmp/lean-max-comparison
```

Alternatively supply `--cpu-runner` and `--gpu-runner` binaries. GPU execution
requires `--enable-gpu`; omission records `disabled`. Build failures, missing
compilers, unavailable drivers, timeouts and verification failures remain in
the report. The JSON report, exact corpus, emitted traces and Lean sources
are retained in the output directory.

All construction lanes use the same 34 problems and record/round caps.
Python, Mojo CPU and GPU constructions run in fresh worker processes. Every
derived result is independently replayed, encoded, decoded, compared with the
reference trace, reconstructed, and checked by actual pinned Lean. Only then
is `proof_accepted` true. Lean `grind` receives the same theorem statements,
100,000 heartbeats and a 30-second process limit. Its kernel-accepted results
are reported separately as baseline proofs, since grind emits no version-1
construction trace and does not obey the search record/round cap.

Each GPU-lane row also records actual device launch count and whether it was
GPU-assisted. Goals established by host seed hypotheses/reflexivity alone do
not count toward GPU-assisted accepted constructions.

Record p50/p95 time to accepted proof and accepted throughput including failed
attempts; preserve all refusals. Capture binary build commands/time/hash,
compiler versions, GPU name/UUID/driver/total memory (NVIDIA or AMD inventory),
per-round device compilation, allocation, transfers, launch count and
launch-plus-synchronization wall time, explicit buffer bytes, constructor/child
peak RSS, reconstruction/replay time and Lean checking time. The launch timer
includes dispatch and synchronization; it is not a GPU event measurement.

This is a conformance harness with deliberate reference-parity overhead and
fresh-process startup. It does not control compiler/driver caches or provide
steady-state warm latency. Buffer sizes are not whole-device peak memory;
capture a vendor profiler trace for actual peak memory, kernel-only time,
power/energy and device occupancy, and archive it with the report. Monetary
runner cost and power mode remain unmeasured until supplied by the host.
No acceleration claim is justified until comparable measured CPU/GPU/Lean
results, complete costs and a stronger mature CPU baseline are available.

## Approval and remaining acceptance

The [November 5 offline receipt](evidence/gpu-offline-2026-11-05.json) records
the fixed corpus and source hashes. Its dry run produced 28 replayable Python
derivations and six `not_derived` outcomes. Both Mojo builds were unavailable;
all Lean checks were unavailable. Accepted constructions: zero. Valid-proof
p50/p95: unmeasured. Hardware execution, driver costs and acceleration:
unvalidated.

Local Python Frontier, claim-audit, provenance and reference suites passed
192 tests with 17 explicit skips (plus 16 unittest subtests). The direct
reference-integrity command passed. The six required Pixi task commands were
attempted but Pixi is absent; the independent property oracle also refused
because Mojo is absent. The full aggregate, Mojo CPU, Lean, property and
polyglot gates must run on the proposed exact head before acceptance.

The existing CPU generator, bridge, Lean workflow, trace codec, kernel tree,
Frontier registry and CI workflows are unchanged relative to PR #92. There is
no shared runner enabled or component promotion. Before adding GPU CI, present
the concrete workflow, runner labels/access boundary, expected cost/time caps
and hardware evidence for user approval. Promotion and merge also require
approval. Compilation failures must be repaired on the pinned toolchain, then
the offline, hardware, CPU and Lean gates rerun at the proposed exact head.
