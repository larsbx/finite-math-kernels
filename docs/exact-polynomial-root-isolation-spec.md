# Exact polynomials over Q, the Sturm chain, and largest-root isolation: specification

**Status:** specification of one new module of the `finite_linear_algebra` package, `finite_linear_algebra/qpoly.mojo`, which carries both the polynomial layer and the general-size characteristic polynomial. Written before the code, as the package's extraction audit requires for new kernels; the executable reference is `tools/qpoly_reference.py`, and `tests/finite_linear_algebra/test_qpoly_reference.py` and `tests/finite_linear_algebra/test_qpoly.mojo` pin the same constants. The package states no theorem: it computes finite facts about exact rational polynomials. Sturm's theorem is what turns one of those facts into a count of roots, and it is the consumer's import to name and gate (section 5).

Origin: item 2 of `docs/tiling-connections-2026-09-20.md` in `larsbx/finite-julia-set-research`, which needed the characteristic polynomial of a transition matrix of arbitrary size and an isolation of its largest real root, found both missing here, and recorded that the general-size characteristic polynomial it had written locally was in the wrong repository. `finite_linear_algebra/mat3.mojo` already carries the `3x3` closed form and the rational-root test for a monic cubic; this specification is the general case beside it, not a replacement for it.

Terminology is field-recognizable (characteristic polynomial, Euclidean division, greatest common divisor, squarefree part, Sturm chain, sign variation, root bound, isolating interval). No novel bridge term is introduced.

## 0. Scope and non-scope

In scope:

- polynomials in one variable with coefficients in `Q`, as normalized ascending coefficient lists;
- evaluation, derivative, the ring operations, Euclidean division, greatest common divisor, and the squarefree part;
- the Cauchy root bound;
- the Sturm chain and the sign-variation count at a rational point;
- an isolating bracket for the largest real root, carrying its own sign change;
- the characteristic polynomial of a square matrix over `Q`, in any dimension.

Out of scope, by design:

- complex roots, root multiplicity above the squarefree part, factorization, irreducibility, and minimal polynomials;
- any test for a root's quadrance, and therefore the Pisot condition itself (section 6);
- eigenvectors, the Perron-Frobenius theorem, and every spectral statement;
- floating point, and any approximation of a root by a single number.

## 1. Objects

### 1.1 Polynomials

A **polynomial** is `List[Q]` of coefficients in **ascending** degree: `p[k]` multiplies `x^k`. It is **normalized** when it is empty or its last coefficient is nonzero. The empty list is the zero polynomial.

- `degree(p)` is `len(p) - 1` for a normalized non-empty `p`, and `-1` for the zero polynomial.
- `normalize(p)` drops trailing zero coefficients. Every function below returns normalized output and accepts any input.

A **rejected** coefficient is an impossible state for a caller that seeded the polynomial from accepted values; `q_is_zero` of `finite_linear_algebra/scalar.mojo` aborts on one, and this module inherits that boundary rather than restating it.

### 1.2 Evaluation and derivative

```text
evaluate(p, x) = sum over k of p[k] x^k,     by Horner from the top
derivative(p)[k] = (k + 1) p[k + 1]
```

`evaluate` of the zero polynomial is `0`. `derivative` of a constant is the zero polynomial.

### 1.3 Ring operations

`add`, `sub`, `neg`, `scale(p, c)`, and `mul` are the usual ones, normalized on the way out. `mul` is the convolution; no fast multiplication is specified, because the degrees here are the sizes of transition matrices.

## 2. Euclidean division, gcd, and the squarefree part

### 2.1 Division

`divmod(a, b)` returns `(q, r)` with `a = q b + r` and `degree(r) < degree(b)`. The divisor must be nonzero; `divmod` by the zero polynomial **refuses**, returning a rejected result rather than a value. Over a field the quotient is exact at every step, so no pseudo-division and no content tracking is needed.

`remainder(a, b)` is the second component.

### 2.2 Greatest common divisor

`gcd(a, b)` is the Euclidean algorithm on `remainder`, returning the **monic** associate of the last nonzero remainder, and the zero polynomial when both inputs are zero. Monic normalization is what makes the result a function of the pair rather than of the order of the steps.

### 2.3 Squarefree part

```text
squarefree_part(p) = p / gcd(p, derivative(p))
```

for `p` of degree at least `1`, and `p` itself otherwise. The division is exact by construction; a nonzero remainder is an impossible state and the implementation refuses rather than discarding it.

The squarefree part has the same **set** of roots as `p`, each simple. Nothing here claims how many roots that is.

## 3. The Cauchy root bound

For a normalized `p` of degree `n >= 1` with leading coefficient `a_n`:

```text
root_bound(p) = 1 + max over k < n of |p[k]| / |a_n|
```

Every real root `r` of `p` satisfies `|r| < root_bound(p)`. This is elementary and is proved wherever it is used: if `|r| >= 1` then `|a_n| |r|^n <= (max |p[k]|) (|r|^n - 1)/(|r| - 1) < (max |p[k]|) |r|^n / (|r| - 1)`, so `|r| - 1 < max |p[k]| / |a_n|`.

The bound is a rational. No square root is taken and no modulus of a complex number is formed.

## 4. The Sturm chain and sign variations

### 4.1 The chain

For `s = squarefree_part(p)` of degree at least `1`:

```text
s_0 = s,    s_1 = derivative(s),    s_(k+1) = -remainder(s_(k-1), s_k)
```

until a zero remainder. `sturm_chain(p)` returns the list `[s_0, ..., s_m]`. Because `s` is squarefree, `s_m` is a nonzero constant.

### 4.2 Sign variations

`sign_variations(chain, x)` evaluates every member at the rational `x`, discards the zeros, and counts the adjacent pairs of opposite sign. It is an integer between `0` and `len(chain) - 1`.

```text
variation_difference(chain, a, b) = sign_variations(chain, a) - sign_variations(chain, b)
```

This is the finite fact the module computes. What it counts is section 5.

## 5. What the counting statement imports

**Sturm's theorem** states that for a squarefree `s` and rationals `a < b` with `s(a) != 0 != s(b)`, `variation_difference(sturm_chain(s), a, b)` is the number of distinct real roots of `s` in the open interval `(a, b)`.

That is a classical theorem. This package does **not** prove it, does not restate it as its own, and no function here is named as though it did: the module computes a difference of sign-variation counts, and a consumer that reads that difference as a root count is importing Sturm and must name and gate the import in its own ledger.

The one exception is deliberate and is section 6: an isolating bracket carries a **sign change**, and that a sign change brackets a root is the intermediate value theorem on a polynomial, which every consumer here already relies on.

## 6. Largest-root isolation

`largest_root_bracket(p, width, max_steps)` returns a record

```text
found   Bool     a bracket was produced
exact   Bool     the bracket is a single rational at which p vanishes
lo, hi  Q        the bracket, lo <= hi
```

The algorithm:

1. normalize `p`; if `degree(p) < 1`, return `found = False`;
2. `s = squarefree_part(p)`, `chain = sturm_chain(s)`, `B = root_bound(p)`;
3. if `variation_difference(chain, -B, B) == 0`, return `found = False`: no real root;
4. set `lo = -B`, `hi = B`, which satisfy `s(lo) != 0 != s(hi)`, and bisect with `m = (lo + hi) / 2`:
   - if `evaluate(s, m) == 0` then `m` is a root, and it is the largest one exactly when `variation_difference(chain, m, hi) == 0`; return the exact bracket `(m, m)` in that case and set `lo = m` otherwise;
   - else set `lo = m` when `variation_difference(chain, m, hi) >= 1`, and `hi = m` otherwise;
5. stop when `hi - lo <= width` **and** `variation_difference(chain, lo, hi) == 1`; if `max_steps` bisections pass without both, return `found = False`.

Step 4 maintains the invariant that `s` does not vanish at either endpoint and the largest real root lies in `(lo, hi)`: a positive variation difference on `(m, hi)` says a root is there, so the largest one is; a zero difference says none is, so the largest one is below `m`. That reading is Sturm's, per section 5.

**What the bracket carries by itself.** When `exact` is false, `evaluate(squarefree_part(p), lo)` and `evaluate(squarefree_part(p), hi)` are nonzero and of opposite sign. A consumer that declines the Sturm import still has a certified root of the squarefree part -- and therefore of `p`, which has the same roots -- in `(lo, hi)`; it simply may not conclude that the root is the largest one. The sign change is stated on the squarefree part rather than on `p` because a root of even multiplicity does not change the sign of `p`.

**What is not here.** Whether the isolated root is the Perron root of a nonnegative matrix is Perron-Frobenius, a further import. Whether it is a Pisot number needs the quadrance of the other roots of its *minimal* polynomial, which needs irreducibility and a root-location test by quadrance; neither is specified here and neither is implemented. A consumer must not read `largest_root_bracket` as a Pisot screen.

## 7. The characteristic polynomial, in any dimension

`charpoly(m)` takes a square `List[List[Q]]` and returns `det(x I - m)` as a normalized ascending coefficient list, by the Faddeev-LeVerrier recurrence

```text
M_0 = 0,    c_0 = 1
M_k = m M_(k-1) + c_(k-1) m,    c_k = -trace(M_k) / k,     k = 1 .. n
```

with the coefficients read out in descending degree, so the output is `[c_n, ..., c_1, c_0]` reversed into ascending order and is monic by construction. The division by `k` is why the recurrence is stated over `Q` even when the matrix is integral; the coefficients of an integer matrix are integers, and the test suite pins that.

The `3x3` closed form in `finite_linear_algebra/mat3.mojo` stays where it is and is the fast path for its dimension; `tests/finite_linear_algebra/test_qpoly.mojo` checks that the two agree, because two routines for one quantity that were never compared are one routine and one liability.

`charpoly` is a matrix operation and would sit naturally in `qlinalg`. It is in `qpoly` instead because `qlinalg` is an imported copy, tracked as one in `audit/provenance.json`, and editing it turns a copy into a modification; `tests/provenance/test_provenance.py` says so, and it said so about the first draft of this work. The polynomial module is authored here, returns the type `charpoly` produces, and is the right home for it.

## 8. Boundaries

- Every function is total on normalized input except `divmod` by the zero polynomial and `squarefree_part` of an input whose gcd division does not divide; both refuse rather than returning a value.
- `largest_root_bracket` refuses rather than returning a bracket it could not isolate. A capped bisection is inconclusive, never a claim that no root exists.
- No function returns a floating-point number, and no function names a root. A root is a bracket, and a bracket is two rationals.
- The module states no spectral fact. It does not know that its input came from a matrix, and `charpoly` does not know what its roots mean.
