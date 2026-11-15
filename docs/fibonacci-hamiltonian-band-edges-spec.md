# Fibonacci trace polynomials and certified band edges: specification

**Status:** specification of the package `fibonacci_hamiltonian` (`kernel/fibonacci_hamiltonian/`), with the executable reference `reference/fibonacci_hamiltonian_reference.py`. `tests/fibonacci_hamiltonian/test_band_edges_reference.py` and `tests/fibonacci_hamiltonian/test_band_edges.mojo` pin the same constants. The package states no theorem: it computes finite facts about polynomials with rational coefficients. Three classical theorems turn those facts into statements about spectra; all three are the consumer's imports (section 6).

Terminology is field-recognizable (trace map, trace polynomial, Fricke-Vogt invariant, periodic approximant, band, gap, band edge). No novel bridge term is introduced.

## 0. Scope and non-scope

In scope, for a rational coupling `lam` and a level `k >= 0`:

- the trace polynomials `t_0, ..., t_k` in `Q[E]`, their scalar recurrence, and the invariant of three consecutive ones;
- disjoint rational brackets for every real root of `t_k - 2` and of `t_k + 2`;
- the bands of the sublevel set `S_k = {E real : |t_k(E)| <= 2}` between those brackets, with an inner and an outer rational enclosure of each band and two-sided bounds on the length of each gap between bands;
- the union of the outer enclosures of two consecutive levels.

Out of scope, by design:

- any operator, any spectrum, any spectral measure, and the Fibonacci Hamiltonian itself;
- an inner bound on the spectrum of the Fibonacci Hamiltonian, and therefore an upper bound on any of its gaps;
- Hausdorff or box dimension, transport exponents, and every limit in `k`;
- irrational couplings, and other substitutions or frequencies;
- floating point, and any approximation of an edge by a single number.

## 1. The trace polynomials

```text
t_(-1) = 2,    t_0 = E,    t_1 = E - lam,    t_(k+1) = t_k t_(k-1) - t_(k-2)
```

This is the recurrence of Suto [S87] for the half-traces `x_k = t_k / 2`, namely `x_(k+1) = 2 x_k x_(k-1) - x_(k-2)` with `x_(-1) = 1`, `x_0 = E/2`, `x_1 = (E - lam)/2`, cleared of denominators; it is the trace map of Kohmoto, Kadanoff and Tang [KKT83].

- `trace_polynomials(k, lam)` is the list `[t_0, ..., t_k]` and `trace_polynomial(k, lam)` its last member, as normalized ascending coefficient lists of `finite_linear_algebra/qpoly.mojo`. A negative level is refused: the Mojo kernel returns the empty list (the zero polynomial), the reference raises.
- `trace_value(k, lam, E)` runs the same recurrence on rationals.
- `invariant(a, b, c) = a^2 + b^2 + c^2 - a b c - 4`.

Finite facts, each tested at the stated levels and couplings and asserted nowhere else:

- `t_k` is monic of degree `F_k`, with `F_0 = F_1 = 1` and `F_(k+1) = F_k + F_(k-1)`;
- `invariant(t_(k-1), t_k, t_(k+1))` is the constant polynomial `lam^2`, starting from `(t_(-1), t_0, t_1)`;
- `trace_value(k, lam, E)` equals `evaluate(trace_polynomial(k, lam), E)`;
- for the word `W_0 = 0`, `W_1 = 1`, `W_(k+1) = W_(k-1) W_k` and the cyclic tridiagonal matrix `J` of size `F_k >= 3` with diagonal `lam W_k`, ones beside the diagonal and `c` in the two corners, `charpoly(J)` is `t_k - 2` for `c = 1` and `t_k + 2` for `c = -1`.

The last fact is what ties the recurrence to a matrix. It is an independent computation (the Faddeev-LeVerrier recurrence of `finite_linear_algebra/faddeev_leverrier.mojo` against a polynomial recurrence), and because `J` is real symmetric it shows, at those levels, that every root of `t_k - 2` and `t_k + 2` is real. The package does not use that, and does not claim it at other levels.

## 2. Edges

An **edge** is a record `(lo, hi, level)` with `lo < hi` rational and `level` equal to `2` or `-2`.

```text
P_+ = squarefree_part(t_k - 2),    P_- = squarefree_part(t_k + 2)
```

1. `real_root_brackets` (`docs/exact-polynomial-root-isolation-spec.md`, section 6a) is run on `P_+` and on `P_-` with the caller's `width` and `max_steps`; either refusal is a refusal.
2. The two ascending lists are merged by ascending `lo`, the `+2` side first on a tie.
3. If some consecutive pair of the merged list has `hi > lo` (the first bracket ends after the second begins), the first such pair is taken, each of its two brackets is replaced by `halve_bracket` on its own polynomial, and step 2 is repeated. Each halving spends one of a second budget of `max_steps`; when none is left the call refuses.

A pair that overlaps anywhere produces a consecutive pair that does, because the list is sorted by `lo`. `P_+` and `P_-` have no common root, so the brackets of two distinct roots separate once they are narrow enough and step 3 ends.

**What the edges carry by themselves.** On acceptance: every edge has width at most `width`; `t_k - level` has nonzero values of opposite sign at its ends, so `t_k` takes the value `level` strictly inside it (intermediate value theorem); and consecutive edges satisfy `hi <= lo`.

## 3. Segments

For consecutive edges `e_i`, `e_(i+1)` the **test point** is `c_i = (e_i.hi + e_(i+1).lo) / 2`, and the segment between them is **inside** when `|t_k(c_i)| < 2` and **outside** when `|t_k(c_i)| > 2`, computed by `trace_value`. Equality is refused.

`c_i` lies between the two edges, so above the point of `e_i` where `t_k` is `+-2` and below that of `e_(i+1)`. If the edges are every real root of `t_k^2 - 4` (section 6, import I1), `|t_k| - 2` has no zero between those two points and so one sign there, the one read at `c_i`.

## 4. Bands, gaps and enclosures

A **band** is a maximal run of consecutive inside segments, recorded as the indices `(left, right)` of the edges at its two ends. An edge with an outside segment, or no segment, on both sides is refused: it would be an isolated point of `S_k`, which import I2 of section 6 excludes for these traces; the kernel refuses rather than report it as a band. An edge with inside segments on both sides is a **closed gap**; `closed_gaps` counts them, as `len(edges) - 2 len(bands)`.

`approximant(k, lam, width, max_steps)` returns a refusal or the record `(k, edges, bands)`. From it:

```text
outer_bands   [edges[left].lo, edges[right].hi]      per band
inner_bands   [edges[left].hi, edges[right].lo]      per band
gap_bounds    [next.left.lo - right.hi,  next.left.hi - right.lo]    per consecutive pair of bands
```

Under import I1, `S_k` is the union of `len(bands)` disjoint closed intervals, the `i`-th one contains `inner_bands[i]` and is contained in `outer_bands[i]`, and the length of the `i`-th gap of `S_k` lies in `gap_bounds[i]`. Each of those intervals has width at most `2 width` around its target.

Without I1 the record still carries, by sign evaluations alone: `|t_k| < 2` at the three tested points of every inner band, `|t_k| > 2` at the test point of every gap, and a point where `|t_k| = 2` inside every edge.

## 5. The cover by two consecutive levels

`cover(first, second)` merges the outer enclosures of two approximants into ascending intervals, joining two that meet. It is a finite union of rational intervals that contains `S_k` and `S_(k+1)` when the arguments are the approximants of levels `k` and `k + 1` (under I1 for both).

Tested at the stated levels, and asserted nowhere else: at the midpoint of every gap of the cover, `|t_k|`, `|t_(k+1)|` and `|t_(k+2)|` all exceed `2`; and every inner band of level `k + 2` lies in one interval of the cover of levels `k` and `k + 1`.

## 6. What the readings import

The package computes sections 1 to 5. Three theorems give them meaning. It proves none, restates none as its own, and names no function after any; a consumer that uses one names and gates it in its own ledger.

- **I1, Sturm's theorem.** The brackets of `real_root_brackets` are every real root, one per bracket. Sections 3 to 5 read `S_k` through it. At a level where each of `P_+` and `P_-` yields `F_k` brackets, I1 can be dropped: a polynomial of degree `F_k` has at most `F_k` roots. The tests observe that count at every stated level with nonzero coupling.
- **I2, Floquet theory.** `S_k` is the spectrum of the periodic discrete Schrodinger operator `(H u)(n) = u(n+1) + u(n-1) + lam W(n) u(n)` whose potential repeats the word `W_k` of section 1, and `t_k` is the trace of its transfer matrix over one period; see Toda [T89], chapter 4, or Simon [Si11], chapter 5. The last fact of section 1 is the finite shadow of this that the tests check.
- **I3, Suto's theorem** [S87]. With `Sigma_lam` the spectrum of the Fibonacci Hamiltonian at coupling `lam` (the same operator with `W(n) = 1` when `n alpha mod 1 >= 1 - alpha` and `0` otherwise, `alpha = (sqrt(5) - 1)/2`): `S_(k+1) ∪ S_(k+2)` is contained in `S_k ∪ S_(k+1)`, and `Sigma_lam` is the intersection over `k` of `S_k ∪ S_(k+1)`.

Under I1, I2 and I3 together, `cover` of levels `k` and `k + 1` contains `Sigma_lam`, and every gap of the cover lies in a gap of `Sigma_lam`: its length is a **lower** bound for the length of that gap.

**What is not here.** No upper bound on a gap of `Sigma_lam` and no point of `Sigma_lam`: an inner statement needs energies whose trace orbit is known to be bounded, which this package does not produce. No statement about the limit in `k`: that `Sigma_lam` is a Cantor set of zero Lebesgue measure for every nonzero `lam` [S89], its dimension, and the opening of every gap are theorems about the limit, and a finite list of levels is evidence for none of them. No statement at a coupling or level that was not run.

## 7. Stated domain of the tests

| Suite | Couplings | Levels |
| --- | --- | --- |
| `tests/fibonacci_hamiltonian/test_band_edges_reference.py` | `1, 1/2, 5, -3/2`; `0` for the closed-gap case | `0 .. 8` (`F_8 = 34`) |
| `tests/fibonacci_hamiltonian/test_band_edges.mojo` | the same | `0 .. 5` (`F_5 = 8`) |

Both use `width = 2^-20`. At every nonzero coupling and level in the table: `F_k` bands, `2 F_k` edges, no closed gap. At coupling `0`: one band with outer enclosure around `[-2, 2]` and `F_k - 1` closed gaps. The Mojo suite stops at level `5` for running time only; the kernel has no level cap, and a caller sets `max_steps`.

## 8. Boundaries

- A refusal is a rejected value in Mojo and `None` in the reference. A capped search is inconclusive, never a claim about roots or bands.
- No function returns a floating-point number, and no function names an edge by a single rational. An edge is a bracket.
- The kernel does not know that `t_k` came from an operator, and no name in it says spectrum.

## References

- [KKT83] M. Kohmoto, L. P. Kadanoff and C. Tang, "Localization problem in one dimension: mapping and escape", Phys. Rev. Lett. 50 (1983) 1870-1872, doi:10.1103/PhysRevLett.50.1870.
- [S87] A. Suto, "The spectrum of a quasiperiodic Schrodinger operator", Comm. Math. Phys. 111 (1987) 409-415, doi:10.1007/BF01238906.
- [S89] A. Suto, "Singular continuous spectrum on a Cantor set of zero Lebesgue measure for the Fibonacci Hamiltonian", J. Stat. Phys. 56 (1989) 525-531, doi:10.1007/BF01044450.
- [T89] M. Toda, *Theory of Nonlinear Lattices* (2nd ed., Springer, 1989), chapter 4.
- [Si11] B. Simon, *Szego's Theorem and Its Descendants* (Princeton, 2011), chapter 5.
- Sturm's theorem and the isolation it supports: `docs/exact-polynomial-root-isolation-spec.md`, sections 5 and 6a.
