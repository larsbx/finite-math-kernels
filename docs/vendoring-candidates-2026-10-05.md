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

## Moved in round 3 (2026-10-06)

Owner decisions taken for this round:

- **Naming rule.** Every named, citable literature object gets its own module
  named after it, with a citation docstring, re-exported from the package
  facade; old paths keep re-exporting.
- **Checked Int64 stack** (Mandelbrot `Q` / `IQ` / `ComplexIQ`): retired. BigQ
  replays are the certificates of record; there is no fast path here.
- **Uncompiled legacy** (`fn`/`inout`) Mandelbrot modules: port only what
  compiled code uses; dead files stay untouched.
- **Independent Python oracles** for `substitution_dynamics` (Pisot `bpa.py`,
  `swap_discrepancy.py`) and Mandelbrot `interval_exclusion_reference.py` stay
  in their consumers; they are not candidates.
- **PRNG, histogram and hash mixing, the manuscript and Markdown validators,
  `BPA.tla`**: stay deferred (one consumer each; the steward's "decide whether
  to build" rule).
- **Escape-test tie** `N(z) = N(c) > 4`: the strict test stays. The owner had
  no preference; strict matches every copy and keeps Julia's ledgers
  byte-identical. The tie stays undecided and is never reported as bounded.

| Upstream now | From | Consumer action |
|---|---|---|
| Named modules (Mojo): `cauchy_bound`, `sturm_sequence`, `faddeev_leverrier`, `wielandt_bound`, `hermite_normal_form`, `smith_normal_form` (`finite_linear_algebra`); `continued_fractions`, `farey` (`rational_dynamics`); `krawczyk_operator` (`quadratic_orbit`); `cyclotomic_polynomial`, `euler_totient`, `moebius_function` (`finite_polynomial`); `subset_construction`, `moore_minimisation` (`finite_automata`); `mobius_transformation`, `spread_polynomial` (`projective_limits`). Python `rational_dynamics_py`: `addresses`, `continued_fractions`, `moebius_function`, `dedekind_sums`, `ramanujan_sums`, `mechanical_words`, `rotation_sets`, `wakes` | FMK's own generic modules | none: old paths re-export the same objects |
| `quadratic_orbit/escape_criterion.mojo`, `quadratic_orbit/multiplier_classification.mojo`; `closed_q` `complex_box`, `gaussian_singleton`, `is_singleton`, `singleton_eq`; `enclosure_width` `sup_magnitude`, `within` | Julia's three escape-bound copies, `kernel/escape_certificate.mojo`, `julia_orbit.mojo`, `enclosure_bound.mojo` | Julia re-pins and deletes its copies; its five-way classification stays local on top |
| `finite_polynomial/{coefficient_ring,truncated_jet,taylor_model}.mojo`; `quadratic_germ` rebuilt on the generic jets | Julia `kernel/{jet,taylor}.mojo` | Julia keeps only the `z^2 + c` steps |
| `finite_polynomial/polynomial_fp.mojo` with `miller_rabin`, `distinct_degree`, `rabin_irreducibility`, `hensel_lifting` | Mandelbrot `dynamics/{exact_type_irreducibility,r41_algebraic_root_certificate,critical_relation_bridge}.mojo` | Mandelbrot calls it |
| — (already upstream: `finite_linear_algebra/qpoly`) | Pisot `psc/{pisot,pisot_screen,real_root_sign}.mojo` | done (Pisot PR #220) |
| `rational_dynamics/{doubling,multiplicative_order,carmichael,moebius,integers}.mojo`; `rational_dynamics_py/{multiplicative_order,carmichael}.py` and `exact_type_count`; `substitution_dynamics/internal_address.mojo` | Mandelbrot `misiurewicz_catalogue.mojo`, `angle_tuning.mojo`, `c1/residual/residual_directive_carrier.mojo` | Mandelbrot calls them and no longer imports its checked Int64 backend |
| `root_isolation` (Mojo: `krawczyk`, `krawczyk_moore`, `boxes`), `oracles/root_isolation_py`, `docs/root-isolation-spec.md`; `quadratic_orbit/krawczyk_operator` is its `z^2 + c` application | Julia `reference/preperiodic.py`; Mandelbrot `certificates/krawczyk_witness.mojo`; bulbs `kernel/bulbford/{certify,antipode}.py` | all three run on it |
| `tools/lexical_audit` | Julia and Mandelbrot `tools/audit_terminology.py`; bulbs `tools/audit_limits.py` | each keeps a thin policy |
| `tools/polyglot_envelope` | `.polyglot/` in Julia, Mandelbrot and Pisot | each renders from its `polyglot.manifest.toml`, `--check` in CI |
| `substitution_dynamics/{symmetry,endpoint_maps}.mojo` and named `barge_class`, `balanced_pair_algorithm`, `dumont_thomas`, `return_lattice`, `strong_coincidence` | Pisot `psc/{symmetry,endpoint_core,barge_class,bounded_bpa,dumont_thomas,return_lattice,coincidence_*}.mojo` | Pisot keeps thin alphabet-3 views, the C4 endpoint names and the Perron-field reserve |

**Naming.** Per the owner's rule, every named literature object that sat
inside a generic module now has its own cited module and the old module
re-exports it, so no import changes. Already-standalone modules gained
citations (Tarjan, Galler–Fischer, Kirchhoff cycle gain, Euclid, FIPS 180-4,
Livshits/Sirvent–Solomyak, Dekking, Derrida–Gervois–Pomeau/Douady–Hubbard,
Berthé–Delecroix, Adamczewski). Tests pin old and new paths to the same
objects.

**Escape criterion, multiplier classification, box constructors (Julia).**
`escape_criterion.mojo` (Carleson–Gamelin 1993; Milnor 2006) replaces Julia's
three escape-bound copies and `kernel/escape_certificate.mojo`. The copies
agreed on the strict test `N(z) > max(4, N(c))` and differed only on
refusals (two returned an accepted zero bound for a rejected parameter); the
reconciled bound is rejected on any refused or negative quadrance.
`multiplier_classification.mojo` (Milnor 2006; Koenigs 1884) decides
attracting, indifferent and repelling exactly, with UNDECIDED and REJECTED
kept apart. `sup_magnitude` and `within` refuse a rejected box (Julia's copy
measured it as zero). Julia's outputs are byte-identical.

**Truncated jets and Taylor models (Julia).** `coefficient_ring` gives
`CoefficientRing` / `CoefficientField` as ring values, `FieldRing[K]`,
`CyclotomicRing` with a run-time conductor and `ComplexBoxRing` over `closed_q`
boxes; `truncated_jet` gives `TruncatedJet[R]`; `taylor_model` (Berz–Makino
1998) is over complex boxes and re-exported. `quadratic_germ` is rebuilt on
the generic jets with byte-identical outputs (226 golden vectors). The Taylor
model is not generic in its enclosure ring: fields of associated type trip the
pinned compiler's "use of uninitialized value" bug
(`docs/mojo-exact-fields-report.md` §5.1). Still local: Julia's Python
`reference/{jet,taylor}.py` (an independent oracle); bulbs `implosion.py`
helpers (`_log` needs a Q-algebra; about 25 lines).

**F_p polynomials (Mandelbrot).** `polynomial_fp` takes a run-time modulus
below `2^31`; canonical residues keep every product below `2^62`.
`miller_rabin` is deterministic below `2^31` (witnesses {2, 3, 5, 7}),
`distinct_degree` is Cantor–Zassenhaus, `rabin_irreducibility` (Rabin 1980)
carries a replayable certificate, `hensel_lifting` is Hensel 1908. The three
Mandelbrot users have byte-identical outputs plus a differential check;
`critical_relation_multiset.integer_orbit_value` no longer wraps (now BigZ).
Still local: Mandelbrot's Int-coefficient `PolyZ` division over Z (a separate
item) and the subset-sum irreducibility-over-Q test. Possible next user:
Pisot's degree-4+ irreducibility refusal.

**Q-polynomials (Pisot).** Pisot `psc/{pisot,pisot_screen,real_root_sign}.mojo`
now build on the vendored `qpoly`. Kept local, with reasons: the unrolled
Horner, O(1) degree, the length-preserving remainder, the Sturm chain of `p`
itself, and the Tarski query.

**Kneading, internal address, continuation letter; doubling-map number theory
(Mandelbrot).** `substitution_dynamics/internal_address.mojo` (Lau–Schleicher
1994); `continuation_twist` reads off it. `rational_dynamics` gains an
uncapped BigZ `doubling.mojo` (preperiod, period, `exact_type`,
`binary_digits`, `binary_block`, `exact_type_count`) and the named modules
`multiplicative_order` (`order_of_two`), `carmichael` and `moebius`, with
`integers.mojo` (`bigz_to_int` refuses rather than truncates). The Python
plane mirrors them and a twin test replays a Mojo transcript. Local policy
stays in Mandelbrot: catalogue bounds, the 62-period tuning contract, the
kneading prefix of an angle. `angle_doubling` keeps its cap of 64; the exact
order lives in `rational_dynamics.multiplicative_order`.

One implementation per object after the merge: `rational_dynamics.moebius` is
the only Mojo Möbius function, and `finite_polynomial.moebius_function`
re-exports it as `moebius` and `mobius_mu` (`finite_polynomial` now imports
`rational_dynamics`, which imports only `finite_exact`, so consumers vendoring
`finite_polynomial` also vendor `rational_dynamics`). `mobius_mu` therefore
refuses `n < 1`, as `moebius` does; it returned `1` there before. In Python,
`moebius_function.moebius` is the one Möbius function, `order_of_two` lives
in `multiplicative_order` and the prime factorisation in `carmichael`;
`doubling` and `arithmetic` re-export them.

**Checked Int64 stack, ray-address doubling, collision partition, Gaussian
rationals (Mandelbrot, Julia).** The checked Int64 stack is retired. A probe
over half-widths `2^1 .. 2^-63` showed byte-identical boxes, Krawczyk images
and exclusion verdicts wherever the Int64 stack answered; beyond that it
rejected on overflow while BigZ answered. Compiled users of ray-address
doubling and the collision partition go through
`rational_dynamics.double_mod_one` and `quadratic_orbit`; the remaining copies
are in uncompiled legacy files. The Mandelbrot Gaussian-rational types are
uncompiled legacy except `rational_trig.mojo`; Julia `reference/gaussian_q.py`
has no second consumer and stays. The collision partition has not converged:
Mandelbrot's versions treat `ell = 0` as purely periodic,
`quadratic_orbit.intended_pair` does not.

**Krawczyk / interval Newton (Julia, Mandelbrot, bulbs).** Specification
first: `docs/root-isolation-spec.md` states the Krawczyk–Moore theorem with
exact hypotheses and a proof outline; its §8 inventories five
implementations that differ only in arithmetic, preconditioner and refusal
convention, never in what they certify. `root_isolation` (Mojo, one variable,
exact over `closed_q`) and `root_isolation_py` (one or two variables over
`closed_interval`, with rounding hooks) share a transcript test. The three
consumers' users run on it with byte-identical outputs. Left local: Julia
`reference/scaled.py` separated-exponent boxes (orbit enclosure, one
consumer); bulbs forbidden-pair exclusions, seeds and ζ selection. Certified
roots of unity are Krawczyk plus disjointness (no module). Moore's interval
Newton operator is not implemented (no consumer).

**Terminology, banned-token and prose audits.** `tools/lexical_audit` is a
frozen `Policy` plus `run(root, policy)`: clause rules with denial, allowed
phrases, exempt sections and paragraph markers; context rules; declaration
rules; governing documents. Where the audits differed only in mechanics the
engine fixes one behaviour (listed in the package docstring); a differential
run on about 31,000 mutated texts found no difference outside those classes.
Mandelbrot `tools/source_tokens.py` had already moved into
`claim_governance.lexing`. Not moved: bulbs `tools/audit_angles.py` (a
Python-token rule, one consumer).

**Polyglot boundary envelope.** `tools/polyglot_envelope` is a template and a
standard-library renderer that reads owner, repository and `boundary_id`
from each consumer's `polyglot.manifest.toml`. This repository's `schemas/`
and `conformance/` files are its rendering with FMK's facts. The consumer
copies also lacked FMK's malformed-digest and unknown-top-level-field
rejected vectors (drift; re-rendering adds them; the schemas are
byte-identical). `.polyglot/README.md` and `polyglot.manifest.toml` stay per
repository; agent-icm's `render_estate.py` does not cover these files.

**Substitution symmetry, endpoint maps, Barge class, bounded BPA,
Dumont-Thomas numeration, return lattices, strong coincidence (Pisot).** The
`ALPHABET = 3` constant was a parameter in all of them, and `perron_field3`
was reached only through `oa_overlap_types.prolongable_point` and the
coincidence automaton's pruning reserve. `substitution_dynamics` now has
`symmetry` and `endpoint_maps` and the named modules `barge_class` (Barge
2016; Barge-Kwapisz 2006), `balanced_pair_algorithm` (Livshits 1987;
Sirvent-Solomyak 2002), `dumont_thomas` (Dumont-Thomas 1989), `return_lattice`
(Durand 1998) and `strong_coincidence` (Arnoux-Ito 2001; Dekking 1978), the
last generic over a caller-supplied `DifferenceBound`. Pisot's Perron-field
reserve and its C4 A..G endpoint names stay local; its `psc` modules are thin
alphabet-3 views. Pisot's 80 claim receipts and the stdout of 20 dependent
census runs are byte-identical; FMK regressions pin the alphabet-3 outputs and
check two- and four-letter cases against independent routes.

**Vendoring checker.** Round 3 also fixed a regression of the round-2 change
(#67): `pin` walked only `<root>/<name>/`, so a package pinned as single files
under its root (Pisot's `proof_architecture`) could not be re-pinned. Listed
files outside the package directory are pinned again and must still exist.

Open for the owner after round 3:

- Mandelbrot `certificates/certificate_sets.mojo` is modern syntax but not
  compiled.
- Nothing reads `.polyglot/` (`ci_wiring = false`); the copies could be
  deleted and the ESTATE schemas plane pointed at the vendored template.
- `claim_governance.checks.terminology` overlaps the `lexical_audit` context
  rule and could be built on it.
- The kneading prefix of an angle is a candidate for its own named module.
- `root_isolation.boxes.is_point` and `closed_q`'s `ComplexIQ.is_singleton`
  (both new this round) test the same thing; one could call the other.
- `substitution_dynamics/__init__.mojo` stays an index, not a code re-export:
  re-exporting would make `finite_automata` a dependency of every consumer.
- The state-capped balanced pair automaton still lives in `automaton.mojo`;
  moving it into `balanced_pair_algorithm` would change a facade Julia and
  Mandelbrot pin.
- The Livshits 1987 citation (title, Russian Math. Surveys 42) should be
  checked against the source.

## Found and deferred

Each row is generic in substance but is not a byte-for-byte move today. The reason is the
blocker; removing it is the next step. In round 3 the owner kept these three rows
deferred: one consumer each, so nothing is built until a second one appears.

| Candidate | Where | Target | Blocker |
|---|---|---|---|
| PRNG, bounded histogram, hash mixing | Pisot `psc/{prng,histogram}.mojo`, three `_mix_hash` copies | a census-support package | no second consumer yet |
| Manuscript and Markdown source validators, recorded-data checksums | Pisot `tools/check_{manuscript,markdown}_source.py`, `tests/test_recorded_data_integrity.py` | `tools/` | no second consumer yet |
| `BPA.tla` and its models | Pisot `proof/tla/` | beside `substitution_dynamics` | its models are generated against Pisot's ledger |

## Not candidates

- Python references for `substitution_dynamics` and the remaining `closed_q`
  copy: Pisot `reference/psc_research/{bpa,swap_discrepancy}.py` and Mandelbrot
  `interval_exclusion_reference.py` stay independent oracles in their consumers
  (owner decision, round 3).
- Uncompiled legacy (`fn`/`inout`) Mandelbrot modules, including the remaining
  ray-address doubling and collision-partition copies and the Gaussian-rational
  types other than `rational_trig.mojo`: dead files stay untouched (owner
  decision, round 3). `rational_trig.mojo` and Julia `reference/gaussian_q.py`
  have no second consumer.
- `larsbx/math-vizops` `build/lib/` is a tracked, stale copy of `vizops/` with no unique
  code; it is a deletion for that repository, not a move here.
- Pisot `archive/2026-09-08/instruments/` imports modules that are not tracked and cannot
  be replayed; its ad-hoc Tarjan, charpoly and cyclotomic helpers would import this
  repository if it were revived.
- Bulbs `experiments/scripts/exact_index.py` duplicates `reference/cyclotomic_reference.py`
  on purpose, as an independent instrument.
