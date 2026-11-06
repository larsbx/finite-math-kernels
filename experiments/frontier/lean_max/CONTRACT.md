# Lean-MAX experimental proof-construction boundary (stage 0)

Status: NON-AUTHORITATIVE CPU reference, not a Mojo/MAX GPU prover, not a Lean kernel and not an acceleration claim. Owner: finite-math-kernels/experiments/frontier.

The [bounded GPU candidate prototype](GPU_PROTOTYPE.md) supplies opt-in device
source and offline conformance coverage. Compilation and genuine device
validation remain pending; this does not promote the CPU or GPU implementation.
The [strict hardware acceptance mode](HARDWARE_ACCEPTANCE.md) rejects missing
runners, skipped hardware tests, failed parity, incomplete Lean acceptance and
missing independent device observations. Offline tests are not hardware evidence.

## Restricted domain
One uninterpreted sort (alpha), atoms, and explicitly listed unary function applications. Terms form a topologically ordered duplicate-free DAG. Premises are named equalities; a goal is an equality. Symbols accept only ASCII alphanumeric identifiers beginning with a letter. Arbitrary Lean expressions are not accepted.

Derivation rules: hyp, refl, symm, congr (same unary function), trans. Each step has lhs/rhs IDs, a rule, references to earlier steps and optional data. The independent Python replayer validates the step endpoints, refs, premise binding and congruence children. This is *not* a verified checker or a substitute for Lean. A generated Lean source file must be accepted by Lean before a result can be called a proof.

Finite, monotonic closure explores only the explicitly listed term DAG. A cap returns INCONCLUSIVE. NOT_DERIVED means finite closure exhausted, not theorem falsehood and not a counterexample. Never promote these statuses to domain-claim authority.

## Version 1 trace interchange

The codec accepts derived certificates and independently replays them in both directions. Refusals remain in the stage 0 search result format. The bytes are canonical for a particular ordered trace. A goal may admit multiple valid traces.

The 44-byte header contains the seven ASCII bytes `LMTRACE`, version byte 1, a 32-byte SHA-256 problem digest, the record count and the goal record index. Integers in the header and records are unsigned 16-bit little-endian. The digest preimage is a compact ASCII JSON array with no whitespace. Its elements in order are the atom names, function names, term triples (kind, name, child index or null), premise pairs, and goal pair. All arrays preserve input order.

Each record contains six integers in order: opcode, left term, right term, first reference, second reference, and premise index. Opcodes 0–4 are hypothesis, reflexivity, symmetry, congruence, and transitivity. Only hypothesis uses the premise index. Symmetry and congruence use the first reference. Transitivity uses both. All unused fields must be 65535. The congruence function is inferred from the left application and replay verifies both endpoints and their children.

The decoder rejects any byte length inconsistent with the record count and keeps the existing 16,384-record limit (196,652 bytes including the header). A digest identifies the intended problem. Replay establishes validity, and Lean independently checks the reconstructed theorem.

## Try locally
Run python -m pytest -q tests/frontier/test_lean_max.py
Run python experiments/frontier/lean_max/reference.py experiments/frontier/lean_max/demo.json --lean-out /tmp/LeanMaxDemo.lean
Then run lean /tmp/LeanMaxDemo.lean (actual independent Lean gate).

The Python tests invoke Lean only if the binary is installed. The pinned Modular toolchain does not supply Lean; passing Python tests alone does not establish a Lean-accepted theorem.

## Acceptance gates
1. The pinned Lean 4.35.0 workflow decodes a versioned trace, checks the reconstructed source, and rejects a mutated Lean proof. Report acceptance against the revision that ran the gate.
2. Define a compact device IR with bounded indices, canonical serialization and rejection of aliasing, overflow and malformed references.
3. Implement Mojo CPU candidate enumeration with byte-for-byte equivalent replayable records and deterministic tests across generated corpora.
4. Implement an opt-in Mojo/MAX GPU batch-matching kernel on a genuine GPU runner. MAX CPU threads do not count as GPU execution. Do not trust GPU output.
5. Replay with Python, reconstruct in Lean, and run actual Lean checking on every candidate used to support a claim.
6. Benchmark solved theorems and total throughput including compile time, host/device transfers, reconstruction and kernel check, under exact pinned hardware and compiler metadata. Compare against Lean grind and a mature CPU baseline; record failures/no-runners.
7. Promote to a shared component or independent lean-max repository only when reproducible GPU proof-construction results and cross-project consumers justify it. my-math-homelab may orchestrate but never grants theorem authority; Biz-kit Proof Bank consumes only independently checked, source-pinned results.

Do not alter the canonical kernel/ tree or the frontier candidate registry until a runnable Mojo implementation and the existing frontier corpus/replay interface are ready.
