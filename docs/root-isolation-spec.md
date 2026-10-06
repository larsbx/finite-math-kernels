# Krawczyk root isolation on complex rational boxes: specification

**Status:** specification of the new package `root_isolation`: the Mojo kernel `kernel/root_isolation` (one complex variable, over `finite_exact/closed_q`) and the vendorable Python package `oracles/root_isolation_py` (one or two complex variables, over `oracles/closed_interval`; the suffix keeps the two out of one `vendored.toml` entry, as for `rational_dynamics_py`). Written before the code, as `qpoly` was (`docs/exact-polynomial-root-isolation-spec.md`). `tests/root_isolation/test_root_isolation.py` and `tests/root_isolation/test_root_isolation.mojo` pin the same cases, and `tests/root_isolation/test_krawczyk_twin.py` compares the two languages on a shared transcript. The package states no theorem: it computes a box and decides an inclusion. Section 4 is what turns an inclusion into a root, and it is the consumer's import to name and gate.

Origin: the deferred row "Krawczyk / interval Newton" of `docs/vendoring-candidates-2026-10-05.md`, which found three implementations in two languages with three box types and asked for one specification first. Section 8 is that inventory; every difference it records is a parameter of section 2 or a consumer-side policy, and none is a difference in what is certified.

**Modules.** Named, citable objects get their own module, re-exported from the package facade (`root_isolation` in Mojo, `root_isolation_py` in Python), with the same names in both languages:

| Module | Object | Source |
| --- | --- | --- |
| `krawczyk` | the Krawczyk operator (section 2) | R. Krawczyk, "Newton-Algorithmen zur Bestimmung von Nullstellen mit Fehlerschranken", *Computing* 4 (1969), 187-201 |
| `krawczyk_moore` | the Krawczyk-Moore existence and uniqueness test, `strictly_inside` (sections 3-4) | R. E. Moore, "A Test for Existence of Solutions to Nonlinear Systems", *SIAM J. Numer. Anal.* 14 (1977), 611-615; A. Neumaier, *Interval Methods for Systems of Equations*, Cambridge University Press (1990), ch. 5 |
| `boxes` | generic helpers: centre, preconditioners, exclusion, disjointness | none (inclusion isotonicity) |

Moore's interval Newton operator `N(X) = m - F(m) / F'(X)` (R. E. Moore, *Interval Analysis*, Prentice-Hall, 1966) is **not** implemented: no consumer uses it, and it needs an interval division that the Krawczyk form avoids. Certified roots of unity are not a separate certificate: they are `krawczyk_moore` on `X^q - 1` plus `disjoint` (section 3), and the seeds that place the boxes are the consumer's (bulbs `antipode.unity_boxes`), so no module is named for them.

Terminology is field-recognizable (Krawczyk operator, interval Newton, preconditioner, outward rounding, isolating box, exclusion). No novel bridge term is introduced.

## 0. Scope and non-scope

In scope:

- the Krawczyk operator for a holomorphic map `F : C^n -> C^n`, `n = 1` (both languages) and `n = 2` (Python), on products of closed rational rectangles;
- the strict-interior inclusion test that is the hypothesis of the Krawczyk-Moore theorem;
- the exclusion test `0 not in F(X)`;
- disjointness of two boxes, which is what makes several isolating boxes count distinct roots;
- two preconditioners: the exact inverse of a point derivative, and a rounded inverse of the midpoint of a derivative enclosure;
- caller-supplied rounding hooks, for consumers whose enclosures round outward.

Out of scope, by design:

- evaluating `F` or its derivative. The caller supplies the enclosures; the package never knows what map it is isolating a zero of, so a quadratic orbit, a polynomial and a two-variable system are the same call;
- seeds, Newton polishing, subdivision and search: how a box was found is untrusted and is not specified (section 7);
- the orbit-type logic consumers attach to an isolating box (same-box exclusions of forbidden index pairs, exact-type, enumeration completeness): those are `quadratic_orbit/collision` and consumer code;
- real intervals as the box type. A real zero of a real map is isolated by a complex box symmetric about the real axis;
- floating point anywhere, and any root named by a single number.

## 1. Objects

### 1.1 Boxes

A **box** in `C^n` is a vector `X = (X_1, ..., X_n)` of complex rectangles `X_j = [a_j, b_j] + i [c_j, d_j]` with exact rational endpoints: a `ComplexIQ` in either language, a `tuple[ComplexIQ, ...]` of length `n` in Python. It is the product set, so it is convex, closed and bounded. A box is **rejected** when any coordinate is; a rejected box poisons every operation it enters, exactly as in `closed_q`.

The **radius** `rad(X)` is the vector of the `2n` real half-widths. A box is **non-degenerate** when every one of them is positive.

### 1.2 Centre

`centre(X)` is the point (singleton box) at the exact midpoint of every real coordinate. It is computed exactly and never rounded: the proof in section 4 uses that `X - centre(X)` is symmetric about the origin.

### 1.3 Enclosures the caller supplies

- `Fm`, a box containing `F(m)` for the centre `m`;
- `J`, an `n x n` matrix of rectangles with `dF_i/dz_j (x) in J_ij` for **every** `x in X` (an enclosure of the complex Jacobian over the whole box, not at a point).

How they were computed (exactly, or with outward rounding) does not matter, only that they contain what they claim to.

### 1.4 Preconditioner

A **preconditioner** is an `n x n` matrix `C` of complex **points**. No hypothesis is placed on it: section 4 allows any `C` and proves that the inclusion forces it to be invertible. It is a parameter of acceptance, never of soundness. Two constructions are specified:

- `exact_inverse(J_m)`: `J_m` must be a matrix of points (the derivative at the centre with an exact parameter); the result is its exact inverse over `Q(i)`. A non-point entry or a zero determinant is **refused**.
- `midpoint_inverse(J_m, round)`: take the exact centre of every entry of `J_m`, form `d = round(1 / det)`, and return `d` for `n = 1`, and `round(d * adj)` entrywise for `n = 2`, where `adj` is the adjugate of the centre matrix and `round` acts on each real coordinate of a point. A zero determinant is **refused**. With `round` the identity this is the exact inverse of the centre matrix.

`n > 2` is refused by both constructions (no consumer needs it, and Cramer's rule is the wrong algorithm there).

### 1.5 Rounding hooks

`outward`, applied to each coordinate of the computed image, must return a box **containing** its argument. `round`, in `midpoint_inverse`, may return any rational at all. Both default to the identity, which is exact.

## 2. The operator

```text
K(X) = outward( m - C Fm + (I - C J)(X - m) ),     m = centre(X)
```

evaluated in rectangular complex interval arithmetic (`closed_q` / `closed_interval`), in this association: the matrix `C J` first, then `I - C J`, then its product with `X - m`; the vector `C Fm`; then `(m - C Fm) + ((I - C J)(X - m))`. Matrix-vector and matrix-matrix products sum their terms left to right. The association is part of the specification because rectangular complex multiplication is not associative as an enclosure, and consumers pin certificate bytes.

`K(X)` is rejected when any input is.

## 3. Certificates

| Name | Test | Proves, with section 4 | Imports |
| --- | --- | --- | --- |
| **isolation** | `K(X)` strictly inside `X`: for every coordinate, `lo(X) < lo(K)` and `hi(K) < hi(X)`, real and imaginary parts, both boxes accepted | `F` has exactly one zero in `X`, and it is simple | `KrawczykMooreUniqueness` (section 4) |
| **exclusion** | `Fx` accepted and some coordinate of `Fx` misses `0` in its real or imaginary part, for an enclosure `Fx` of `F(X)` | `F` has no zero in `X` | none (inclusion isotonicity) |
| **disjointness** | some real coordinate in which the two closed boxes are strictly separated | a zero in one is not a zero in the other | none |

Non-strict inclusion `K(X) subset X` is **not** a certificate of this package: it gives existence only when `C` is known to be invertible, which no consumer checks, and no consumer uses it. Failure of any test proves nothing: it is a statement about the enclosure, never about the zeros.

A family of `N` pairwise-disjoint isolating boxes for a polynomial of degree `N` accounts for every root, each simple: that needs only "a nonzero polynomial of degree `N` has at most `N` roots" (the factor theorem), and is what `bulbford.antipode.unity_boxes` uses for `X^q - 1`.

## 4. The theorem, and its exact hypotheses

**Theorem (Krawczyk-Moore; Krawczyk 1969, Moore 1977, in this form Neumaier 1990, ch. 5; module `krawczyk_moore`).** Let `D subset C^n` be open, `F : D -> C^n` holomorphic, and `X subset D` a box. Suppose

- (H1) `m = centre(X)`;
- (H2) `F(m) in Fm`;
- (H3) `dF_i/dz_j(x) in J_ij` for all `x in X` and all `i, j`;
- (H4) `C` is any complex point matrix;
- (H5) `K` is the box of section 2 computed from these, with any outward `outward`;
- (H6) **strict inclusion**: `K` lies in the interior of `X` in each of the `2n` real coordinates.

Then `C` is invertible, `F` has exactly one zero `x*` in `X`, and `DF(x*)` is invertible, so `x*` is a simple zero.

There is no hypothesis on `C`, on how `Fm` and `J` were computed beyond (H2)-(H3), or on the arithmetic beyond inclusion isotonicity. The proof is short and is given so that the hypotheses can be checked against it, not to replace the citation.

*Realification.* Identify `C^n` with `R^{2n}`. Multiplication by `a + ib` is the real matrix `[[a, -b], [b, a]]`, and the rectangular product `(A + iB)(U + iV) = (AU - BV) + i(AV + BU)` is **exactly** the real interval matrix-vector product with the matrix `[[A, -B], [B, A]]` whose four entries are taken independently. So the complex operator of section 2 is the real Krawczyk operator with the realified `C` and a real interval matrix that contains the realified `J`. Nothing is lost or gained in the translation; in particular the complex reading is an instance of the real theorem, not an analogy (Julia `docs/literature-gate-2026-09-20-krawczyk.md`, finding 2, which says "at least as tight"; it is equal).

*Mean value.* `X` is convex and each `J_ij` is a closed rectangle, hence convex. For `x, y in X`, `F(x) - F(y) = A_xy (x - y)` with `A_xy = integral_0^1 DF(y + t(x - y)) dt`, and every entry of `A_xy` lies in the corresponding `J_ij` because the integrand does.

*Invertibility.* Let `r = rad(X)`; (H6) forces `r > 0` in every coordinate. By (H1), `X - m = [-r, r]` exactly. For a real interval matrix `M`, `M [-r, r] = [-|M| r, |M| r]`, with `|M|` the entrywise magnitude. Radii add under interval addition and outward rounding only widens, so `rad(K) >= |M| r` for `M` the realified `I - C J`, and (H6) gives `rad(K) < r`. Hence `|M| r < r`, so in the weighted norm `||B||_r = max_k (|B| r)_k / r_k` every real matrix `B` with `|B| <= |M|` has `||B||_r < 1`. Each `I - C A` with `A` in `J` is such a `B`, so `C A` is invertible, and therefore so are `C` and every `A` in `J`.

*Uniqueness.* If `F(x) = F(y)` with `x, y in X`, then `A_xy (x - y) = 0` with `A_xy` invertible, so `x = y`.

*Existence.* `g(x) = x - C F(x)` is continuous, and for `x in X`, `g(x) = m - C F(m) + (I - C A_xm)(x - m)`, which lies in `K` by (H2), (H3) and inclusion isotonicity; `K subset X` by (H6). Brouwer's fixed-point theorem on the box `X` gives `x*` with `g(x*) = x*`, so `C F(x*) = 0` and `F(x*) = 0` because `C` is invertible.

*Simplicity.* `DF(x*)` lies in `J`, so it is invertible.

**Where each hypothesis is discharged.** (H1) by `centre`, which is exact. (H2)-(H3) by the caller, and only there: an enclosure that does not contain what it claims is the one way to break a certificate, and no check here can detect it. (H4) by construction. (H5) by section 2 and the `outward` contract. (H6) is the test of section 3.

**What a consumer imports.** The tag `KrawczykMooreUniqueness` (already named and ACCEPTED in `larsbx/finite-julia-set-research`, `docs/literature-gate-2026-09-20-krawczyk.md`), and through it Brouwer's fixed-point theorem. The package returns the hypothesis (H6); the conclusion is the import.

## 5. Exactness and rounding

Arithmetic is exact over `Q` throughout; `closed_q` never rounds. Rounding exists only through the hooks of 1.4-1.5, and the theorem covers both: a rounded preconditioner is still a point matrix (H4), and a rounded image still contains the exact one, so (H6) on the rounded image implies (H6) on the exact one. The consumers' policies are:

- exact: no rounding, `exact_inverse` (Julia, the Mojo kernel, Mandelbrot);
- fixed-point dyadic: `round(x) = floor(x 2^p) / 2^p` and `outward` to the `2^-p` grid, `midpoint_inverse` (bulbs, `p = 160` by default). This is an absolute grid, not the significant-bit rounding of `closed_interval.dyadic`; the hook is what lets both exist without a second interval type.

## 6. Refusals

Every refusal is a value, never an abort, and never evidence either way:

- a rejected box, centre, enclosure or preconditioner entry gives a rejected `K`, and the isolation test is false (Mojo: rejected, so a consumer can tell arithmetic rejection from a valid non-contraction);
- `exact_inverse` of a non-point entry, or either inverse of a singular centre matrix, is a rejected preconditioner;
- the exclusion test of a rejected enclosure is false (Mojo: rejected);
- disjointness of a rejected box is false.

Malformed shapes (a matrix that is not `n x n`, mismatched lengths, `n` not `1` or `2` for an inverse) are programming errors and raise `ValueError` in Python. Floats are refused with `TypeError` by `closed_interval` before they reach this package.

## 7. What is untrusted

Seeds, Newton steps, box radii, precision choices, subdivision depth and the order in which boxes are tried choose *which* box is tested, and are untrusted by design: a stored certificate is replayed from its box, enclosures and preconditioner policy alone. A wrong seed makes a test fail; it cannot make one pass.

## 8. Inventory of the implementations this replaces (2026-10-06)

| | Julia `reference/preperiodic.py` | FMK `quadratic_orbit/preperiodic.mojo`, now `quadratic_orbit/krawczyk_operator.mojo` (Julia's Mojo twin) | bulbs `kernel/bulbford/certify.py` | bulbs `kernel/bulbford/antipode.py` | Mandelbrot `certificates/krawczyk_witness.mojo` |
| --- | --- | --- | --- | --- | --- |
| box type | `closed_interval.ComplexBox` (vendored) | `finite_exact.ComplexIQ` (BigQ) | local `Box` of local `I` (Fraction) | local `Box`; `(Box, Box)` for `n = 2` | `finite_exact.ComplexIQ` (BigQ) |
| map | `R^c_{l,k}(z)` in the dynamical plane | same | `Q_{l+k}(c) - Q_l(c)` in the parameter plane | `X^q - 1` (`n = 1`); `(f_c^q(z) - z, (f_c^q)'(z) + 1)` in `(z, c)` (`n = 2`) | `P_{2,1}(C) = C(C + 2)`, one fixed box at `-2` |
| operator | section 2, `n = 1` | same | same | same, `n = 1` and `n = 2` | same, `m = -2`, `C = -1/2` hard-coded |
| centre | exact midpoint | exact midpoint | exact midpoint | exact midpoint | `-2`, the exact centre of its box |
| preconditioner | `exact_inverse`; refuses a non-point `R'(m)` (box parameter) or `R'(m) = 0` | same | `midpoint_inverse`, rounded down to `2^-160`; a zero derivative gives `C = 0` | same; `n = 2` by adjugate over rounded `1/det`, entries rounded down | exact constant, equal to `exact_inverse(P'(-2))` |
| outward rounding | none | none | every jet step and `K` to the `2^-prec` grid | every jet step, power and `K` | none |
| inclusion | strict interior, both coordinates | strict interior | strict interior | strict interior, every coordinate of both variables | strict interior; rejection kept apart from non-contraction |
| certifies | ISOLATED / EXCLUDED / UNKNOWN; exact type by exclusion of smaller types; completeness by degree count | the isolation and exclusion hypotheses | Krawczyk inclusion and same-box exclusions of forbidden pairs (exact type) | roots of unity (inclusion + pairwise disjointness), antipode (`n = 2` inclusion + exclusions) | the inclusion only, as one input to a joint certificate |
| refusal | `False`/`UNKNOWN`; rejected boxes poison | rejected boxes poison; `Bool` | `ValueError` on bad `(l, k, H)`; `INCONCLUSIVE` otherwise | `ValueError` when a root-of-unity box fails; `Blowup` maps to inclusion false | `BigQKrawczykResult(contraction, rejected)` |

**Verdict.** All five compute the operator of section 2 with an exact centre and decide strict-interior inclusion, and all read it as "exactly one zero, simple" -- the theorem of section 4, whose hypothesis (H4) admits every preconditioner above. The differences are arithmetic (exact vs fixed-point outward rounding, both covered by section 5), the preconditioner policy (1.4), and refusal conventions (section 6, which keeps each consumer's distinction). One specification covers them without changing any consumer's claim, and the zero-derivative difference is a non-difference: bulbs' `C = 0` makes `K = X`, which fails strict inclusion, the same verdict as a refusal.

**One home for the operator.** The generic, map-agnostic operator and test live here; `quadratic_orbit/krawczyk_operator` is their `z^2 + c` application (the residual `R^c_{l,k}`, its chain-rule derivative, the exact preconditioner) and keeps its names, re-exported from `quadratic_orbit/preperiodic`. The reverse would put a map-agnostic kernel, also used for `P_{2,1}` in Mandelbrot and for `X^q - 1` and a two-variable system in bulbs, inside the quadratic-family package.

**Not covered, and staying local.** Mandelbrot `certificates/checked_krawczyk_witness.mojo` is the same `P_{2,1}` operator over the checked `Int64` backend, a different arithmetic regime kept as a rejection-aware demonstration; Julia `reference/scaled.py` (separated-exponent boxes) is an orbit enclosure for itineraries, not a root certificate, and has one consumer; the orbit-type layers (forbidden pairs, exact type, completeness) are listed in section 0.

## 9. Boundaries

- No function evaluates a map, chooses a box, or returns a root. A root is a box, and a box is rationals.
- The isolation test returns the hypothesis (H6). Reading it as a zero is the import of section 4.
- A failed test is inconclusive, never a disproof, and a refusal is never read as either outcome.
- Python is the reference for `n = 2`. The Mojo kernel is canonical for `n = 1` and is compared with the Python package on a shared transcript.
