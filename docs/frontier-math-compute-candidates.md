# Frontier mathematics workloads for Mojo

Status: research and benchmark charter  
Authority: performance evidence only; never theorem, proof, or certificate acceptance

## Decision

The strongest first benchmark is **finite-field orbit and word enumeration with
certificate replay**. It combines a current research frontier, very large batches
of independent work, fixed-width modular arithmetic, and small deterministic
outputs. It is a fair contest for both Mojo and Bend.

The strongest Mojo-specific benchmark is **batched NTT/negacyclic arithmetic**.
Its regular memory access, compile-time specialization, SIMD lanes, and GPU
mapping align directly with Mojo. Bend remains a useful challenger, but its
current U32/F32-only numeric surface and balanced-call requirement make it a
poor authority for wide exact arithmetic.

The strongest estate-native irregular benchmark is **Pisot substitution
balanced-pair/SCC census**. It should be the third slice, after the harness has
proved it can distinguish kernel speed from scheduler, allocation, and
serialization costs.

This is deliberately not a language beauty contest. Julia is the independent
mathematical oracle and rapid algorithm laboratory; Mojo is the candidate
authoritative execution kernel; Bend is an experimental parallel search engine;
Rust/C++ is the mature systems baseline. A faster result has no mathematical
authority until its emitted certificate is replayed by the domain owner.

## Candidate ranking

| Rank | Workload | Research question | Hardware shape | Mojo thesis | Bend thesis | Initial home |
|---:|---|---|---|---|---|---|
| 1 | Finite-field orbit / thin-group word census | Exceptional fibers, orbit statistics, collision and stabilizer witnesses | Millions of independent fixed-width trajectories; bounded reductions | SIMD/GPU batches with explicit layouts and reductions | Native divide-and-conquer can expose massive leaf parallelism | `giant-fibers-finite-fields-thin-groups`, kernels extracted here |
| 2 | Batched NTT and negacyclic convolution | Fast exact transforms for finite RFFT, MLWE/MLWR, lattice and transcript workloads | Dense, regular butterflies; high arithmetic intensity | Best match for specialization, SIMD and GPU kernels | Useful only for fixed U32-friendly moduli and balanced stages | `falcon-ntt-ftt`, `NLAP-JT`, kernels here |
| 3 | Pisot substitution BPA/SCC census | Search for realized producer-free recurrent components and degree/size frontier specimens | Wide independent substitutions followed by irregular graph growth | Fast compact structs, hash tables, work queues, CPU/GPU filtering | Strong for independent specimens; weaker for uneven SCC workloads | PSC repo, reusable word/automaton kernels here |
| 4 | Finite quadratic orbit and incidence search | Exact orbit types, modular obstructions, multiset/projective incidence candidates | Independent parameters/seeds with early exits; fixed-width filter then exact replay | Good hybrid GPU filter + CPU exact verification | Good at the outer independent tree if witnesses stay U32 | finite Mandelbrot/Julia-set repos |
| 5 | Finite-field polynomial-system screening | Modular solutions and obstruction witnesses feeding exact/certified solvers | Independent primes/assignments; dense evaluation; divergent pruning | Strong batched evaluation and SIMD reductions | Plausible pure search backend | new consumer; kernels here |
| 6 | Local height / BSD contribution batches | Local data over many primes/places and candidate curves | Independent local computations but heavy multiprecision/CAS boundary | Useful only for fixed-width filters and data movement | Poor initial fit because wide integers and mature libraries matter | height-pairings repo |
| 7 | Exact rational or m-adic linear algebra | Certificate-producing elimination and enclosure refinement | Dependency-heavy, branchy, growing integers | CPU optimization target, not first GPU showcase | Bad fit until numeric and sharing limits improve | kernels here |

## Why rank 1 first

The first workload must test the user's actual hypothesis: whether automatic
parallelism can beat carefully shaped kernels when the work is embarrassingly
parallel. Finite-field orbit enumeration gives both systems their best case
without relaxing semantics:

1. Generate the same canonical list of seeds or group words.
2. Apply the same recurrence over a pinned prime field.
3. Emit only canonical witnesses: counts, first-hit indices, orbit hashes, and
   selected trajectories.
4. Replay every selected witness independently.
5. Compare throughput, energy, memory, compile latency, and engineering effort.

Bend should not be asked to emulate arbitrary-precision arithmetic in the first
round. Bend 2 (2.0.25, measured here) has `Nat`, `U32` and `F32` and nothing
wider: `U32` add, mul, xor and shifts are native and wrapping, but `U32.div`
and `U32.mod` are bit-serial library code. Parallelism is a balanced binary
fork-join (`a b = f(x) g(y)`) over affine values, and the runtime takes
`--threads`. That makes a fixed-prime, leaf-independent census the honest test.
It also means a Bend win is evidence for the outer search scheduler, not a
reason to move canonical exact arithmetic out of Mojo.

## Benchmark lanes

### Lane A: fixed-width leaf throughput

- Prime fields fitting U32, with separately tested overflow-safe multiplication.
- Equal seed corpus and iteration cap.
- CPU single-core, CPU all-core, and one-GPU modes.
- Mojo, Bend, Julia, and Rust/C++ implementations.
- No disk writes inside the timed region.
- Mandatory digest and witness equality after the timed region.

This is the Bend-friendly lane and must be implemented first.

### Lane B: structured dense arithmetic

- Forward/inverse NTT and negacyclic convolution.
- Pinned moduli, roots, layouts, batch sizes, and transform sizes.
- Scalar, SIMD, and GPU variants where supported.
- Measure cold compile separately from warm execution.
- Validate against naive convolution for small sizes and Julia vectors for all
  published sizes.

This is the Mojo-favorable lane. Publishing only Lane B would be selection bias.

### Lane C: irregular research search

- Balanced-pair expansion, SCC decomposition, and producer search.
- Identical caps and three-valued outcome: witnessed, refuted, inconclusive.
- Report work distribution, queue depth, allocation, duplicate rate, and tail
  latency, not only total runtime.
- Retain the exact input and canonical output record for every claimed anomaly.

This lane determines whether Mojo's low-level control pays off outside dense
numeric kernels and whether Bend's balanced-call model survives real skew.

## Required measurements

Each result row records:

- repository, revision, dirty flag, compiler/runtime version;
- CPU, GPU, driver, OS, power mode, thread count, affinity;
- algorithm ID and semantic contract version;
- corpus ID and SHA-256;
- warmup policy and cold/warm distinction;
- wall time distribution (minimum, median, p95), throughput and peak memory;
- host-to-device and device-to-host time separately;
- compile time and executable size;
- energy when the host exposes a credible counter;
- output digest, witness count and replay result;
- implementation size and a short engineering-effort note.

Speedup is reported against the fastest correct mature baseline, never only
against Python. A timeout, compiler failure, unsupported type, or incorrect
digest remains in the table. “Embarrassing” results are part of the result.

## Correctness and authority firewall

The benchmark may establish only:

- that two implementations produced byte-identical canonical records;
- that a domain-owned replay predicate accepted a record;
- measured performance under the recorded environment.

It may not establish:

- a theorem from repeated successful runs;
- that absence under a cap is mathematical nonexistence;
- that Julia, Bend, or a GPU kernel is authoritative because it agrees;
- certificate acceptance outside the consumer's stated predicate;
- a change to conjecture or proof status.

Mojo remains the proposed kernel boundary because the estate already uses its
exact types and fail-closed consumers. Julia remains independent,
non-authoritative evidence. Bend is an explicitly experimental execution
candidate. Domain repositories own the research claim and certificate
predicate.

## Promotion gates

A candidate enters implementation only if all are true:

1. The frontier question and the finite computational subproblem are stated
   separately.
2. The input corpus is canonical and versioned.
3. The output has a compact deterministic encoding.
4. A second implementation can replay or recompute selected witnesses.
5. “Cap reached” maps to inconclusive.
6. The workload is large enough to amortize compilation and transfer.
7. A performance win would change the feasible research envelope.

A language is promoted for a workload only after:

- three hardware classes or an explicit single-GPU scope;
- at least two independent correct implementations;
- no unexplained digest divergence;
- reproducible scripts and raw result records;
- measured end-to-end benefit, not kernel-only theatre.

## Implementation sequence

Status (2026-09-22): Slice 0 is in place and Slice 1 has its CPU correctness
path. `benchmarks/frontier/harness.py` builds, runs, replays and records
(`pixi run bench-frontier`; tests in `pixi run test-frontier`). The Lane A
contract is `benchmarks/frontier/ff_orbit_census/CONTRACT.md`: a census of
reduced Apollonian words over `F_p`, replayed by the spec oracle
`benchmarks/frontier/ff_orbit_census/reference.py`. Mojo and Rust
(`cpu_single`, `cpu_all`) emit byte-identical records on every shipped
corpus, and so does Bend 2 (`cpu_single` and `cpu_all`, via its runtime's
`--threads`). Every kernel reduces residues by conditional subtraction, the
only reduction Bend can afford, so the lanes compare languages rather than
modular-reduction strategies. Mojo `cpu_all` runs on MAX's task runtime
through `parallel_fold`, whose in-order fold keeps the record identical at
every thread count; the Mojo std itself has no CPU task runtime. Julia is
recorded as not implemented, and GPU lanes as having no runner. On the first
container run the Rust baseline was the slowest single-thread kernel, so it
needs a tuning pass before any speedup against it is claimed.

### Slice 0 — harness and contracts

Create `benchmarks/frontier/` with a machine-readable manifest, JSON Lines
results, corpus digests, environment capture, and a comparator that refuses
semantic-contract mismatches.

### Slice 1 — orbit census shootout

Implement a U32 prime-field recurrence in Mojo, Bend, Julia, and Rust. Use
fixed seed blocks and deterministic tree partitioning. Emit aggregate digests
plus a configurable witness sample.

A companion contract, `orbit-census-v1` (`docs/polyglot-orbit-census-design.md`),
takes the rho census of `x^2 + c` through the same Mojo-decides discipline
with an Elixir orchestrator and a model-checked choreography. It is a protocol
lane, not a second Lane A. Its challenger is Bend 2, the same pinned build as
the harness, with the declared domain `p < 2^16`.

### Slice 2 — batched NTT

Implement scalar and optimized Mojo variants, Julia oracle vectors, and the
strongest available Rust/C++ baseline. Add Bend only if its arithmetic expresses
the pinned modulus without semantic contortions.

### Slice 3 — PSC census

Extract the smallest domain-owned BPA/SCC workload with existing canonical
fixtures. Parallelize across substitutions first; do not prematurely parallelize
inside one graph. Then test skewed work stealing separately.

### Slice 4 — research frontier runs

Only after the lanes reproduce locally and in CI should consumers increase
degree, word length, prime range, orbit depth, or collar. Frontier results are
published with certificates and replay commands, never as benchmark summaries
alone.

## Sources and runtime reality

- Mojo documentation and releases must be pinned with each result; the current
  repo already pins a Modular nightly, so comparisons across nightlies are not
  silently pooled.
- Bend 2 (github.com/bendlang/bend) compiles one C file for CPU and GPU,
  schedules a contention-free binary fork-join, and has only 32-bit machine
  numbers, with software division. Its `IO.now` ticks in milliseconds, so Bend
  kernel times are ms-quantized. The benchmark treats all of these as measured
  facts, not as reasons to exclude it.
- Julia provides mature numerical experimentation, SIMD-aware code, parallel
  computing, and GPU packages; it is both a serious performance contender and
  the independent oracle, but those roles must use separate code paths and
  recorded revisions.
- Rust/C++ supplies the mature optimized baseline. Python may be retained for
  orchestration and legacy comparison but is not the denominator used to claim
  a breakthrough.

## Immediate deliverable

The first executable PR should implement Slice 0 and one CPU-only correctness
path for Slice 1. GPU claims wait for an identified runner. The first published
table must include Bend even if it fails to compile, lacks a required operation,
or loses badly; unsupported and embarrassing outcomes answer the research
question.
