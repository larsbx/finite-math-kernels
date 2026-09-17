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
proof_records/
  ProofArchitecture.tla
audit/
  claim_governance/
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
- Claim-governance checks enforce only a consumer-supplied policy; the
  monorepo does not encode NLAP or PSC theorem status as library truth.
  `docs/provenance-for-computer-assisted-proof.md` states the record and
  enforcement layers for readers outside these programmes: the three outcomes,
  the five record kinds, the five checks, and what adopting them costs. It is
  methodology, not mathematics, and proves nothing.

## Verification

```bash
pixi run test
```

See `audit/CONSOLIDATION_PROVENANCE.md` for source mapping and retirement gates.
