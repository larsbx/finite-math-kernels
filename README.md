# finite-math-kernels

Exact finite-mathematics kernels, in Mojo, shared by the finite-regime
Mandelbrot programme (`larsbx/finite-mandlebrot-research`) and the Pisot
substitution programme.

The library computes finite facts. It never turns a computation into a theorem:
an unknown stays unknown, and a capped search that hits its cap is
*inconclusive*, never a proof or a counterexample. Interpreting results is the
consumer's job.

## Packages

All canonical kernels live under `kernel/` (the include root, `-I kernel`).

| Package | What it provides |
|---|---|
| `finite_exact` | Unbounded integers `BigZ`, rationals `Q`, conservative closed intervals, enclosure-width bounds; machine-`Int` gcd, overflow-refusing arithmetic, base-ten rendering. Signed-minimum inputs are supported when the result fits; unrepresentable GCDs and arithmetic raise. `ExactField`, a field as a structure over its `Element` type (`QField`), and the prime fields `Fp[p]` / `FpField[p]`. |
| `finite_linear_algebra` | Exact matrices, RREF/rank/nullspace over `Q`, rank-three tensors, checked integer vectors and matrix multiplication; exact Boolean support powers decide primitivity of non-negative integer matrices without weight overflow; `qpoly`: polynomials over `Q`, Sturm chains, isolating brackets, the characteristic polynomial in any dimension (`docs/exact-polynomial-root-isolation-spec.md`). |
| `finite_polynomial` | `BigZ` polynomials, cyclotomic fields `Q[X]/(Phi_n)` with Galois actions, jets of the quadratic germ. `cyclotomic_field` types it for the field-generic kernels: `Cyc[q]` with a compile-time conductor and operators `+ − * / ==`, trace and norm, and `CyclotomicField[q]` as an `ExactField`. |
| `substitution_dynamics` | Words, substitutions, balanced pairs, tuning, S-adic sequences, column coincidence. Its automaton reads components through `finite_graph`, so the two are vendored together. |
| `quadratic_orbit` | Enclosed orbits of `z -> z^2 + c`, the collision partition, and box certificates for preperiodic points (exclusion; Krawczyk hypothesis). |
| `angle_doubling` | `t -> 2t` on `Q/Z`: preperiod and period in closed form, angle types. |
| `projective` | The quadratic map on `P^1(C)` in homogeneous coordinates, and its charts. |
| `rational_dynamics` | Reduced fractions, doubling mod 1, continued fractions, Farey determinants. |
| `projective_limits` | Limits of rational functions over any `ExactField` K (Q, F_p, Q(zeta_q)) as points of `P^1(K)`; `rotor`: rotations of `x^2 + y^2 = 1` as non-isotropic points of `P^1(K)`, turns, orders and spreads, with no angle (`docs/projective-limits-over-exact-fields.md`). |
| `certified_records` | Canonical one-line records: a schema of 32/64-bit fields, a total decoder, `malformed:`/`mismatch:` refusals (Mojo; a Python binding to the same codec). |
| `finite_field_orbit` | Exact tails and periods of `x -> x^2 + c` over `F_p`. |
| `parallel_fold` | Order-preserving parallel map-fold (the only package needing MAX). |
| `proof_records` | Proof-record model (`ProofArchitecture.tla`) and its graph. |
| `finite_automata` | Total DFAs over an integer alphabet: Boolean operations, projection, minimisation, emptiness witnesses, exact counts. |
| `finite_graph` | Strongly connected components, union-find, F2 signings (period, cyclic classes, Perron compatibility). |
| `mojo_smoke` | Test scaffolding, and the `require_claim` / `require_contract` receipts the claim-governance coverage check reads. |

Stable entry points in `finite_exact` and `finite_linear_algebra` are
`rational`, `closed_interval`, `matrix`, `matrix3` and `rational_elimination`;
older module names (`rat_q`, `mat3`, `qlinalg`, …) remain for compatibility.

## Rest of the repository

| Path | Role |
|---|---|
| `reference/` | Independent Python reference semantics (non-authoritative). |
| `oracles/` | Differential oracles. |
| `schemas/`, `conformance/` | Normative contracts and their golden vectors. |
| `tools/` | Vendorable `vendoring`, `references` and `claim_governance` packages; provenance; vector generators. |
| `experiments/frontier/` | Polyglot experiments (non-authoritative). |
| `experiments/mojo_issues/` | Reproductions and logged evidence for Mojo toolchain issues (non-authoritative; `pixi run mojo-issue-evidence`). |
| `docs/` | Specifications; start with `docs/exact-arithmetic-public-boundary.md`. |
| `policy/provenance.json` | Origin of every tracked file. |

See `ARCHITECTURE.md` for layout rules and `CONTRIBUTING.md` for workflow.

## Verification

```bash
pixi run test
```
