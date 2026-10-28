# Guarded three-ray Gram defect: beyond the planar triple-spread formula

**Status:** elementary polynomial identity / executable conformance contract, **not a novelty finding** or independently reviewed general proof.  
**Upstream authority:** \`kernel/projective_limits/gram_geometry.mojo\`; independent bounded oracle \`reference/gram_geometry_reference.py\`.  
**Field scope:** finite odd-characteristic fields with a well-defined \`ExactField\` implementation; the written polynomial argument works over any field of characteristic not two.

## 1. Known result and boundary

The classical triple-spread law holds for triples of non-null directions in a two-dimensional span. It is **not** a relation forced by any three non-null rays in a higher-dimensional nondegenerate quadratic space. In the current split eight-space, a mutually orthogonal non-null triple has all spreads equal to one, giving planar triple-spread defect \(-1\).

Prior art: N. J. Wildberger, *Rational Trigonometry in Higher Dimensions and a Diagonal Rule for 2-planes in Four-dimensional Space*, **KoG 21** (2017), 47–54, DOI [10.31896/k.21.2](https://doi.org/10.31896/k.21.2). **Theorems 4–5** give classical cross/triple-spread formulas in planar triangle geometry; its section **“Cross matrices, cross and det-cross”** already defines a higher-\(k\) cross matrix, normalized trace cross/spread, and determinant cross. In particular, a normalized determinant ratio for two \(k\)-planes **must not** be presented as an original higher-rank construction. Our earlier scalar determinant-based proposal corresponds to the **det-cross**, while Wildberger's higher-rank spread is defined from a **normalized trace**. In characteristic dividing \(k\), that normalized trace needs a different treatment; the det-cross remains guarded by Gram invertibility.

See the related existing [Gram-minor/exterior-rank contract](gram-minor-rt-contract.md), which correctly distinguishes a zero Gram determinant from coordinate rank at most two.

## 2. A field-generic algebraic identity

Let \((V,Q)\) have half-polarization \(\langle x,y\rangle=(Q(x+y)-Q(x)-Q(y))/2\). Choose non-null \(x,y,z\) and define
\[
A=Q(x),\quad B=Q(y),\quad C=Q(z),\qquad
u=\langle x,y\rangle,\quad v=\langle y,z\rangle,\quad w=\langle z,x\rangle.
\]
Write
\[
D=\det
\begin{pmatrix}
A&u&w\\ u&B&v\\ w&v&C
\end{pmatrix}
=ABC+2uvw-Av^2-Bw^2-Cu^2.
\]
For the pairwise spreads \(s_{xy},s_{yz},s_{zx}\), define
\[
T=(s_{xy}+s_{yz}+s_{zx})^2-
2(s_{xy}^2+s_{yz}^2+s_{zx}^2)-
4s_{xy}s_{yz}s_{zx}.
\]

**Proposition (unrestricted three-ray defect).** On the non-null guard \(ABC\ne0\),
\[
\boxed{(ABC)^2T=D(4uvw-D).}
\]

**Proof by exact polynomial expansion.** Set \(a=u^2/(AB)\), \(b=v^2/(BC)\), \(c=w^2/(CA)\), so the three spreads are \(1-a,1-b,1-c\). Direct expansion gives
\[
T=4abc-(a+b+c-1)^2.
\]
From the displayed Gram determinant,
\[
a+b+c-1=(2uvw-D)/(ABC),\qquad
abc=u^2v^2w^2/(ABC)^2.
\]
Substituting and clearing the guarded denominators produces
\[
(ABC)^2T=4u^2v^2w^2-(2uvw-D)^2=D(4uvw-D).\quad\square
\]

The polynomial numerator \((ABC)^2T-D(4uvw-D)\), after denominator clearing, is identically zero as an integer polynomial in \(A,B,C,u,v,w\). This is independent of finite-field enumerations. As a rational function, \(T\) is invariant under independent projective rescalings, and for semilinear similitudes is **Frobenius covariant**, not necessarily fixed as an element of \(F_q\).

This proposition is a direct elementary Gram identity, not a claimed new result of rational trigonometry.

## 3. Three distinct configurations

1. **Rank ≤ 2:** \(x\wedge y\wedge z=0\), hence \(D=0\), so \(T=0\). The planar triple-spread theorem is recovered.
2. **Independent but Gram-singular:** \(D=0\) can still occur when the restricted quadratic form has a radical; \(T=0\) then holds for a nonplanar triple. A zero Gram determinant is not a rank test.
3. **Independent and Gram-nonsingular with \(T=0\):** \(D=4uvw\ne0\) is possible. Therefore the *unrestricted* triple-spread polynomial being zero **does not characterize planarity**.

For (3), in the split hyperbolic basis \(e_i,f_i\) with \(Q(e_i)=Q(f_i)=0\), \(Q(e_i+f_i/2)=1\), choose
\[
x=e_0+f_0/2,\qquad y=x+e_1,\qquad z=-x+2f_1.
\]
Then \(Q(x)=Q(y)=Q(z)=1\), \(u=v=1\), \(w=-1\), \(D=-4\ne0\) in every odd characteristic, and all three spreads vanish. This is a **nonplanar zero-defect falsifier**, different from the orthogonal nonplanar triple with defect \(-1\).

## 4. Exact executable contract

The reusable Mojo APIs are:

- \`unrestricted_triple_spread_defect8\`: compute the polynomial \(T\) from three **guarded** spreads, **without** a planar-rank restriction.
- \`gram_triple_spread_defect8\`: independently compute \(D(4uvw-D)/(ABC)^2\), rejecting any malformed input or null norm.
- Existing \`planar_triple_spread_defect8\`: retain the stricter coordinate-rank-≤2 guard; **do not change its meaning**.

Both unrestricted APIs return rejected elements on a null input. The underlying Gram determinant stays defined on null triples; only the rational normalization is partial. The determinant-side and spread-side implementations are intentionally independent except for the shared exact norm/pairing arithmetic.

Evidence: \`tests/projective_limits/test_gram_geometry.mojo\` for F3/F5/F7, including the nonplanar zero-defect and orthogonal falsifiers; \`tests/projective_limits/test_gram_triple_defect_reference.py\` for independently calculated selected triples. A bounded finite test is evidence of **implementation conformance**, not the proof of the generic identity.

## 5. Boundaries and next use

This identity does not distinguish all three-ray projective orbits; \(T=0\) is not a geometric planarity certificate. It does not authorize operational route swaps, graph/homology cell attachment or neural-training equivalence. The identity can serve as an **exact audit invariant** for triples of declared non-null tensor directions, but semantic equivalence still needs complete state-dependent endpoint replay. An extension to more than three directions should use full Gram-minor or exterior algebra contracts rather than a speculative universal “higher triple-spread law”.

**Conformance command:** \`pixi run test-projective-limits\` and \`python -m pytest -q tests/projective_limits/test_gram_triple_defect_reference.py\`. These require actual successful execution before claiming a Mojo pass.
