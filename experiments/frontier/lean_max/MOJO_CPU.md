# Lean-MAX stage 1: bounded Mojo CPU inference candidate enumeration

This stage adds a **CPU-only** Mojo executable, `experiments/frontier/lean_max/mojo/candidates.mojo`. It is an accelerator *candidate producer*, not a proof checker, and not a GPU result. The Python `cpu_bridge.py` runs Mojo each frontier round, compares the complete candidate list against an independent CPU Python enumerator, checks each candidate before admission, and independently replays the resulting proof and reconstructs a Lean 4 proof script. This deliberate reference-parity overhead makes the implementation a correctness/conformance experiment, NOT a performance benchmark.

## Canonical CLI

```text
candidates A F N S [kind symbol child] * N [lhs rhs] * S
```

All arguments are nonnegative canonical decimal integers. Caps: `1 <= A <= 128`, `0 <= F <= 16`, `1 <= N <= 128`, `0 <= S <= 64`. Kind 0: atom ID `< A`, child = 0. Kind 1: unary function ID `< F`, child `< current term index`. Duplicate terms, forward references, invalid arity, and invalid IDs are refused by the executable.

Output is zero or more lines of:
```text
S <rhs> <lhs> <premise-step-index>       # symmetry
C <lhs-app> <rhs-app> <step-index> <function-id>    # unary congruence
T <lhs> <rhs> <left-step-index> <right-step-index>  # transitivity
```

Output order: for each source equality, symmetry followed by congruence for each listed function; then transitivity in source-outer, right-inner step order. References point only to the given input proof frontier. All pairs are candidates, including duplicates and trivial identities. The Python bridge checks byte-equivalent semantics and rejects any missing or extra candidates.

## Run

```sh
pixi run mojo build -O3 experiments/frontier/lean_max/mojo/candidates.mojo -o /tmp/lean-max-candidates
LEAN_MAX_CPU_RUNNER=/tmp/lean-max-candidates pixi run python -m pytest -q tests/frontier/test_lean_max_cpu.py
```

A scoped GitHub Actions job runs this with the repository's existing pinned Mojo. **Compilation and parity are not verified until its exact-head hosted job passes.** The separately pinned Lean job checks the resulting proof script as an independent step. A missing runner is a skip in the broad Python suite, not a proof of Mojo correctness.

## Next

Make batches GPU-resident with a device-friendly indexed DAG, prove CPU/GPU candidate parity, add GPU hardware metadata, and benchmark end-to-end solved theorems with transfer/replay/Lean-check overhead. Never infer a speedup from the reference-parity implementation.
