# finite-math-kernels

Canonical monorepo for reusable exact finite-mathematics kernels extracted
from NLAP-JT and the Pisot substitution research program.

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
proof_records/
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
- Proof-record acceptance policy belongs to the consumer.
- Claim-governance checks enforce only a consumer-supplied policy; the
  monorepo does not encode NLAP or PSC theorem status as library truth.

## Verification

```bash
pixi run test
```

See `audit/CONSOLIDATION_PROVENANCE.md` for source mapping and retirement gates.
