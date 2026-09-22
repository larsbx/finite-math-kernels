# Polyglot orbit census: Elixir, Bend, Mojo, and choreographies

Status: design and executable protocol lane beside Slice 1 of
`docs/frontier-math-compute-candidates.md` (whose Lane A contract is
`benchmarks/frontier/ff_orbit_census/CONTRACT.md`)  
Authority: performance and conformance evidence only; the Mojo replay
predicate is the only acceptance authority, and it accepts finite facts about
finite fields, never theorems

## 1. Decision

Each language does the one job its execution model is best at. They
communicate only through immutable, canonical records:

| Layer | Language | Role (polyglot vocabulary) | Why this language |
|---|---|---|---|
| Protocol | TLA+ choreography | specification | One global view of the exchange; per-role behaviour is its projection |
| Orchestration | Elixir/OTP | runtime | Supervision, isolation of foreign processes, bounded restart, distribution |
| Irregular search | Bend (HVM2) | challenger (non-authoritative) | Divide-and-conquer parallelism without explicit threads |
| Exact kernel | Mojo | kernel (authoritative) | Exact fixed-width arithmetic, ownership, SIMD/GPU headroom |
| Semantics | Python | reference (vector generation) | Smallest possible statement of the contract |

Wyzer is not a dependency. It is an experimental research language, and this
design takes two of its ideas, not its toolchain:

1. **Choreographic programming.** The protocol is written once, as a global
   exchange between roles (`benchmarks/frontier/FrontierCensus.tla`). Each
   role's local behaviour is its projection. The orchestrator's projection is
   a pure transition function (`Frontier.Protocol.step/2`) whose clauses match
   the specification's actions one to one. The specification is model-checked
   for deadlock freedom and for the safety invariants of section 6, and the
   Elixir transition function is property-tested against the same
   invariants. A choreography library such as Chorex could later replace the
   hand projection, but only after it passes the same property suite.
2. **Perceus / functional-but-in-place.** When a value has exactly one owner,
   updating it in place is indistinguishable from building a new value. Mojo
   gets this from ownership (`owned`/`var` values, deterministic
   destruction), Bend from affinity (every variable is used once), and the
   BEAM from per-process heaps. The kernel code is therefore written as pure
   folds over owned accumulators. Nothing mutable crosses a process boundary;
   only encoded records do.

**Common principle: no shared mutable state.** The BEAM copies messages
between processes, HVM2 is affine, Mojo has ownership, and Perceus relies on
uniqueness. The boundary between them is therefore a canonical byte string,
and each side is free to mutate privately.

## 2. The frontier question and the finite subproblem

Frontier question (owned by `larsbx/giant-fibers-finite-fields-thin-groups`):
the statistics of tail and cycle lengths of `x -> x^2 + c` on prime fields,
and the exceptional parameters where they deviate from random-mapping
predictions.

The finite subproblem computed here (and nothing more): for a block of seeds
in `F_p` at a fixed `c`, the exact tail (`mu`) and period (`lambda`) of each
seed's orbit, when these are observed within a cap, aggregated as a monoid.

## 3. Contract `orbit-census-v1` (normative)

### 3.1 Block

A block is `(p, c, cap, lo, hi)` of non-negative integers. The block is
well-formed iff:

- `p` is prime and `p < 2^32`;
- `c < p`;
- `lo <= hi <= p`;
- `cap < 2^32`.

The seeds of a block are `s` with `lo <= s < hi`.

### 3.2 Seed semantics

`f(x) = (x^2 + c) mod p` on `{0, ..., p-1}`, `x_0 = s`, and
`x_(i+1) = f(x_i)`. Let `j` be the least index with `x_j` in
`{x_0, ..., x_(j-1)}`; such a `j` exists and `j <= p`. Then `mu` is the unique
`i < j` with `x_i = x_j`, and `lambda = j - mu >= 1`.

The seed is **resolved** iff `j <= cap`; otherwise it is **inconclusive**. The
definition refers only to `j`, never to an algorithm, so Brent, Floyd, and
visited-table implementations must all agree. Inconclusive means the cap was
reached. It is never a claim about the orbit.

### 3.3 Aggregate (the canonical record)

| Field | Meaning |
|---|---|
| `n` | `hi - lo` |
| `resolved` | number of resolved seeds |
| `sum_mu`, `sum_lambda` | sums over resolved seeds |
| `periodic` | resolved seeds with `mu = 0` |
| `has_w`, `w_seed`, `w_mu`, `w_lambda` | witness: the resolved seed maximising `mu + lambda`, ties broken by the smallest seed; `has_w = 0` and zeros when no seed is resolved |

The aggregate is a commutative monoid (sums, plus a maximum under a total
order on `(-(mu + lambda), seed)`). **Partition invariance** follows:
any tree partition of `[lo, hi)` yields the same record. The property suites
test this rather than assume it.

### 3.4 Canonical encoding

A record is exactly one ASCII line:

```text
orbit-census-v1 p c cap lo hi n resolved sum_mu sum_lambda periodic has_w w_seed w_mu w_lambda
```

Fields are unsigned decimal numbers with no sign and no leading zeros (`0` is
the only representation of zero), separated by single spaces. `sum_mu` and
`sum_lambda` are below `2^64`; every other field is below `2^32`. The sums need
the wider range: `mu + lambda <= p` for each seed and `n <= p`, so each sum is
at most `p (p - 1) < 2^64`. That bound is reached in practice. The full-field
block `(94379, 0, 94379, 0, 94379)` has `sum_lambda = 4453414691 >= 2^32`,
and under a uniform `2^32` bound every decoder refused that valid record as
`malformed:sum_lambda`. The block is
echoed so that a receiver can reject an answer to a question it did not ask.
The run digest is SHA-256 over the concatenation of the record lines, each
terminated by `\n`, in block order. The encoding is injective and the
decoding is total: any other byte string is `malformed`.

### 3.5 Outcomes

Every request ends in exactly one of:

| Outcome | Meaning | Retried? |
|---|---|---|
| `accepted` | the authority recomputed the block, got the identical record, and replayed the witness | never |
| `rejected:<reason>` | a well-formed answer the authority refuses (`mismatch:<field>`, `witness:<check>`) | **never** |
| `malformed:<field>` | the request or answer is not in the contract's language | never |
| `unsupported:<field>` | well-formed, but outside the implementation's declared domain | never |
| `infra:<reason>` | the process died, timed out, or wrote nothing | bounded, at most `k` times |
| `exhausted` | `k` infrastructure failures in a row | terminal; inconclusive |

A verdict is a value, not an exception. OTP restarts apply only to `infra`.
A supervisor must never turn a rejection into an acceptance by retrying.

### 3.6 Declared domains

| Implementation | Domain | Measured reason |
|---|---|---|
| Mojo kernel | `p < 2^24`; sums below `2^63` | visited table of `p` words per worker; a sum in `[2^63, 2^64)` does not fit an `Int` and decodes as `unsupported:<field>`. No record in the domain is refused, since there `p < 2^24` bounds the sums below `2^48` |
| Bend challenger (Bend 1: `bend-lang` 0.2.38, HVM2) | `p <= 4093`, `cap < 2^24` | HVM2 arithmetic is `u24` and wraps silently (`4097 * 4097` evaluates to `8193`). `(p-1)^2 < 2^24` forces `p <= 4097`, and 4093 is the largest prime at or below that. Sums stay below `p^2 < 2^24`. The CLI refuses arguments of `2^24` or more (exit status 2), so only products wrap; a block with `p = 4099` returns a well-formed, wrong record |
| Python reference | contract domain | unbounded integers |

A request outside a domain is answered `unsupported` *before* dispatch. The
Bend lane in particular can never be allowed to wrap.

The contract is U32, but this Bend lane is not. It records the narrower
domain as a measured fact and does not relax the contract to fit it. Bend 2,
which the Lane A harness uses, has native `U32` with software division, so a
Bend 2 port of `benchmarks/frontier/census.bend` should lift the domain to the
contract's (deferred, section 10).

## 4. The authority: replay predicate

`replay(record)` in `finite_field_orbit/census.mojo` accepts iff **all** of
the following hold:

1. the record decodes and its block is well-formed and supported;
2. recomputing the block's census gives the identical record, field by field
   (the first differing field is the `mismatch:` reason);
3. if `has_w = 1`, the witness independently replays: `lo <= w_seed < hi`,
   `w_mu + w_lambda <= cap`, `x_(w_mu + w_lambda) = x_(w_mu)`, and
   `x_0, ..., x_(w_mu + w_lambda - 1)` are pairwise distinct. This check does
   not use the census code path (it keeps its own trajectory list).

Check 2 dominates the cost, so replay costs as much as the census itself.
That is acceptable for Slice 1, whose question is agreement. Cheaper
certificates, such as per-seed rho witnesses in a Merkle tree with sampled
replay, are a Slice 4 concern and would need their own soundness argument.

## 5. The orchestrator (Elixir)

A functional core with an imperative shell:

- `Frontier.Record`: decoding (total, fail-closed), encoding, the monoid, and
  the digest.
- `Frontier.Contract`: well-formedness (section 3.1) and the declared
  domains (section 3.6), checked before dispatch.
- `Frontier.Protocol`: the orchestrator's projection of the choreography, as a
  pure `step(state, event) -> {state, [effect]}`.
- `Frontier.PortKernel`: kernels as plain maps of functions (`domain`,
  `census`, `replay`), backed by OS processes behind Erlang Ports. A crash is
  a process exit and never takes down the VM. The design uses Ports and
  **not NIFs**: a NIF fault kills the whole BEAM and every other block's
  state with it. Output outside a kernel's exact answer grammar, a non-zero
  exit, or a timeout (which kills the OS process) becomes `infra`, never a
  verdict.
- `Frontier.Census`: runs blocks with `Task.Supervisor.async_stream_nolink`,
  interprets effects, and returns the ledger in block order. A run digest is
  produced only when every block is accepted.

Two rejections come from the orchestrator itself, not the authority:
`rejected:echo` (the proposal answers a different block) and
`rejected:protocol:<event>` (a message the choreography does not allow in the
current phase; rejecting rather than waiting keeps the projection
deadlock-free).

The orchestrator has no dependencies beyond Elixir and Erlang. Its property
tests use a seeded `:rand` generator, so every counterexample can be
reproduced with `FRONTIER_SEED`.

## 6. Choreography and invariants

Global protocol (roles `O` orchestrator, `B` challenger, `M` authority):

```text
O -> B : job(block)
B -> O : proposal(record) | fault           -- fault: O may re-send, at most k times
O -> M : replay(block, record)
M -> O : verdict(accepted | rejected(reason))
O      : ledger(block) := verdict           -- write-once
```

Invariants, checked by TLC on the specification and by property tests on
`Frontier.Protocol.step/2`:

- **NoAcceptWithoutReplay**: `ledger[b] = accepted` implies `M` replayed the
  exact proposal that `B` sent for `b`.
- **WriteOnce**: a ledger entry, once written, never changes.
- **NoRetryAfterVerdict**: `B` never receives `job(b)` again after `M` returns
  a verdict for `b`.
- **BoundedRestarts**: attempts for `b` never exceed `k`.
- **Deadlock freedom and termination**: every state has a successor, or all
  blocks are terminal. Under weak fairness, every block reaches a terminal
  ledger entry. In the projection this is "an undecided block always has
  exactly one outstanding effect".

The model (`benchmarks/frontier/FrontierCensus.cfg`, two blocks, `k = 3`)
has 2,025 distinct states. To show that the invariants can fail, the
specification carries three mutant orchestrators, and each must trip the
invariant that names its fault: acceptance without replay, retry after a
verdict, and unbounded retry.

## 7. Verification plan (this slice)

| Gate | Command | Environment |
|---|---|---|
| reference laws, vector drift | `pixi run test-orbit-reference` | default |
| Mojo kernel against the vectors, replay rejects each tampered vector | `pixi run test-orbit-census` | default |
| Bend census against the vectors, domain refusal | `pixi run test-orbit-bend` | polyglot (needs `FRONTIER_BEND1`, `FRONTIER_HVM1`) |
| orchestrator properties and Mojo/Bend Port integration | `pixi run test-orchestrator` | polyglot |
| choreography model check, mutants caught | `pixi run test-choreography` | polyglot (needs `TLA_TOOLS`) |

Pixi runs a polyglot task in the `polyglot` environment on its own, because
the task exists only there.

The default gates join `pixi run test`, so the existing authoritative CI
gains checks and loses none. The polyglot gates run in a separate workflow
(`.github/workflows/frontier-polyglot.yml`). There they **fail** rather than
skip when a toolchain is missing.

Golden vectors (`fixtures/orbit_census_v1.txt`, generated by
`tools/make_orbit_vectors.py` from `tools/orbit_census_reference.py`) contain
accepted blocks, tampered records paired with the rejection the authority
must give, malformed and unsupported requests, and boundary blocks: empty
ranges, `cap = 0`, `cap = p`, `c = 0`, `p = 2`, and the Bend domain edge
`p = 4093`.

## 8. Measured facts from building the slice

These are observations from one Linux x86-64 container, not benchmarks:

- **Bend runs race in a shared directory.** `bend run-c` writes its compiled
  program to a fixed `.out.hvm` in the current directory. The first
  concurrent end-to-end run had one Bend process print another block's
  record. The echo check rejected it (`rejected:echo`) and it was never
  accepted. The Bend adapter now gives each run its own scratch directory.
- **Aggregate sums outgrow 32 bits.** The first contract put every field
  below `2^32`, and the golden vectors never left that range. A full-field
  block with `p = 94379` produced `sum_lambda = 4453414691`, which the census
  emitted and every decoder then refused (section 3.4). The vectors now carry
  that record (kind `wide`) and forged sums at `2^32` and `2^63 - 1`. The
  polyglot gate replays the record end to end: any honest record with a sum of
  `2^32` or more costs at least `2^32` steps, about a minute each for census
  and replay here, so it is not a default gate.
- **Two Bends, one name.** The Lane A harness calls `bend` expecting Bend 2.
  With this lane's Bend 1 installed as `bend`, the harness's Bend build
  failed. This lane therefore installs Bend 1 under its own root and calls it
  by explicit path (`FRONTIER_BEND1`, with `--hvm-bin FRONTIER_HVM1`).
- **`bend` exits 0 on compile errors.** The adapter therefore decides by the
  exact shape of stdout (`<record>`, then `Result: ...`), never by exit
  status alone.
- **Bend wraps silently outside its domain** (section 3.6); a test pins this
  with `p = 4099`.
- **Single-run wall time for `(4093, 1, 4093, 0, 4093)`:** Mojo about 12 ms,
  Bend (`run-c`, CPU) about 11 s. This is not a benchmark result (no warm-up,
  no distribution, compile included), but it sets expectations for Lane A.

## 9. Removability

Deleting Bend, Elixir, or the TLA+ specification leaves the canonical state
unchanged: the Mojo kernel, the reference, and the vectors stand alone.
Deleting the reference only removes vector generation; the committed vectors
still gate the kernel.

## 10. Deferred

- A Bend 2 port of the challenger, which removes the u24 domain and the
  second Bend toolchain; the harness already installs Bend 2 in CI.
- Running this contract through `benchmarks/frontier/harness.py` for timing,
  once it has a Bend 2 challenger.
- GPU lanes (`bend run-cu`, Mojo GPU): wait for an identified runner.
- The Julia oracle lane and the Rust baseline for Slice 1's throughput table.
- Timing capture (`benchmarks/frontier/candidates.toml` result requirements):
  this slice proves agreement first.
- Distribution across BEAM nodes: the core is already location-transparent,
  but a single node is enough to test the protocol.
- A mechanised choreography (Chorex or a Wyzer-style projection compiler) in
  place of the hand projection.
