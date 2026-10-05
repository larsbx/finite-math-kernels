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

## 0. Bottom line

The survey's "accessible attack surfaces" that the consumers adopt all reduce to
three missing kernels:

1. polynomials over `F_p` with distinct-degree factorisation;
2. truncated power series over `Q`, with a 2-adic valuation;
3. continued-fraction prefixes of a rotor's turn, computed without angles.

The first is already a deferred candidate. The survey raises it to the top,
because two consumer directions block on it.

## 1. Ranked candidates

| Rank | Kernel | Consumer direction (survey §) | Existing pieces | Blocker today |
|---|---|---|---|---|
| 1 | `finite_polynomial/polynomial_fp`: `F_p[x]` arithmetic, gcd, Frobenius powering mod `f`, distinct-degree factorisation, squarefree test | Mandelbrot: Gleason `n = 11…14` irreducibility, Misiurewicz `(m, 4)` data, certified Galois groups (§6) | `finite_exact/fp.mojo` (`Fp[p]`, `p < 2^31`); Mandelbrot `dynamics/exact_type_irreducibility.mojo` (machine-`Int`) | the deferred row's "unchecked products". With coefficients typed as `Fp[p]`, `p < 2^31`, every product is below `2^62`, so building on `Fp[p]` removes the blocker rather than working around it |
| 2 | Galois-group witness checker: given an irreducible `f ∈ Z[x]` of degree `d` and two good primes, accept iff the patterns are `(2,1,…,1)` and `(d−1,1)`, which gives `Gal = S_d` | Mandelbrot §4.1 | rank 1, plus a subset-sum irreducibility check | rank 1 |
| 3 | `power_series` over `Q`: truncated series, composition, exact `ν_2` on `Q` | Ewing–Schober coefficients `b_m` and the Zagier 2-adic conjecture for `m ≢ 2 (mod 4)` (§1.5); exact bound `area(M)/π ≤ 1 − Σ_{m≤N} m b_m²` | `rat_q`, `BigZ`; jets exist only over `CyclotomicQ` (`finite_polynomial/quadratic_germ.mojo`) | the deferred "no shared ring trait" row. A `Q`-only first version avoids the trait question |
| 4 | Rotor turn continued fraction: the first `n` partial quotients of the turn of a rotor of infinite order, decided by exact comparisons of its powers | Julia `niven` row (§3): data only, never a rotation-number class | `projective_limits/rotor` (turns, orders); `rational_dynamics.continued_fraction` (for rational inputs) | none known; needs a spec saying the output is a prefix and nothing more |
| — | NTT multiplication for `F_p[x]` | performance for rank 1 at degree ≳ 4000 | candidate 2 of `docs/frontier-math-compute-candidates.md` | measure first, under that charter's authority firewall |

## 2. What stays consumer-side

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
  - a series truncated at order `N` never reports a coefficient beyond `N`.

The library computes finite facts. Irreducibility, Galois groups and area bounds
become claims only in a consumer's ledger.

Reference values for rank 1, from a throwaway distinct-degree factorisation
over `F_2` run on 2026-10-05:

- the Gleason polynomials `G_n mod 2` are squarefree for `n <= 16`;
- every irreducible factor has degree `n`, or `n/2` when `n` is even (e.g.
  `G_4 ≡ (deg 2)(deg 4)`, `G_12 ≡ (deg 6)^5 (deg 12)^165`);
- `G_n mod 2` is irreducible only for `n <= 3`.

These are test vectors, not claims.
