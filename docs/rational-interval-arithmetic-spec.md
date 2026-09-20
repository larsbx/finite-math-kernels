# Rational and interval arithmetic: canonical exactness specification

**Status:** specification of the `finite_exact` package (layer ℚ, sections 0 to 1) and of the `larsbx/interval_q` package built on it (layer I, sections 2 to 3); shared by every consumer that vendors either package. Sections 0 to 5 are repository-independent and carry no theorem: exactness removes one class of error from a computation, and the epistemic status of the computation is governed by each consumer's own claim-status documents. Section 6 names the consumers and where each keeps its binding table; section 7 says how a consumer enforces the specification.

History: this text was written in `larsbx/NLAP-JT` (`docs/rational-interval-arithmetic-spec.md`) while the arithmetic lived there, and moved here unchanged in sections 0 to 5 when the arithmetic was extracted. That program, now `larsbx/finite-mandlebrot-research`, and `larsbx/pisot-substitution-conjecture-research` keep only their binding rows.

Terminology in this file is field-recognizable (rational arithmetic, interval arithmetic, natural interval extension, dependency problem, floating-point filter). No novel bridge term is introduced.

## 0. The problem being solved

Let `F ⊂ ℝ` be a floating-point format (`F = F_{53}` for IEEE binary64). `F` is finite and non-uniform: it samples `ℝ` densely near `0` and sparsely far from it. Every arithmetic operation on `F` is a rounded operation

```text
fl(x ∘ y) = (x ∘ y)(1 + δ),   |δ| ≤ u,   ∘ ∈ {+, −, ×, ÷},
```

with unit roundoff `u = 2^{-53}`. Three consequences drive this specification.

1. **Algebraic laws fail.** `fl` is commutative but neither associative nor distributive: `(a +ᶠ b) +ᶠ c ≠ a +ᶠ (b +ᶠ c)` in general, and `fl(0.1) +ᶠ fl(0.2) ≠ fl(0.3)`. A computation's value therefore depends on evaluation order.
2. **Rounding is silent.** `δ` is not observable from the result, so a computed sign, a computed equality, or a computed `≤` carries no certificate.
3. **Cancellation destroys digits.** If `x ≈ y`, then `x −ᶠ y` retains only the bits in which `x` and `y` differ, and those bits are exactly the ones already contaminated by earlier `δ`.

For a proof-support kernel, (2) is fatal on its own: any predicate whose truth value enters a certificate (`= 0`, `> 0`, `∈ box`, `has a root`) must be decided by an arithmetic that either **never rounds** or **bounds every rounding in a form the certificate can carry**. The two admissible arithmetics are stated below. They attack the problem from opposite directions and are combined in section 3.

## 1. Layer ℚ: eliminate rounding

### 1.1 Representation

A rational is a pair `(p, q) ∈ ℤ × ℤ_{>0}` in lowest terms:

```text
Q := { (p, q) : q > 0,  gcd(|p|, q) = 1 }.
```

Invariants, which every constructor and every operation must re-establish:

- **I1 (positive denominator):** `q > 0`.
- **I2 (reduced):** `gcd(|p|, q) = 1`. Zero is represented uniquely as `(0, 1)`.
- **I3 (total normalization):** no value of the type may exist that violates I1 or I2, so normalization happens inside the constructor, not at use sites.

### 1.2 Operations

With `a = (p₁, q₁)` and `b = (p₂, q₂)`:

```text
a + b = norm(p₁q₂ + p₂q₁,  q₁q₂)
a − b = norm(p₁q₂ − p₂q₁,  q₁q₂)
a × b = norm(p₁p₂,          q₁q₂)
a ÷ b = norm(p₁q₂,          q₁p₂)          (b ≠ 0; sign moved to numerator by norm)
−a    = (−p₁, q₁)
```

Cross-cancellation before multiplication (`gcd(p₁, q₂)`, `gcd(p₂, q₁)`) and gcd-of-denominators before addition are permitted optimizations. They change intermediate operand size, never the result.

### 1.3 Laws

`(Q, +, ×)` is a field. Every operation is closed, and

- associativity, commutativity, and distributivity hold **exactly**;
- results are independent of evaluation order and of intermediate normalization strategy;
- equality is decidable by pair comparison after normalization: `a = b ⟺ p₁ = p₂ ∧ q₁ = q₂`, equivalently `p₁q₂ = p₂q₁`;
- order is decidable by cross multiplication: `a < b ⟺ p₁q₂ < p₂q₁` (valid because `q₁, q₂ > 0`);
- cancellation is lossless: `(x + y) − y = x` exactly, for all `x, y ∈ Q`.

Hence `1/10 + 2/10 = 3/10` holds, and any sequence of `+ − × ÷` returns the mathematically correct rational.

### 1.4 Costs

- **Size growth.** `bits(den(a + b)) ≤ bits(q₁) + bits(q₂)` and `bits(num(a × b)) ≤ bits(p₁) + bits(p₂)` before reduction. Under iteration the bound compounds: a Newton step or a Gaussian-elimination pivot can double operand size per step, so `k` steps cost up to `Θ(2^k)` bits in the worst case. Reduction by gcd mitigates but does not remove this; it is a cost to be measured, not assumed away.
- **Closure boundary.** Only operations algebraic over `ℚ` stay in `Q`. `√2`, `e`, `sin x`, and the Perron root `β` of an irreducible cubic are not elements of `Q`. To handle them exactly one extends the field (`ℚ(√d)`, `ℚ(β)` represented through a minimal polynomial with a sign oracle such as Sturm–Tarski), or one leaves exactness for enclosure (section 2).
- **Speed.** No hardware support. Expect two to three orders of magnitude slower than binary64 on the same operation count, more when operands grow.

### 1.5 Backend requirement

The laws of 1.3 hold only over unbounded `ℤ`. A fixed-width integer backend (`Int64`, `Int`) is admissible in exactly one of two modes:

- **Proof grade (unbounded):** arbitrary-precision `ℤ`. Cross multiplication in `=` and `<` is then safe.
- **Checked fixed width (fail closed):** every `+ − × neg abs` on the backend is overflow-checked, and overflow **raises or aborts**. It must never wrap, saturate, or widen silently. Under this mode a completed computation is exact; an aborted computation is *no result*, not a wrong result.

An unchecked fixed-width backend is **demo grade**: it may back examples and smoke tests, and it must be barred from every path that emits or accepts a certificate.

### 1.6 Best fit

Geometry predicates, exact linear algebra over `ℚ`, Parikh and incidence algebra, gcd and squarefree witnesses, canonical serialization, and every decision whose wrong sign or false equality would be catastrophic.

## 2. Layer I: keep rounding, bound it

### 2.1 Representation

An interval is a closed set `[a, b] = { x ∈ ℝ : a ≤ x ≤ b }` with endpoints in an endpoint set `E`:

```text
I_E := { [a, b] : a, b ∈ E,  a ≤ b }.
```

Two endpoint sets are relevant.

- **`E = F` with directed rounding.** Lower endpoints are computed rounding toward `−∞`, upper endpoints toward `+∞`. Every result contains the true result. Requires rounding-mode control on the hardware; fast.
- **`E = Q` (rational endpoints).** Endpoint arithmetic is exact (section 1), so no rounding mode is needed and the enclosures are the tightest the formulas allow. This is the mode both repositories use; `E = F` is stated for completeness and is **not** admitted in certificate paths.

Invariant **J1:** `a ≤ b` at construction. Reversed endpoints must raise, not swap.

### 2.2 Operations

```text
[a,b] + [c,d] = [a+c, b+d]
[a,b] − [c,d] = [a−d, b−c]
[a,b] × [c,d] = [min S, max S],   S = {ac, ad, bc, bd}
1/[c,d]       = [1/d, 1/c]           only if 0 ∉ [c,d]; otherwise raise
[a,b] ÷ [c,d] = [a,b] × (1/[c,d])
[a,b]²        = [0, max(a², b²)]     if 0 ∈ [a,b];  else [a,b] × [a,b]
```

Under `E = F` each endpoint formula is evaluated with the outward rounding stated in 2.1; under `E = Q` it is evaluated exactly.

### 2.3 The inclusion theorem

For every operation `∘` above and every `x ∈ X`, `y ∈ Y` in `I_E`,

```text
x ∘ y ∈ X ∘ Y.
```

By induction, for any expression `f` built from `+ − × ÷` and constants, the **natural interval extension** `f_I` satisfies `f(x) ∈ f_I(X)` whenever `x ∈ X`. This is the layer's central theorem, and it is the whole point: rounding error becomes a **certified width** `b − a` rather than an unobservable `δ`. Transcendental and algebraic functions outside `ℚ` are admitted here through any enclosure `g_I` with `g(x) ∈ g_I(X)`, for example a rational bracket of a Perron root obtained by exact sign changes at rational points. What it does **not** say is how far the enclosure and the point drift apart under iteration; section 2.5 bounds that.

### 2.4 Decision semantics

An interval answers a sign question with three values, never two:

```text
sign_I([a,b]) = +1  if a > 0
              = −1  if b < 0
              =  0  otherwise   (meaning UNKNOWN, not "equals zero")
```

Consequently:

- `X ∩ Y = ∅` proves `x ≠ y`; overlap proves nothing.
- `0 ∉ f_I(X)` proves `f` has no zero in `X`; `0 ∈ f_I(X)` proves nothing.
- `f_I(X) ⊂ int(X)` (strict inclusion) is the hypothesis of contraction-type uniqueness theorems (Krawczyk, Brouwer); non-inclusion proves nothing.

An interval never returns equality, and `0` from `sign_I` must never be consumed as a mathematical zero.

### 2.5 Costs

- **Dependency problem.** Occurrences of the same variable are treated as independent. `X − X = [a−b, b−a] ≠ [0,0]` and `X × X ⊋ X²` when `0 ∈ X`. Only **subdistributivity** holds: `X(Y + Z) ⊆ XY + XZ`. Widths therefore inflate along long computations and through iterated maps (the wrapping effect). The natural extension of the same polynomial in Horner form and in expanded form gives different, both valid, enclosures; Horner is generally tighter and is the required form here.
- **Refinement.** The inflation is bounded per step, and that is what makes bisection a decision procedure rather than a hope. Suppose `rad(F(X)) ≤ K · rad(X)` for every enclosure confined to a region `R`, with `K ≥ 1` rational. Then while the iterates stay in `R`,

  ```text
  rad(F^n(X)) ≤ K^n · rad(X),   and   |w − f^n(x)| ≤ 2 K^n · rad(X)   for w ∈ F^n(X), x ∈ X
  ```

  both in the sup norm. So a certificate that holds at a point with margin `δ` holds on the whole enclosure once `rad(X) < δ / (2 K^n)`, which bisection reaches in `⌈log2(2 K^n · rad(X) / δ)⌉ levels`. `K` is the caller's, because it depends on the map; nothing else here does. `finite_exact/enclosure_width.mojo` computes each quantity exactly, and a consumer supplies `K`: for `z ↦ z² + c` on a box of coordinate bound `M` it is `6M` (`docs/enclosure-width-lemma.md` in `larsbx/finite-julia-set-research`).
- **Mitigations.** Centred forms and mean-value forms; affine or Taylor-model arithmetic, which tracks first-order correlations and cancels `X − X` exactly. Affine and Taylor models are out of scope for both repositories at present; bisection and Horner are in scope.
- **No exact answer.** The layer proves enclosure, never value. Equality is only ever refuted.

### 2.6 Best fit

Validated numerics, root isolation and exclusion, contraction witnesses for uniqueness, computer-assisted proofs (Hales' Kepler proof, Tucker's Lorenz attractor), branch-and-bound global optimization, and any "certified margin" statement.

## 3. Combining the layers

### 3.1 Rational endpoints

Take `E = Q` in section 2. The two layers then share one backend, the enclosure formulas are exact, and rounding-mode control disappears. The dependency problem (2.5) remains untouched: exact endpoints do not make `X − X` collapse to zero.

### 3.2 Filter-then-exact

For a predicate `P(x)` whose exact decision is expensive (an exact sign in `ℚ(β)`, an exact geometric orientation, an exact zero test on a large polynomial), define the two-stage procedure

```text
decide(x):
  s := sign_I(P_I(X))          # cheap enclosure with X ∋ x
  if s ≠ 0: return s           # interval-certified strict sign
  return sign_exact(P(x))      # exact oracle: ℚ, ℚ(β) with Sturm–Tarski, gcd witness, ...
```

**Soundness.** By 2.3 the strict interval sign, when it is nonzero, equals the exact sign. The filter can therefore never contradict the oracle, and the oracle is invoked exactly on the cases the filter cannot decide. This is the pattern of CGAL's filtered predicates and Shewchuk's adaptive-precision predicates: near-float cost on the common case, exact correctness on every case.

Two rules follow and are enforced (section 7):

- **R1.** The exact oracle is never bypassed on `s = 0`. An ambiguous interval is a *fallthrough*, not a *result*.
- **R2.** A result is labelled by which stage produced it (`interval_certified` versus exact fallback). Downstream code may count, report, or require interval certification, but must treat both labels as mathematically valid signs.

### 3.3 Exact-in-combinatorics, interval-in-geometry

Where a computation has a combinatorial skeleton (an automaton, a catalogue, a graph of states) and a geometric margin (a distance, a discriminant, a Perron-coordinate sign), the skeleton is built in `ℤ`/`ℚ` and the margins are certified by `I_Q` with exact fallback. The skeleton is never rebuilt from a floating summary of the geometry.

## 4. Decision table

| Question | Layer | Reason |
| --- | --- | --- |
| `x = y`? | ℚ only | I refutes equality but never proves it (2.4) |
| `x < y`, `x > 0`? | I with ℚ / ℚ(β) fallback (3.2) | strict interval sign is a proof; `0` falls through |
| `f(x) ∈ B`? | I | 2.3 gives a containment proof |
| `f` has no zero in `X`? | I (`0 ∉ f_I(X)`) | exclusion certificate |
| `f` has a unique zero in `X`? | I (contraction, strict inclusion) plus ℚ for the point evaluations | Krawczyk / Brouwer hypotheses |
| root bracket for `β ∉ ℚ`? | ℚ signs at rational points, bisection; box is `I_Q` | exact sign changes, enclosure output |
| gcd, squarefree, divisibility, rank | ℚ only | any rounding falsifies the witness |
| serialization / hashing of certificate data | ℚ (normalized form) | I1 to I3 make the encoding canonical |

## 5. Conformance criteria

A module implementing either layer is **conformant** when all of the following hold.

- **C1.** No floating-point type (`Float16`, `Float32`, `Float64`, `float`) appears in any code path that constructs, evaluates, or accepts certificate data. Floats are permitted only in explicitly quarantined demo files listed in the repository allowlist.
- **C2.** Rational construction normalizes (I1 to I3) and rejects `den = 0`.
- **C3.** Integer backend is unbounded, or checked fail-closed (1.5); an unchecked fixed-width backend is labelled demo grade in the binding table and in the module header.
- **C4.** Interval construction enforces J1 and interval reciprocal raises on `0 ∈ [c, d]`.
- **C5.** Sign queries on intervals are three-valued (2.4); no API converts `0` into "zero" or "false".
- **C6.** Every filter-then-exact site obeys R1 and R2.
- **C7.** The module header cites this specification by path.

The distinction between `Rat` (1.1) and a *checked* `Rat` is only C3; the algebra is the same.

## 6. Consumers and binding tables

A consumer of either package keeps a **binding table** in its own repository: one row per module that instantiates a layer, with the module path, its conformance class, and the criteria it currently fails. Classes:

| Class | Meaning |
| --- | --- |
| CONFORMS | meets C1 to C7 with an unbounded backend |
| CONFORMS-CHECKED | meets C1 to C7 with a checked fail-closed fixed-width backend (1.5) |
| DEMO | unchecked fixed-width backend; algebra conformant; barred from certificate acceptance |
| QUARANTINED | uses floating point; allowlisted; barred from every certificate path; scheduled for replacement |

The packages themselves are CONFORMS rows in every consumer: `finite_exact/bigint_z.mojo` (1.1 integer backend, unbounded), `finite_exact/rat_q.mojo` (1.1–1.3 ℚ), and `finite_exact/closed_q.mojo` (2.1–2.5 I_Q and rank-2 boxes; stable facade `finite_exact/closed_interval.mojo`). A consumer must not re-implement a layer beside the vendored package; a second rational or interval type in a consumer is a binding-table violation.

Known consumers and their binding tables:

| Consumer | Binding table | Vendored root |
| --- | --- | --- |
| `larsbx/interval_q` | `README.md` | `finite_exact/` at the repository root |
| `larsbx/finite_linear_algebra` | `README.md` | `finite_exact/` at the repository root |
| `larsbx/finite-mandlebrot-research` | `docs/exact-arithmetic-binding.md` | `src/finite_exact/` |
| `larsbx/pisot-substitution-conjecture-research` | `docs/exact-arithmetic-binding.md` | `mojo/finite_exact/`, `mojo/interval_q/` |
| `larsbx/finite-julia-set-research` | `docs/exact-arithmetic-binding.md` | `src/finite_exact/` |

Promotion of a DEMO row to CONFORMS requires that the consumer's certificate-acceptance gate, not this package, be satisfied; `Q.accepted()` says only that a value is a well-formed rational.

## 7. Hook: how a consumer enforces the specification

The specification is a hook, not a note. In this package:

1. **Law tests.** `tests/finite_exact/test_finite_exact.mojo` executes 1.3 (normalization, decidable equality, `1/10 + 2/10 = 3/10`, order-independence, lossless cancellation) and the sticky-rejection rule of the public boundary; `pixi run test-finite-exact`.
2. **Property probe.** `tests/finite_exact/property_probe.mojo` draws deterministic pseudo-random operands and prints canonical bytes of every `BigZ` and `Q` result; `tools/property_oracle.py` recomputes them with Python `int` and `fractions.Fraction`; `pixi run property`. A disagreement on any canonical byte fails the build. `larsbx/interval_q` runs the same oracle with the I layer appended.
3. **Public boundary.** `docs/exact-arithmetic-public-boundary.md` fixes the names, semantics, and encodings a consumer may rely on; a change there requires a matching change in this file and a passing probe.

In a consumer:

4. **Pinned consumption.** Consumers pin a commit of this repository, and `tools/provenance.py --check` verifies every imported file here against the blobs pinned in `audit/provenance.json` on every CI run (`audit/CONSOLIDATION_PROVENANCE.md`). A change to the arithmetic is made here, then the consumer moves its pin; a local patch in a consumer is a binding-table violation.
5. **Audit script and allowlist**, where the consumer has certificate paths: a lexical scan of the kernel scope for floating-point types and literals outside an allowlist, discovery of direct arithmetic consumers with a binding row required for each, and the C7 citation check. `larsbx/finite-mandlebrot-research`'s `tools/audit_exact_arithmetic.py` is the reference implementation.
6. **Policy pointers.** The consumer's README and implementation-policy file name this specification as the arithmetic policy.

## 8. Non-goals

- This specification does not select an arbitrary-precision integer library; that remains the backend handoff in each repository.
- It does not introduce affine or Taylor-model arithmetic.
- It does not claim that exact arithmetic proves any theorem. Exactness removes one class of error from a computation; the epistemic status of the computation is governed by each repository's verification-architecture and claim-status documents.

## References

- IEEE Std 754-2019, *IEEE Standard for Floating-Point Arithmetic*.
- R. E. Moore, R. B. Kearfott, M. J. Cloud, *Introduction to Interval Analysis*, SIAM 2009 (inclusion theorem, dependency problem, natural extension).
- W. Tucker, *Validated Numerics*, Princeton 2011.
- J. R. Shewchuk, *Adaptive Precision Floating-Point Arithmetic and Fast Robust Geometric Predicates*, Discrete Comput. Geom. 18 (1997) (filter-then-exact).
- CGAL Editorial Board, *CGAL User and Reference Manual*, "Exact Geometric Computation" and filtered kernels.
- T. C. Hales et al., *A formal proof of the Kepler conjecture*, Forum Math. Pi 5 (2017).
- W. Tucker, *A rigorous ODE solver and Smale's 14th problem*, Found. Comput. Math. 2 (2002).
- L. H. de Figueiredo, J. Stolfi, *Affine arithmetic: concepts and applications*, Numer. Algorithms 37 (2004).
