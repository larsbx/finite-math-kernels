# Survey assessment — kernel work it implies (2026-10-05)

Status: planning note. Authority: none. It ranks candidate kernels; it states no
mathematical result and changes no contract.

Source: the external open-problems survey stored verbatim in
`larsbx/finite-mandelbrot-research` as
`docs/literature/open-problems-survey-2026-10.md` (status October 2026), with
the consumers' assessments beside it (`docs/survey-assessment-2026-10-05.md` in
`larsbx/finite-mandelbrot-research` and `larsbx/finite-julia-set-research`).
This note keeps only what is domain-neutral and therefore belongs here, per the
estate rule restated in `docs/vendoring-candidates-2026-10-05.md`.

Julia authority for rank 3: the
[algebraic-multiplier gate at efba3f2e0af31df4dc81169b6a83a5adc8aaaec6](https://github.com/larsbx/finite-julia-set-research/blob/efba3f2e0af31df4dc81169b6a83a5adc8aaaec6/docs/literature-gate-2026-10-06-algebraic-multiplier.md),
findings 2–7. It accepts qualitative Diophantine/Brjuno imports and derives a
conditional tail estimate; it supplies no numerical bound or implemented
rotation-domain certificate. The Laurent route formerly cited here is
withdrawn by its finding 6.

## 0. Bottom line

The survey's "accessible attack surfaces" that the consumers adopt all reduce to
three missing kernels. The labels are their ranks in section 1; rank 2 builds
on rank 1.

- rank 1: polynomials over `F_p` with distinct-degree factorisation;
- rank 3: continued-fraction prefixes of a rotor's turn, computed without
  angles. A proposed finite input to a Brjuno-sum bound, conditional on the
  consumer supplying audited constants and logarithm enclosures;
- rank 4: truncated power series over `Q`, with a 2-adic valuation.

The first is already a deferred candidate. The survey raises it to the top,
because two consumer directions block on it.

## 1. Ranked candidates

| Rank | Kernel | Consumer direction (survey §) | Existing pieces | Blocker today |
|---|---|---|---|---|
| 1 | `finite_polynomial/polynomial_fp`: `F_p[x]` arithmetic, gcd, Frobenius powering mod `f`, distinct-degree factorisation, squarefree test | Mandelbrot: Gleason `n = 11…14` irreducibility, Misiurewicz `(m, 4)` data, certified Galois groups (§6) | `finite_exact/fp.mojo` (`Fp[p]`, `p < 2^31`); Mandelbrot `kernel/mojo/dynamics/exact_type_irreducibility.mojo` (machine-`Int`) | the deferred row's "unchecked products". With coefficients typed as `Fp[p]`, `p < 2^31`, every product is below `2^62`, so building on `Fp[p]` removes the blocker rather than working around it |
| 2 | Galois-group witness checker: given an irreducible `f ∈ Z[x]` of degree `d` and two good primes, accept iff the patterns are `(2,1,…,1)` and `(d−1,1)`, which gives `Gal = S_d` | Mandelbrot §4.1 | rank 1, plus a subset-sum irreducibility check | rank 1 |
| 3 | Rotor turn continued fraction: the partial quotients `a_1 … a_N` of the turn of a rotor of infinite order, and the convergent denominators `q_1 … q_N`, to be obtained by exact comparisons of its powers. No logarithm, no angle, output exact and replayable | Proposed Julia `niven` consumer: `docs/literature-gate-2026-10-06-algebraic-multiplier.md`, finding 7, derives a route-D tail estimate conditional on explicit audited Diophantine constants. A prefix through `q_N >= 3` could supply the finite sum once the consumer also encloses its logarithms. A quantitative linearization-radius bridge and rotation-domain `IN` checker remain open. Second candidate consumer: the bulb–Ford continued-fraction and Brjuno-sum code (`docs/vendoring-candidates-2026-10-05.md`) | `projective_limits/rotor` (turns, orders); `rational_dynamics.continued_fraction` (for rational inputs) | a prefix specification with correctness/termination and replay is missing. The Julia consumer also lacks instantiated constants, logarithm enclosures, a quantitative radius bridge and an `IN` checker; none is supplied by this planning note |
| 4 | `power_series` over `Q`: truncated series, composition, exact `ν_2` on `Q` | Ewing–Schober coefficients `b_m` and the Zagier 2-adic conjecture for `m ≢ 2 (mod 4)` (§1.5; the Mandelbrot assessment marks this direction optional); exact bound `area(M)/π ≤ 1 − Σ_{m≤N} m b_m²` | `rat_q`, `BigZ`; jets exist only over `CyclotomicQ` (`finite_polynomial/quadratic_germ.mojo`) | the deferred "no shared ring trait" row. A `Q`-only first version avoids the trait question |
| — | NTT multiplication for `F_p[x]` | performance for rank 1 at degree ≳ 4000 | candidate 2 of `docs/frontier-math-compute-candidates.md` | measure first, under that charter's authority firewall |

## 2. What stays consumer-side

- **Brjuno and linearization bounds.** `niven` is Brjuno by the algebraic
  multiplier import, independently of a prefix. Gate finding 7 bounds the
  tail by `4 (D + C log(2 q_N))/q_N`, with `D = -log A`, only after audited
  constants `A, C` have been supplied. Constants, logarithm enclosures,
  analytic radius bounds and `IN` interpretation stay in the consumer.
  Rank 3 is a planning priority for these proposed consumers, not a report
  that their quantitative certificate exists.
- **Quadtree area drivers and Koebe bounds.** These are renderer policy over
  `IQ`/`ComplexIQ`. The exact dyadic sum of box areas is trivial and needs no
  kernel.
- **Hubbard trees and core-entropy matrices.** These already sit with the
  consumer per `docs/tuning-substitutions-spec.md`. The survey does not change
  that.
- **Rational periodic points over `Q` (Poonen).** No consumer adopts it.

## 3. Acceptance, in this repository's terms

Each kernel lands with three things:

- a spec;
- a Python reference oracle that agrees transcript for transcript;
- negative controls, among them:
  - a product of two irreducibles never certifies;
  - a capped prime search that finds no `S_d` witness reports *inconclusive*;
  - a series truncated at order `N` never reports a coefficient beyond `N`;
  - a rotor of finite order (a root of unity, whose turn is rational) is
    refused rather than given a terminating expansion that a consumer could
    mistake for an irrational prefix.

The library computes finite facts. Irreducibility, Galois groups and area bounds
become claims only in a consumer's ledger.

Reference values for rank 1, from a throwaway distinct-degree factorisation
over `F_2` run on 2026-10-05:

- the Gleason polynomials `G_n mod 2` are squarefree for `n <= 16`;
- every irreducible factor has degree `n`, or `n/2` when `n` is even (e.g.
  `G_4 ≡ (deg 2)(deg 4)`, `G_12 ≡ (deg 6)^5 (deg 12)^165`);
- `G_n mod 2` is irreducible only for `n <= 3`.

These are test vectors, not claims.
