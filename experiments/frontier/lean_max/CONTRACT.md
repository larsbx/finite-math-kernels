# Lean-MAX experimental proof-construction boundary (stage 0)

Status: NON-AUTHORITATIVE CPU reference, not a Mojo/MAX GPU prover, not a Lean kernel and not an acceleration claim. Owner: finite-math-kernels/experiments/frontier.

## Restricted domain
One uninterpreted sort (alpha), atoms, and explicitly listed unary function applications. Terms form a topologically ordered duplicate-free DAG. Premises are named equalities; a goal is an equality. Symbols accept only ASCII alphanumeric identifiers beginning with a letter. Arbitrary Lean expressions are not accepted.

Derivation rules: hyp, refl, symm, congr (same unary function), trans. Each step has lhs/rhs IDs, a rule, references to earlier steps and optional data. The independent Python replayer validates the step endpoints, refs, premise binding and congruence children. This is *not* a verified checker or a substitute for Lean. A generated Lean source file must be accepted by Lean before a result can be called a proof.

Finite, monotonic closure explores only the explicitly listed term DAG. A cap returns INCONCLUSIVE. NOT_DERIVED means finite closure exhausted, not theorem falsehood and not a counterexample. Never promote these statuses to domain-claim authority.

## Try locally
Run python -m pytest -q tests/frontier/test_lean_max.py
Run python experiments/frontier/lean_max/reference.py experiments/frontier/lean_max/demo.json --lean-out /tmp/LeanMaxDemo.lean
Then run lean /tmp/LeanMaxDemo.lean (actual independent Lean gate).

The Python tests invoke Lean only if the binary is installed. The pinned Modular toolchain does not supply Lean; passing Python tests alone does not establish a Lean-accepted theorem.

## Unimplemented acceptance gates
1. Pin a real Lean 4 toolchain and require generated-source checking in a focused hosted CI job; negative proof mutation must be rejected.
2. Define a compact device IR with bounded indices, canonical serialization and rejection of aliasing, overflow and malformed references.
3. Implement Mojo CPU candidate enumeration with byte-for-byte equivalent replayable records and deterministic tests across generated corpora.
4. Implement an opt-in Mojo/MAX GPU batch-matching kernel on a genuine GPU runner. MAX CPU threads do not count as GPU execution. Do not trust GPU output.
5. Replay with Python, reconstruct in Lean, and run actual Lean checking on every candidate used to support a claim.
6. Benchmark solved theorems and total throughput including compile time, host/device transfers, reconstruction and kernel check, under exact pinned hardware and compiler metadata. Compare against Lean grind and a mature CPU baseline; record failures/no-runners.
7. Promote to a shared component or independent lean-max repository only when reproducible GPU proof-construction results and cross-project consumers justify it. my-math-homelab may orchestrate but never grants theorem authority; Biz-kit Proof Bank consumes only independently checked, source-pinned results.

Do not alter the canonical kernel/ tree or the frontier candidate registry until a runnable Mojo implementation and the existing frontier corpus/replay interface are ready.
