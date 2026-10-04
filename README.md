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
| `finite_exact` | Unbounded integers `BigZ`, rationals `Q`, conservative closed intervals. Fail-closed on invalid input. |
| `finite_linear_algebra` | Exact matrices, RREF/rank/nullspace over `Q`, rank-three tensors. |
| `finite_polynomial` | `BigZ` polynomials, cyclotomic fields `Q[X]/(Phi_n)` with Galois actions, jets of the quadratic germ. |
| `substitution_dynamics` | Words, substitutions, balanced pairs, tuning, S-adic sequences, column coincidence. |
| `quadratic_orbit` | Enclosed orbits of `z -> z^2 + c` and the collision partition. |
| `rational_dynamics` | Reduced fractions, doubling mod 1, continued fractions, Farey determinants. |
| `projective_limits` | Limits of rational functions over `Q` as points of `P^1(Q)`. |
| `finite_field_orbit` | Exact tails and periods of `x -> x^2 + c` over `F_p`. |
| `parallel_fold` | Order-preserving parallel map-fold (the only package needing MAX). |
| `proof_records` | Proof-record model (`ProofArchitecture.tla`) and its graph. |
| `mojo_smoke` | Test scaffolding. |

Stable entry points in `finite_exact` and `finite_linear_algebra` are
`rational`, `closed_interval`, `matrix`, `matrix3` and `rational_elimination`;
older module names (`rat_q`, `mat3`, `qlinalg`, …) remain for compatibility.

## Rest of the repository

| Path | Role |
|---|---|
| `reference/` | Independent Python reference semantics (non-authoritative). |
| `oracles/` | Differential oracles. |
| `schemas/`, `conformance/` | Normative contracts and their golden vectors. |
| `tools/` | Vendoring drift checker, claim governance, vector generators. |
| `experiments/frontier/` | Polyglot experiments (non-authoritative). |
| `docs/` | Specifications; start with `docs/exact-arithmetic-public-boundary.md`. |
| `policy/provenance.json` | Origin of every tracked file. |

See `ARCHITECTURE.md` for layout rules and `CONTRIBUTING.md` for workflow.

## Verification

```bash
pixi run test
```
