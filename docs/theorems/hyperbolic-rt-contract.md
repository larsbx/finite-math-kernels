# Exact eight-dimensional rational trigonometry: theorem and algorithm contracts

**Classification:** existing quadratic-form mathematics, elementary proofs and implementation contracts; **not a claim of novelty or independent formal proof review**.  
**Implementations:** `projective_limits.hyperbolic_rt`, `hyperbolic_rt_batch`, `hyperbolic_rt_max` (canonical Mojo) and a separate independent Python Gram-form oracle.  
**Evidence:** `conformance/hyperbolic_rt_v1.txt` (48 cases), the F3^8 norm-one shell enumeration, and Mojo/Python CI. Theorems and their tests have different authority.

## 1. Exact quadratic and projective contract

Let \(F\) be a field of characteristic different from 2. A quadratic form
\(N:V\to F\) satisfies \(N(cx)=c^2N(x)\) and has \(F\)-bilinear doubled
polarization \(B_2(x,y)=N(x+y)-N(x)-N(y)\).

**Proposition 1 (projective spread).** On the domain \(N(x)N(y)\ne0\),
\[
s([x],[y])=1-\frac{B_2(x,y)^2}{4N(x)N(y)}
\]
depends only on the projective rays. It is uniquely characterized on this domain by
\[
4N(x)N(y)(1-s)=B_2(x,y)^2.
\]
**Proof:** replacing \(x,y\) by \(cx,dy\), \(c,d\in F^\times\), multiplies
both numerator and denominator by \(c^2d^2\). On the guarded domain the
denominator is invertible, so the equation uniquely determines \(s\).
Without the guard the polynomial equation is not an equivalent definition. □

**Proposition 2 (orthogonal reflection).** For \(N(a)\ne0\), define
\[
r_a(x)=x-\frac{B_2(x,a)}{N(a)}a.
\]
Then \(r_a\) is a linear isometry, fixes the \(B_2\)-orthogonal hyperplane
of \(a\), and maps \(a\) to \(-a\).

**Proof:** with \(t=B_2(x,a)/N(a)\), expand
\(N(x-ta)=N(x)+t^2N(a)-tB_2(x,a)=N(x)\).
Also \(B_2(a,a)=2N(a)\); the remaining assertions follow. □

**Proposition 3 (at most two reflections).** If
\(N(u)=N(v)=c\ne0\), then the following explicitly guarded map sends \(u\)
to \(v\):
\[
g=\begin{cases}
r_{u-v},&N(u-v)\ne0,\\
r_v\circ r_{u+v},&N(u-v)=0.
\end{cases}
\]
**Proof:** in the first case
\(B_2(u,u-v)=N(u-v)\) and \(r_{u-v}(u)=v\).
In the second case,
\(N(u+v)+N(u-v)=4c\), so \(N(u+v)=4c\ne0\).
Also \(B_2(u,u+v)=N(u+v)\), hence
\(r_{u+v}(u)=-v\) and \(r_v(-v)=v\).
Every denominator used is nonzero. □

This proof is independent of the choice of an eight-dimensional split model;
the implementation fixes a split basis solely to provide exact coordinates.

## 2. A closed-form finite norm-shell count

**Proposition 4 (hyperbolic 8D shell size).** Let \(q\) be odd and
\(N(u,v)=2u\cdot v\) on \(\mathbb F_q^4\oplus\mathbb F_q^4\). For any
\(c\in\mathbb F_q^\times\),
\[
\#\{x:N(x)=c\}=q^3(q^4-1).
\]
**Proof:** \(u=0\) cannot satisfy \(2u\cdot v=c\ne0\).
There are \(q^4-1\) nonzero \(u\). For fixed nonzero \(u\), the linear
functional \(v\mapsto u\cdot v\) is surjective, and each fiber has
\(q^{4-1}=q^3\) elements. Multiply the counts. □

Consequently the F3 and F5 exact cardinalities are **2160** and **78000**.
These serve as independent conformance targets for the MAX parallel census;
the closed-form argument is the mathematical justification, not enumeration.

## 3. One checked inversion for a batch

**Proposition 5 (Montgomery batch inversion).** Let
\(a_0,\ldots,a_{n-1}\in F^\times\). Put
\(p_0=1\) and \(p_{i+1}=p_i a_i\). Set
\(w_n=p_n^{-1}\) and for \(i=n-1,\ldots,0\) define
\[
b_i=p_iw_{i+1},\qquad w_i=w_{i+1}a_i.
\]
Then \(b_i=a_i^{-1}\) for every \(i\), with **one inversion** and
a linear number of multiplications.

**Proof:** by backward induction \(w_{i+1}=p_{i+1}^{-1}\).
Thus \(b_i=p_i(p_i a_i)^{-1}=a_i^{-1}\),
and \(w_i=w_{i+1}a_i=p_i^{-1}\), using commutativity of field
multiplication. □

For spread batches, rejected/null lanes are replaced by denominator \(1\)
*only in the internal prefix product* and are returned as rejected outputs.
Their non-null neighbors therefore share one safe inversion. This is an
operation-count reduction, not evidence of a measured MAX speedup.

## 4. MAX parallelization and finite exactness

`hyperbolic_rt_max.norm_one_count_max[p](workers)` enumerates \(p^8\)
vectors and evaluates their norm via the canonical `Fp[p]` package. The
consumer map is pure; the reducer is integer addition, hence associative and
independent of worker partition. The shared `parallel_fold.map_fold` code
uses the MAX thread pool. This allows deterministic multicore execution
without floating-point reduction-order effects.

Enumeration is refused if \(p^8>10^6\), or \(workers<1\).
An exhaustion cap is **a runtime domain**, not a proof that the shell is empty
or a theorem about arbitrary \(q\). Benchmarking has not been performed;
performance improvements cannot be claimed from parameter counts alone.

MAX tensors/GPU are **not** substituted for exact `Fp` arithmetic because
uncontrolled reduction widths, modular overflow or nonintegral floating
representations invalidate certificates. Any future GPU kernel must derive
bounds on every intermediate accumulation, maintain canonical residues and
supply an independent exact oracle.

## 5. Falsifiers and scope boundaries

- The ordinary triple-spread polynomial applies to planar (rank-two)
  configurations with all rays non-null, **not** arbitrary triples in 8D.
  Three mutually orthogonal non-null rays have pairwise spreads \((1,1,1)\),
  giving polynomial defect \(-1\), not zero.
- Scalar field rejection is sticky; projective spread and reflections refuse
  a null denominator. A finite-field spread has no canonical comparison
  \(\le\epsilon\) because no compatible field order exists.
- A finite-field function vanishing everywhere need not be the zero
  polynomial: \(t^p-t\) is a standard counterexample.
- These routines do not implement Cayley algebra multiplication and do not
  prove Artin, Moufang, Aschbacher classification, or higher-degree tensor laws.
- The projective `rotor` and spread-polynomial packages remain the reusable
  rank-two foundation; this 8D module extends quadratic contractions without
  forking those algorithms.

## 6. Exact evidence and reproducibility

- `tools/make_hyperbolic_rt_vectors.py --check` regenerates 48 independent
  fixed cases from `reference/hyperbolic_rt_reference.py`.
- `tests/projective_limits/test_hyperbolic_rt_vectors.mojo` replays the
  same fixture through canonical `ExactField` arithmetic.
- `test_hyperbolic_rt_batch.mojo` compares checked batch results against
  scalar spread calls with null and length-mismatch refusals.
- `test_hyperbolic_rt_max.mojo` checks serial/MAX-parallel agreement and
  independent F3/F5 shell cardinalities.

The literature for these elementary calculations is standard quadratic
form, finite geometry and batch-field arithmetic; any originality claim
requires a separate bounded prior-art check and human-reviewed evidence.

## 7. Downstream tensor-direction and training-route experiment (not a kernel feature)

The research prototype in [tensor-multiplication-research](https://github.com/larsbx/tensor-multiplication-research/blob/main/research/training-route-audit-experiment.md) uses exact rational quadrance, guarded projective spread, and exterior-rank Gram determinants to compare alternative **training update schedules**. Its mathematical direction adapter is parameterized: rank 1 uses an update displacement, while rank 2 uses recorded factor spans, with a separate check that the factors reconstruct the displacement.

**Ownership boundary:** the training-state graph, optimizer updates, probabilistic schedule semantics, direction-adapter selection, local diamond policy, certificate format, and higher-cell interpretation all belong to the research consumer. This library owns only reusable **field/ring arithmetic**, existing guarded RT operations, and future proven/accepted exterior Gram kernels. Its current `gram_geometry` and `hyperbolic_rt` functions are not by themselves an optimizer verifier.

The research prototype distinguishes an exact commuting diamond (`U_j(U_i(A))=U_i(U_j(A))`) from a **bounded local discrepancy**, even when both direction spreads pass. The latter is *not* a topological 2-cell, route equivalence proof, or certificate of LLM training correctness. The quadratic spread squares its pairing and cannot distinguish antiparallel directions without an additional orientation-sensitive policy.

Any subsequent Mojo addition must pass: (1) exact rational and finite-field domain contracts; (2) nonzero Gram/denominator guards; (3) factor reconstruction and rank checking; (4) independent Python/Mojo conformance vectors including noncommuting and null negative controls; and (5) field-correct threshold policy (ordered comparisons over `Q`, not `Fp`). Move no consumer-specific optimizer or probability logic into shared math kernels. A documented experiment is not evidence of a merged production Mojo implementation.
