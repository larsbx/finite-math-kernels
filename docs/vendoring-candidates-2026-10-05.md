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

## Moved in round 2

Decision **D1**: this repository has a vendorable *Python* plane, in `oracles/`
(and `tools/` for audits), for consumers that are Python-only or that check
arithmetic without a Mojo toolchain. Its packages are pure standard library
(`fractions`, `math`), exact, and fail closed: an input outside the domain is
refused, never approximated, clamped or capped. Each docstring states what is
and is not claimed, as the Mojo packages do. They are non-authoritative where a
Mojo package overlaps them, and `oracles/oracle_refinement` was the precedent.
D1 removes the blocker "this repository vendors no Python `rational_dynamics`"
below, and it settles the "which oracle is canonical" question for the
`closed_q` twin: Julia's copy becomes this repository's, and Julia vendors it.

| Upstream now | From | Consumer action |
|---|---|---|
| `oracles/rational_dynamics_py`: continued fractions, units, mediants, Farey sequences and parents, preperiod and exact period, binary expansions, rotation cycles, mechanical words, wakes, rotation numbers, doubling orbits, Moebius, Dedekind and Ramanujan sums; the R1 reference moves in and `reference/rational_dynamics_reference.py` re-exports it | bulbs `kernel/bulbford/{cf,wake,cycles}.py`, `experiments/scripts/{spectral,bridges_spike}.py`; vizops `atlas/trace.py` `period_of`; Mandelbrot `misiurewicz_catalogue_reference.py` (`moebius`, `exact_type`) and `structure_names_reference.py` (`farey_neighbours`, `rotation_angles`) | bulbs and vizops vendor it and delete their copies; Mandelbrot may keep its two references as independent oracles or call it |
| `oracles/closed_interval`: `IQ`, `ComplexIQ` (alias `ComplexBox`), directed dyadic rounding | Julia `reference/interval_box.py`, `reference/dyadic.py` | Julia vendors it and switches by import path (`from closed_interval import ComplexBox, IQ, round_down, round_up`) |
| `tools/exact_arithmetic_audit`: one engine and a `Policy` for the spec section 7 audit | Julia and Mandelbrot `tools/audit_exact_arithmetic.py` (diverged copies) | Julia and Mandelbrot vendor it with `vendoring` and `claim_governance` and keep only their `Policy`; Julia vendors `claim_governance` for the first time |
| `vendored_directories` in `tools/vendoring` | Julia's three hand-written readers of `vendored.toml` (`audit_exact_arithmetic.py`, `audit_terminology.py`, `tests/test_documented_invariants.py`) | Julia re-pins `vendoring` and calls it |

What the consumers' copies disagreed on, found while porting:

- bulbs `dedekind(h, k)` runs reciprocity without dividing out `gcd(h, k)`, so
  it disagrees with the defining sum whenever `gcd(h, k) > 1` (`s(2, 4)` came
  out `-1/32`; it is `0`). Its one caller uses a prime `k`, where the two agree.
- vizops `period_of` answers `None` both for a preperiodic angle and for a
  period past its cap, and its cap of 32 admits 33. Here the period is exact
  and uncapped, and "preperiodic" is `preperiod > 0`.
- Mandelbrot `farey_neighbours` answers `None` on a boundary side, and not
  symmetrically: `(None, 1)` at `0` but `(None, None)` at `1`, where `0/1` is a
  Farey parent. `farey_parents` refuses both ends.
- bulbs `coprime_numerators(1)` is empty; `units(1)` is `(0,)`, so that it has
  `phi(1) = 1` elements. Bulbs `farey(n)` is the interior of `F_n`.
- Bulbs `wake` and Mandelbrot `rotation_angles` agree on every `p/q` with
  `q <= 10` (tested), by different algorithms; Mandelbrot's answers `(0, 0)`
  at `0`, which `wake` refuses.
- Julia `IQ.width` and `midpoint` answered `0` and `1/2` for a rejected
  interval, so a refused box measured as converged; they now raise. Julia's
  `enclosure_bound.mojo` row records the same "a rejected box measures as
  zero" behaviour on the Mojo side, which is that repository's to revisit.
- The two exact-arithmetic audits disagreed on: where the binding table lives
  (a separate document vs. a section of the spec), whether classes are
  validated, which `finite_exact` imports make a consumer (any module vs. four),
  hidden directories, the C7 exemption (every vendored file from the manifest
  vs. four named facades), a C1 exemption for vendored `finite_exact`, how
  comments and strings are skipped, the float pattern (Mandelbrot's missed
  `DType.float32`; Julia's missed `2.`, `.5`, `1e-3`, `Float`) and whether
  allowlist prose grants. Run against both live trees with the policies in the
  package docstring, the engine reports nothing on either. Of the policy
  differences, only the import set matters on today's trees: with "any
  `finite_exact` module", Mandelbrot has seven unbound modules (for example
  `kernel/mojo/arithmetic/big_int_boundary.mojo`).

Not moved, and why: Brjuno sums (a sum of logarithms, not exact); the Mojo
halves of the doubling-map row (Mandelbrot `misiurewicz_catalogue.mojo`,
`angle_tuning.mojo`); the other audits of the audits row; Krawczyk and the
other `root_isolation` candidates. The Python package is named
`rational_dynamics_py`, not `rational_dynamics`, so it never shares a name, and
therefore a `vendored.toml` entry, with the Mojo package.

## Found and deferred

Each row is generic in substance but is not a byte-for-byte move today. The reason is the
blocker; removing it is the next step.

| Candidate | Where | Target | Blocker |
|---|---|---|---|
| Krawczyk / interval Newton (1-D and 2-D), certified roots of unity, separated-exponent boxes (dyadic outward rounding moved in round 2) | Julia `reference/{preperiodic,dyadic,scaled}.py`; bulbs `kernel/bulbford/{certify,antipode}.py`; Mandelbrot `certificates/krawczyk_witness.mojo` | new `root_isolation`; `finite_exact` | three implementations in two languages with different box types; needs one specification first, as `qpoly` had |
| Truncated jets and Taylor models over a coefficient ring | Julia `kernel/{jet,taylor}.mojo`, `reference/{jet,taylor}.py`; bulbs `implosion.py` series helpers | `finite_polynomial` | `quadratic_germ` jets are over `CyclotomicQ`, Julia's over `ComplexIQ`; Mojo has no shared ring trait here yet |
| Q-polynomials, Sturm, Tarski query, Routh/Pisot screen, cubic number fields | Pisot `psc/{pisot,real_root_sign,pisot_screen,field3,perron_*}.mojo`; Mandelbrot `structure_names_reference.py` `sturm_count` | `finite_linear_algebra/qpoly`, `finite_polynomial` | three local Q-polynomial layers to converge on `qpoly`'s API; the Pisot ones are cubic-specific and have about 25 importers |
| F_p polynomials, distinct-degree factorisation, irreducibility certificates, Hensel steps, modular inverse, primality | Mandelbrot `dynamics/{exact_type_irreducibility,r41_algebraic_root_certificate,critical_relation_bridge}.mojo` | new `finite_polynomial/polynomial_fp` | machine-`Int` coefficients with unchecked products; must move onto `BigZ` or `checked_int` first |
| Doubling-map number theory in Mojo: catalogue counts and binary blocks (the Python half moved in round 2) | Mandelbrot `misiurewicz_catalogue.mojo`, `angle_tuning.mojo` | `rational_dynamics`, `angle_doubling` | Mandelbrot's types are checked `Int64`; the Mojo `angle_doubling` caps its order search at 64 and would need the uncapped order first |
| Kneading, internal address, continuation letter | Mandelbrot `c1/residual/residual_directive_carrier.mojo` | `substitution_dynamics/tuning` | Mandelbrot pins `tuning.mojo` before `continuation_twist`; re-pin, then retire the brute-force letter |
| Ray-address doubling (three Int64/BigQ variants), collision partition (five copies) | Mandelbrot `dynamics/*ray_address.mojo`, `interval_orbit.mojo`, `certificates/*` | `rational_dynamics`, `quadratic_orbit` | importers are C1 research modules; about 45 of the files use the retired `fn`/`inout` syntax and are not compiled |
| Checked Int64 Q / IQ / ComplexIQ stack | Mandelbrot `arithmetic/checked_*.mojo` | `finite_exact` fast path, or retire | a policy decision: BigQ replays of the same certificates exist |
| Gaussian rationals, rational trigonometry | Julia `reference/gaussian_q.py`; Mandelbrot `arithmetic/{complex_inverse,coord_record_eval,rank2_operator,rational_trig}.mojo` | `finite_exact` or `cyclotomic_q` (conductor 4) | the Mandelbrot types are uncompiled legacy syntax |
| Escape certificates, multiplier trichotomy, box constructors | Julia `kernel/{escape_certificate,julia_orbit,enclosure_bound}.mojo` | `quadratic_orbit`, `finite_exact/closed_q` | three local copies of the escape bound to reconcile first |
| Substitution symmetry, endpoint maps, Barge class, bounded BPA, Dumont-Thomas numeration, return lattices, strong-coincidence automata | Pisot `psc/{symmetry,endpoint_core,barge_class,bounded_bpa,dumont_thomas,return_lattice,coincidence_*}.mojo` | `substitution_dynamics` | `ALPHABET = 3` hardwired, or imports reach `perron_field3` |
| PRNG, bounded histogram, hash mixing | Pisot `psc/{prng,histogram}.mojo`, three `_mix_hash` copies | a census-support package | no second consumer yet |
| Python references for `substitution_dynamics` and the remaining `closed_q` copy (Julia's moved in round 2) | Pisot `reference/psc_research/{bpa,swap_discrepancy}.py`; Mandelbrot `interval_exclusion_reference.py` | `reference/` | they are deliberately independent oracles in their consumers; copying one here is a decision about which oracle is canonical |
| Terminology, banned-token and prose audits (the exact-arithmetic audit moved in round 2) | Julia and Mandelbrot `tools/audit_terminology.py` (diverged copies); Mandelbrot `tools/source_tokens.py`; bulbs `tools/audit_limits.py` | `tools/claim_governance` checks | the policies differ per repository; the engines need a shared policy format |
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
