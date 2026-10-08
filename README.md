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
A named object of the literature (a theorem, algorithm or classical function)
has a module named after it whose docstring cites its source; the generic
module it was first written in re-exports it, so older import paths keep
working (`tests/facades/test_named_modules.mojo` pins both).

| Package | What it provides |
|---|---|
| `finite_exact` | Unbounded integers `BigZ`, rationals `Q`, conservative closed intervals and boxes (common-denominator and Gaussian-rational constructors, exact singleton predicates), enclosure-width bounds and box magnitudes; machine-`Int` gcd, overflow-refusing arithmetic, base-ten rendering. Signed-minimum inputs are supported when the result fits; unrepresentable GCDs and arithmetic raise. `ExactField`, a field as a structure over its `Element` type (`QField`), and the prime fields `Fp[p]` / `FpField[p]`. |
| `finite_linear_algebra` | Exact matrices, RREF/rank/nullspace over `Q`, rank-three tensors, checked integer vectors and matrix multiplication; exact Boolean support powers decide primitivity of non-negative integer matrices without weight overflow; `qpoly`: polynomials over `Q` (`docs/exact-polynomial-root-isolation-spec.md`). Named modules: `cauchy_bound`, `sturm_sequence` (Sturm chains, isolating brackets), `faddeev_leverrier` (the characteristic polynomial in any dimension), `wielandt_bound`, `hermite_normal_form`, `smith_normal_form`. |
| `finite_polynomial` | `BigZ` polynomials, cyclotomic fields `Q[X]/(Phi_n)` with Galois actions, jets of the quadratic germ. `cyclotomic_field` types it for the field-generic kernels: `Cyc[q]` with a compile-time conductor and operators `+ − * / ==`, trace and norm, `CyclotomicField[q]` as an `ExactField`, and `CyclotomicRing` for a run-time conductor. `coefficient_ring`: `CoefficientRing`/`CoefficientField`, rings as values, with `FieldRing[K]` over any `ExactField` and `ComplexBoxRing` over `closed_q` boxes. `truncated_jet`: `TruncatedJet[R]` over any of them (products, reciprocal, vanishing order). `taylor_model`: the Taylor model (Berz–Makino 1998) over complex boxes, re-exported from the facade. `polynomial_fp` is the run-time-prime counterpart: polynomials over `Z/m` and `F_p` (`p < 2^31`, products exact by the canonical-residue bound), gcd and Bezout, modular powers, the Frobenius map; the named algorithms over it have their own modules, re-exported from the package: `miller_rabin` (deterministic below `2^31`), `distinct_degree` (Cantor-Zassenhaus), `rabin_irreducibility` (Rabin's test with a replayable certificate), `hensel_lifting` (one Hensel step to `p^2`). Named modules: `cyclotomic_polynomial`, `euler_totient`, `moebius_function`. |
| `substitution_dynamics` | Words, substitutions, balanced pairs, tuning, internal addresses of kneading sequences (`internal_address`, Lau-Schleicher), S-adic sequences, column coincidence, relabelling/reversal normal forms, endpoint self-map classes, over an explicit alphabet; named modules for the balanced pair algorithm (`balanced_pair_algorithm`, Livshits; Sirvent-Solomyak), Barge's class (`barge_class`), the Dumont-Thomas numeration (`dumont_thomas`), strong coincidence (`strong_coincidence`, Arnoux-Ito; generic over a caller-supplied difference bound) and return lattices (`return_lattice`, Durand). Its automaton reads components through `finite_graph`, so the two are vendored together; `dumont_thomas` and `strong_coincidence` also need `finite_automata`, `return_lattice` needs `finite_exact`. |
| `quadratic_orbit` | Enclosed orbits of `z -> z^2 + c`, the collision partition, box certificates for preperiodic points (exclusion; the Krawczyk hypothesis, in `krawczyk_operator`, through `root_isolation`, which it is vendored with), the escape test `N(z) > max(4, N(c))` with its rational growth certificate, and the exact multiplier trichotomy. |
| `root_isolation` | Root isolation on complex rational boxes in one variable: `krawczyk` (the Krawczyk operator, Krawczyk 1969), `krawczyk_moore` (the strict-interior Krawczyk-Moore test, Moore 1977), `boxes` (exact centre and point inverse, exclusion, disjointness) (`docs/root-isolation-spec.md`). |
| `angle_doubling` | `t -> 2t` on `Q/Z`: preperiod and period in closed form, angle types. |
| `projective` | The quadratic map on `P^1(C)` in homogeneous coordinates, and its charts. |
| `rational_dynamics` | Reduced fractions, doubling mod 1; the uncapped doubling-map types on `Q/Z` (`doubling`: preperiod, period, binary blocks, exact-type counts). Named modules: `continued_fractions`, `farey` (Farey determinants), `multiplicative_order` (the order of two), `carmichael` (the Carmichael function), `moebius` (the Moebius function; `finite_polynomial.moebius_function` re-exports it). |
| `projective_limits` | Limits of rational functions over any `ExactField` K (Q, F_p, Q(zeta_q)) as points of `P^1(K)`; `rotor`: rotations of `x^2 + y^2 = 1` as non-isotropic points of `P^1(K)`, turns, orders and spreads, with no angle (`docs/projective-limits-over-exact-fields.md`). Named modules: `mobius_transformation`, `spread_polynomial`. |
| `certified_records` | Canonical one-line records: a schema of 32/64-bit fields, a total decoder, `malformed:`/`mismatch:` refusals (Mojo; a Python binding to the same codec). |
| `finite_field_orbit` | Exact tails and periods of `x -> x^2 + c` over `F_p`. |
| `parallel_fold` | Order-preserving parallel map-fold (the only package needing MAX). |
| `proof_records` | Proof-record model (`ProofArchitecture.tla`) and its graph. |
| `finite_automata` | Total DFAs over an integer alphabet: Boolean operations, projection (`subset_construction`), minimisation (`moore_minimisation`), emptiness witnesses, exact counts. |
| `finite_graph` | Strongly connected components (Tarjan), union-find, F2 signings (period, cyclic classes, Perron compatibility). |
| `mojo_smoke` | Test scaffolding, and the `require_claim` / `require_contract` receipts the claim-governance coverage check reads. |

## Python packages

Pure-standard-library Python packages that consumers vendor byte-for-byte,
like the Mojo ones. They are non-authoritative: where one overlaps a Mojo
package, the Mojo package is canonical. Those under `oracles/` are exact and
fail closed; they exist for consumers with no Mojo toolchain (decision D1,
`docs/vendoring-candidates-2026-10-05.md`).

| Package | What it provides |
|---|---|
| `oracles/rational_dynamics_py` | Reduced fractions and units (`addresses`), continued fractions (`continued_fractions`), mediants, Farey sequences and parents (`farey`); the doubling map on `Q/Z` (`doubling`: preperiod, exact period, exact-type counts, binary expansions, doubling orbits), the order of two (`multiplicative_order`), the Carmichael function (`carmichael`), mechanical words (`mechanical_words`), rotation cycles and numbers (`rotation_sets`), wakes (`wakes`); Moebius, Dedekind and Ramanujan sums (`moebius_function`, `dedekind_sums`, `ramanujan_sums`; `arithmetic` re-exports them). Also the R1 reference that `reference/rational_dynamics_reference.py` re-exports. |
| `oracles/closed_interval` | The Python twin of `finite_exact/closed_q.mojo`: `IQ`, `ComplexIQ` (alias `ComplexBox`) over `Fraction`, and directed dyadic rounding. |
| `oracles/root_isolation_py` | The same modules (`krawczyk`, `krawczyk_moore`, `boxes`) in one or two complex variables over `closed_interval`: exact or rounded midpoint preconditioners, caller-supplied outward rounding, and the isolation, exclusion and disjointness tests (`docs/root-isolation-spec.md`). Vendored with `closed_interval`. |
| `oracles/oracle_refinement` | Declared generator codomains (`docs/generator-refinement-spec.md`). |
| `tools/vendoring` | The `vendored.toml` checker and pinner. |
| `tools/references` | Path and task reference checking under a consumer policy. |
| `tools/claim_governance` | Claim-status, terminology and coverage checks under a consumer policy. |
| `tools/exact_arithmetic_audit` | The section 7 exact-arithmetic consumer audit under a consumer policy; vendored with `vendoring` and `claim_governance`. |
| `tools/lexical_audit` | Terminology, banned-token and prose audits (clause, context and declaration rules) under a consumer policy; vendored with `vendoring` and `claim_governance`. |
| `tools/polyglot_envelope` | The polyglot boundary envelope schema and conformance vectors as one template; `render.py` writes, or with `--check` verifies, a consumer's `.polyglot/` from its `polyglot.manifest.toml`. This repository's `schemas/` and `conformance/` copies are its own rendering. |

Stable entry points in `finite_exact` and `finite_linear_algebra` are
`rational`, `closed_interval`, `matrix`, `matrix3` and `rational_elimination`;
older module names (`rat_q`, `mat3`, `qlinalg`, …) remain for compatibility.

## Rest of the repository

| Path | Role |
|---|---|
| `reference/` | Independent Python reference semantics (non-authoritative). |
| `oracles/` | Differential oracles, and the vendorable Python packages above. |
| `schemas/`, `conformance/` | Normative contracts and their golden vectors. |
| `tools/` | Vendorable `vendoring`, `references`, `claim_governance`, `exact_arithmetic_audit`, `lexical_audit` and `polyglot_envelope` packages; provenance; vector generators. |
| `experiments/frontier/` | Polyglot experiments (non-authoritative). |
| `experiments/mojo_issues/` | Reproductions and logged evidence for Mojo toolchain issues (non-authoritative; `pixi run mojo-issue-evidence`). |
| `docs/` | Specifications; start with `docs/exact-arithmetic-public-boundary.md`. |
| `policy/provenance.json` | Origin of every tracked file. |

See `ARCHITECTURE.md` for layout rules and `CONTRIBUTING.md` for workflow.

## Verification

```bash
pixi run test
```
