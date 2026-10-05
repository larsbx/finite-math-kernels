# Vendoring candidates across the estate, 2026-10-05

A sweep of every tracked file in the five consumers — `larsbx/finite-julia-set-research`,
`larsbx/finite-mandelbrot-research`, `larsbx/mandelbrot-bulbs-and-ford-circles-research`,
`larsbx/math-vizops` and `larsbx/pisot-substitution-conjecture-research`, including
`archive/`, probes, experiment scripts, hidden directories and stale build output — for
code that is exact, domain-neutral and therefore belongs here. The rule applied is the
estate's: code moves upstream when a second consumer needs it, or when a consumer
already carries a copy of something upstream.

## Moved in this change

| Upstream now | From | Consumer action |
|---|---|---|
| `angle_doubling`, `projective`, `quadratic_orbit/preperiodic.mojo`, `finite_exact/enclosure_width.mojo`, `finite_linear_algebra/qpoly.mojo`, sharp `ComplexIQ.square`, `tools/references` | unmerged branch `claude/julia-set-research-h65zm2`, which Julia already vendored from | Julia re-pins to a commit on `main` |
| `finite_exact/checked_int.mojo`, `finite_linear_algebra/{integer_matrix,integer_vector}.mojo`, `finite_automata`, `finite_graph/signing.mojo` | Pisot `kernel/psc/` | Pisot vendors them and deletes its copies |
| `finite_graph/{scc,union_find}.mojo` | FMK `substitution_dynamics/automaton.mojo` Tarjan, copied verbatim in Pisot `overlap_obstruction.mojo`; union-find twice in Pisot | Pisot calls them |
| `mojo_smoke/claims.mojo` | Pisot `kernel/psc/claim_tests.mojo` | Pisot vendors it |
| `finite_exact/{integer_gcd,exact_decimal}.mojo` | Mandelbrot `kernel/mojo/arithmetic/` | Mandelbrot vendors them |
| estate `[[dep]]` pin derivation in `tools/vendoring` | Pisot's fork of the checker | Pisot and Mandelbrot vendor the checker instead of forking it |
| — (already upstream) | Mandelbrot `smoke/smoke_report.mojo` (header-only diff of `mojo_smoke/report.mojo`) | Mandelbrot vendors `mojo_smoke` |

## Found and deferred

Each row is generic in substance but is not a byte-for-byte move today. The reason is the
blocker; removing it is the next step.

| Candidate | Where | Target | Blocker |
|---|---|---|---|
| Krawczyk / interval Newton (1-D and 2-D), certified roots of unity, dyadic outward rounding, separated-exponent boxes | Julia `reference/{preperiodic,dyadic,scaled}.py`; bulbs `kernel/bulbford/{certify,antipode}.py`; Mandelbrot `certificates/krawczyk_witness.mojo` | new `root_isolation`; `finite_exact` | three implementations in two languages with different box types; needs one specification first, as `qpoly` had |
| Truncated jets and Taylor models over a coefficient ring | Julia `kernel/{jet,taylor}.mojo`, `reference/{jet,taylor}.py`; bulbs `implosion.py` series helpers | `finite_polynomial` | `quadratic_germ` jets are over `CyclotomicQ`, Julia's over `ComplexIQ`; Mojo has no shared ring trait here yet |
| Q-polynomials, Sturm, Tarski query, Routh/Pisot screen, cubic number fields | Pisot `psc/{pisot,real_root_sign,pisot_screen,field3,perron_*}.mojo`; Mandelbrot `structure_names_reference.py` `sturm_count` | `finite_linear_algebra/qpoly`, `finite_polynomial` | three local Q-polynomial layers to converge on `qpoly`'s API; the Pisot ones are cubic-specific and have about 25 importers |
| F_p polynomials, distinct-degree factorisation, irreducibility certificates, Hensel steps, modular inverse, primality | Mandelbrot `dynamics/{exact_type_irreducibility,r41_algebraic_root_certificate,critical_relation_bridge}.mojo` | new `finite_polynomial/polynomial_fp` | machine-`Int` coefficients with unchecked products; must move onto `BigZ` or `checked_int` first |
| Doubling-map number theory: Möbius, catalogue counts, binary blocks, Farey parents and sequences, rotation cycles, mechanical words, wakes, Dedekind and Ramanujan sums, Brjuno sums | Mandelbrot `misiurewicz_catalogue.mojo`, `angle_tuning.mojo`; bulbs `cf.py`, `wake.py`, `cycles.py`, `spectral.py`; vizops `atlas/trace.py` `period_of` | `rational_dynamics`, `angle_doubling` | bulbs and vizops are Python-only and this repository vendors no Python `rational_dynamics`; needs a vendorable Python plane or vectors |
| Kneading, internal address, continuation letter | Mandelbrot `c1/residual/residual_directive_carrier.mojo` | `substitution_dynamics/tuning` | Mandelbrot pins `tuning.mojo` before `continuation_twist`; re-pin, then retire the brute-force letter |
| Ray-address doubling (three Int64/BigQ variants), collision partition (five copies) | Mandelbrot `dynamics/*ray_address.mojo`, `interval_orbit.mojo`, `certificates/*` | `rational_dynamics`, `quadratic_orbit` | importers are C1 research modules; about 45 of the files use the retired `fn`/`inout` syntax and are not compiled |
| Checked Int64 Q / IQ / ComplexIQ stack | Mandelbrot `arithmetic/checked_*.mojo` | `finite_exact` fast path, or retire | a policy decision: BigQ replays of the same certificates exist |
| Gaussian rationals, rational trigonometry | Julia `reference/gaussian_q.py`; Mandelbrot `arithmetic/{complex_inverse,coord_record_eval,rank2_operator,rational_trig}.mojo` | `finite_exact` or `cyclotomic_q` (conductor 4) | the Mandelbrot types are uncompiled legacy syntax |
| Escape certificates, multiplier trichotomy, box constructors | Julia `kernel/{escape_certificate,julia_orbit,enclosure_bound}.mojo` | `quadratic_orbit`, `finite_exact/closed_q` | three local copies of the escape bound to reconcile first |
| Substitution symmetry, endpoint maps, Barge class, bounded BPA, Dumont-Thomas numeration, return lattices, strong-coincidence automata | Pisot `psc/{symmetry,endpoint_core,barge_class,bounded_bpa,dumont_thomas,return_lattice,coincidence_*}.mojo` | `substitution_dynamics` | `ALPHABET = 3` hardwired, or imports reach `perron_field3` |
| PRNG, bounded histogram, hash mixing | Pisot `psc/{prng,histogram}.mojo`, three `_mix_hash` copies | a census-support package | no second consumer yet |
| Python references for `substitution_dynamics` and `closed_q` | Pisot `reference/psc_research/{bpa,swap_discrepancy}.py`; Julia `reference/interval_box.py`; Mandelbrot `interval_exclusion_reference.py` | `reference/` | they are deliberately independent oracles in their consumers; copying one here is a decision about which oracle is canonical |
| Exact-arithmetic, terminology, banned-token and prose audits | Julia and Mandelbrot `tools/audit_{exact_arithmetic,terminology}.py` (diverged copies); Mandelbrot `tools/source_tokens.py`; bulbs `tools/audit_limits.py` | `tools/claim_governance` checks | the policies differ per repository; the engines need a shared policy format |
| Manuscript and Markdown source validators, recorded-data checksums | Pisot `tools/check_{manuscript,markdown}_source.py`, `tests/test_recorded_data_integrity.py` | `tools/` | no second consumer yet |
| `BPA.tla` and its models | Pisot `proof/tla/` | beside `substitution_dynamics` | its models are generated against Pisot's ledger |
| Polyglot boundary envelope copies | `.polyglot/` in Julia, Mandelbrot and Pisot | `schemas/` as a parameterised template | only `$id`, `title` and `boundary_id` differ; needs a template mechanism |

## Not candidates

- `larsbx/math-vizops` `build/lib/` is a tracked, stale copy of `vizops/` with no unique
  code; it is a deletion for that repository, not a move here.
- Pisot `archive/2026-09-08/instruments/` imports modules that are not tracked and cannot
  be replayed; its ad-hoc Tarjan, charpoly and cyclotomic helpers would import this
  repository if it were revived.
- Bulbs `experiments/scripts/exact_index.py` duplicates `reference/cyclotomic_reference.py`
  on purpose, as an independent instrument.
