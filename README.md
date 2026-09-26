# finite-math-kernels

Canonical monorepo for reusable exact finite-mathematics kernels extracted
from the finite-regime Mandelbrot program (`larsbx/finite-mandlebrot-research`,
formerly `larsbx/NLAP-JT`) and the Pisot substitution research program.

```text
finite_exact/
  bigint_z.mojo
  rational.mojo
  closed_interval.mojo
finite_linear_algebra/
  matrix.mojo
  matrix3.mojo
  rational_elimination.mojo
  tensor3.mojo
substitution_dynamics/
  words.mojo
  substitution.mojo
  balanced_pairs.mojo
  automaton.mojo
  discrepancy.mojo
  tuning.mojo
  sadic.mojo
  coincidence.mojo
quadratic_orbit/
  orbit.mojo
  collision.mojo
rational_dynamics/
  rational.mojo
finite_field_orbit/
  census.mojo
mojo_smoke/
  report.mojo
parallel_fold/
  map_fold.mojo
proof_records/
  ProofArchitecture.tla
  graph.py
vendoring/
  check_vendored_sync.py
audit/
  claim_governance/
  estate_repository/v1/
```

The implementation retains compatibility modules (`rat_q`, `closed_q`,
`mat3`, `qlinalg`, `scalar`, and `w3`) while consumers move to the stable public
filenames above. There is one in-tree `finite_exact`; vendored duplicates are
not part of this repository.

## Boundaries

- `BigZ` and `Q` are exact and unbounded; malformed construction and invalid
  arithmetic on constructor-produced values are rejected fail-closed. Direct
  assignment to `BigZ` fields is outside the boundary
  (`docs/exact-arithmetic-public-boundary.md`, section 2).
- Closed intervals are conservative filters. Unknown containment or sign is
  never promoted to equality or certificate acceptance.
- Linear algebra computes exact finite-dimensional facts and makes no spectral
  or conjectural theorem claims.
- A capped balanced-pair automaton is inconclusive, never a proof or
  counterexample.
- Tuning patterns, directive prefixes, and column coincidence are finite
  combinatorics (`docs/tuning-substitutions-spec.md`). A coincidence witness
  is a fact about columns of powers of a substitution; the spectral
  conclusion (Dekking) and the kneading interpretation of tuning are the
  consumer's imported theorems. The parity twist is the real-line
  convention; the continuation twist is the general rule.
- The quadratic orbit is seeded. Both planes of the family iterate
  `z -> z^2 + c`; the parameter plane varies `c` from the critical seed and
  the dynamical plane varies the seed at fixed `c`, so the seed is an argument
  and neither plane is the library's default. Terms are enclosures: separation
  of two terms is a fact about the boxes, and overlap is never equality.
- The collision partition (`quadratic_orbit/collision.mojo`) is finite
  combinatorics on indices. It says which pairs an `(ell, period)` type
  intends to collide, knows nothing about any parameter, and proves nothing
  about any orbit; an invalid type intends nothing rather than something
  arbitrary.
- `rational_dynamics` provides exact unbounded reduced-fraction arithmetic, explicit doubling modulo one, modular and centered modular inverses, canonical simple continued fractions and convergents, and Farey determinants. It interprets none of these as measured angles or domain claims.
- The finite-field orbit census (`finite_field_orbit/census.mojo`,
  `docs/polyglot-orbit-census-design.md`) computes exact tails and periods of
  `x -> x^2 + c` over `F_p` for a block of seeds, up to a cap. Cap reached is
  inconclusive, never a fact about the orbit. Its replay predicate is the only
  authority for records proposed by the Bend challenger, and the Elixir
  orchestrator only schedules; neither decides anything.
- The vendoring checker (`vendoring/`) reports drift between a consumer's
  copies and its pins. It decides nothing about the code it checks, and it
  searches upward for the manifest so that how deep a consumer puts it does
  not matter.
- `mojo_smoke` is test scaffolding: it reports the verdicts it is handed and
  certifies nothing.
- `parallel_fold` evaluates a map-fold over an index range on worker threads
  and folds the chunks in index order, so an associative `combine` returns the
  sequential fold at every worker count; it relies on associativity alone,
  never commutativity. It is the one package that needs MAX
  (`max.algorithm.parallelize`, from `max-core`) and it certifies nothing.
- Proof-record acceptance policy belongs to the consumer.
- The evidence-vocabulary map (`docs/evidence-vocabulary-map.md`) only preserves
  or lowers authority: a non-transferable exercise never becomes a theorem, an
  unexecuted step never becomes a failure, and a failing test never becomes a
  malformed record.
- Generated ledgers (`docs/ledger-generation-spec.md`) are functions of a
  consumer's named proof records: the TLA+ ledger and TLC models over
  `proof_records/ProofArchitecture.tla`, the `[[claim]]` entries, and the
  Markdown index all say what the records say, and the generator refuses a
  ledger it cannot render faithfully. It promotes nothing.
- The typed relationship graph (`docs/typed-relationship-graph-spec.md`) is
  the same records read as a graph: it types the relationships the ledger
  already records and infers none, and every edge is declared rather than
  scored, so importing it into an LLM-asserted graph cannot launder a guess
  into a verified relationship.
- Generator refinements (`oracle_refinement`, `docs/generator-refinement-spec.md`) declare what each
  differential oracle draws from, because a comparison is only as strong as its
  corpus: this repository lost a 64-bit wrap and a singular lattice to a corpus
  that was silent rather than wrong. A class declared reached and never drawn
  fails the run, and so does a class declared missed and then drawn.
- The shared Estate Repository Template v1 audit (`audit/estate_repository/v1/`) validates repository authority/layout declarations only. Consumers pin it as CI/tooling; it never acquires their mathematical, proof, certificate, effect, or persisted-state authority.
- Claim-governance checks enforce only a consumer-supplied policy; the
  monorepo does not encode NLAP or PSC theorem status as library truth. The
  `coverage` check reports which claims no test guards; it never decides that
  a test establishes one.
  `docs/provenance-for-computer-assisted-proof.md` states the record and
  enforcement layers for readers outside these programmes: the three outcomes,
  the five record kinds, the six checks, and what adopting them costs. It is
  methodology, not mathematics, and proves nothing.

## Verification

```bash
pixi run test
```

See `audit/CONSOLIDATION_PROVENANCE.md` for source mapping and retirement gates.
