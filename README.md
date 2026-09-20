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
  preperiodic.mojo
angle_doubling/
  angle.mojo
projective/
  homogeneous.mojo
  chart.mojo
mojo_smoke/
  report.mojo
proof_records/
  ProofArchitecture.tla
  graph.py
references/
  check_references.py
vendoring/
  check_vendored_sync.py
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
- The quadratic orbit is seeded. Both planes of the family iterate
  `z -> z^2 + c`; the parameter plane varies `c` from the critical seed and
  the dynamical plane varies the seed at fixed `c`, so the seed is an argument
  and neither plane is the library's default. Terms are enclosures: separation
  of two terms is a fact about the boxes, and overlap is never equality.
- The projective package (`projective/`) is the quadratic map on the
  projective line over the complex numbers, where it is a morphism of degree
  two with no base point and infinity is a fixed class of the algebra rather
  than a limit. That is not the completion in which the plane gains an ideal
  line carrying the circular points; the quadrance form degenerates there and
  this map is not a morphism of it, so a consumer that conflates the two is
  wrong whatever it proves. A homogeneous pair is not an ideal point: it is
  two coordinate records modulo scaling, and reading one as a value needs a
  chart. Each chart is a division, so it has a domain, and a box whose
  quadrance could vanish leaves the chart rather than being evaluated.
- Angle doubling (`angle_doubling/`) is finite combinatorics on `Q/Z`, not
  geometry. No angle here is derived from a locus and no locus from an angle,
  and the package does not know what a ray is. Its two facts are closed forms
  rather than searches: a rational angle's preperiod under `t -> 2t` is the
  exponent of two in its denominator, and its period is the multiplicative
  order of two modulo the odd part. What a consumer does with the
  correspondence between an angle's type and a dynamical point's type is the
  consumer's import to name and gate.
- The preperiodic certificates (`quadratic_orbit/preperiodic.mojo`) are about
  boxes. `R^c_{l,k}(z) = f^{l+k}(z) - f^l(z)` is evaluated along the orbit and
  its derivative by the chain rule, so no polynomial is ever formed and no
  squarefree decomposition is needed; what a squarefree part would buy is a
  simple root, and a derivative enclosure that misses zero is that, checked.
  Exclusion (`0` not in the residual's enclosure) is a proof about every point
  of the box. Isolation returns the *hypothesis* of the Krawczyk-Moore
  theorem, strict inclusion of the operator's image, and never its conclusion:
  the theorem is the consumer's import to name and gate.
- The collision partition (`quadratic_orbit/collision.mojo`) is finite
  combinatorics on indices. It says which pairs an `(ell, period)` type
  intends to collide, knows nothing about any parameter, and proves nothing
  about any orbit; an invalid type intends nothing rather than something
  arbitrary.
- The reference checker (`references/`) reports paths and pixi tasks a tree
  mentions that resolve to nothing. What counts as resolving is the
  consumer's `Policy`: which files to read, which paths to skip, and which
  references live in another repository and are attested by a sentence rather
  than resolved. The package supplies the one file listing this repository
  uses, so the provenance manifest and the reference check cannot describe
  different trees.
- The vendoring checker (`vendoring/`) reports drift between a consumer's
  copies and its pins. It decides nothing about the code it checks, and it
  searches upward for the manifest so that how deep a consumer puts it does
  not matter.
- `mojo_smoke` is test scaffolding: it reports the verdicts it is handed and
  certifies nothing.
- The claim-governance package (`audit/claim_governance`) reads a consumer's
  `claim_governance.toml` and reports findings against it. This repository is
  one of those consumers: `claim_governance.toml` at the root restates the
  boundaries above as rules, and `pixi run governance` checks them. A rule
  that matched nothing would be a gate in name only, so
  `tests/governance/test_self_policy.py` also checks that each shipped rule
  still fires on a tree that breaks it.
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
