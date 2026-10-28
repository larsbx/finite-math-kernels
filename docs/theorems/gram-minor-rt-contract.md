# Exact Gram-minor and exterior-rank geometry for split eight-spaces

**Classification:** classical algebraic linear geometry; field-generic elementary
derivations and finite implementation contracts. **Not a novelty claim, or a
formal proof reviewed by an independent mathematician.**

**Executable:** `projective_limits.gram_geometry`, using the existing
`projective_limits.hyperbolic_rt` quadratic-space kernel and the estate's
`finite_exact.ExactField`. **Evidence:** `conformance/gram_geometry_v1.txt`,
18 independent F3/F5/F7 vectors, source generator and Mojo replay. The
standard planar rational-trigonometry theorem is imported from the existing RT
literature; this dossier proves its *guard construction*, not that theorem from
first principles.

## 1. The coordinate and Gram tensors are different certificates

Let \(V=F^8\) carry the split quadratic norm
\[
N(x)=2\sum_{i=0}^3x_ix_{i+4}
\]
over a field of characteristic not two. Write
\(\langle x,y\rangle=B_2(x,y)/2\). The implementation computes this
pairing directly by the eight-coordinate contraction
\[
\langle x,y\rangle=\sum_{i=0}^3(x_i y_{i+4}+x_{i+4}y_i).
\]
No division or square root is needed to compute any Gram entry.

For three vectors the Gram tensor is
\[
G=\begin{bmatrix}
N(x)&a&b\\
a&N(y)&c\\
b&c&N(z)
\end{bmatrix},
\quad a=\langle x,y\rangle,\ b=\langle x,z\rangle,\ c=\langle y,z\rangle.
\]
Its determinant is the exact polynomial
\[
D_3=N(x)N(y)N(z)+2abc-N(x)c^2-N(y)b^2-N(z)a^2.
\]

The polynomial \(D_3\) is defined on **every** triple, including null
directions. The normalized projective ratio
\[
d_3([x],[y],[z])=\frac{D_3}{N(x)N(y)N(z)}
\]
is defined only if **all three norms are nonzero**.

### Elementary statement: projective normalization

Under independent rescalings \(x\mapsto\lambda x\),
\(y\mapsto\mu y\), \(z\mapsto\nu z\), each Gram determinant term scales
by \(\lambda^2\mu^2\nu^2\); so does the denominator. Therefore \(d_3\)
is a projective invariant whenever the denominator is nonzero.

## 2. Exterior rank, not a Gram determinant, decides planarity

Let \(X\) be the \(8\times3\) matrix with columns \(x,y,z\).
For \(0\le i<j<k<8\), let \(M_{ijk}\) be the coordinate determinant of
rows \(i,j,k\):
\[
M_{ijk}=x_i(y_jz_k-y_kz_j)-y_i(x_jz_k-x_kz_j)
+z_i(x_jy_k-x_ky_j).
\]

**Elementary statement: faithful planarity guard.**
\[
\boxed{\dim\langle x,y,z\rangle\le2
\iff M_{ijk}=0\text{ for all }i<j<k.}
\]

**Proof:** every 3-minor is zero precisely when the column rank of \(X\)
is at most two, by the elementary minor characterization of matrix rank.
Equivalently \(x\wedge y\wedge z=0\) in \(\Lambda^3V\). This statement
holds for any field, irrespective of the quadratic form's Witt index. □

\(D_3=0\) is **only** a statement about degeneracy of the form restricted
to the span; it does not guarantee \(x\wedge y\wedge z=0\) in an
indefinite or split quadratic space.

### Explicit counterexample (non-null rays)

Let \(x=e_0+\tfrac12 f_0\), \(y=e_1+\tfrac12 f_1\),
\(t=e_2\) in the hyperbolic basis, and \(z=x+y+t\).

Then \(N(x)=N(y)=1\), \(N(z)=2\), all nonzero in odd
characteristic. The vectors are linearly independent because \(t\) supplies
a third basis direction. Yet
\[
\operatorname{Gram}(x,y,z)=
\begin{bmatrix}1&0&1\\0&1&1\\1&1&2\end{bmatrix}
\quad\Rightarrow\quad D_3=0.
\]

The exact `rank_le_two8` procedure checks all 56 coordinate 3-minors,
returning an accepted field indicator 1 or 0, or a **rejected** element for
malformed inputs. It never substitutes \(D_3=0\) for planarity.

## 3. A guarded planar triple-spread entry point

`planar_triple_spread_defect8(x,y,z)` rejects unless:

1. all three vectors are valid;
2. every one of the 56 coordinate 3-minors vanishes;
3. all three norms are nonzero.

Only on this domain does it compute the familiar triple-spread polynomial
defect from three exact projective spreads. The planar theorem implies that
this defect is zero; the kernel explicitly **rejects** nonplanar inputs rather
than claiming that the planar identity extends to arbitrary three rays.

This is a domain-restoration and safe-API contribution, not a new theorem.

## 4. Degenerate Cayley–Klein absolute intersections

For non-null \(x,y\) spanning a genuine 2-plane, the binary restricted norm
\(N(ax+by)\) has discriminant
\[
B_2(x,y)^2-4N(x)N(y)=-4D_2,
\quad D_2=N(x)N(y)-\langle x,y\rangle^2.
\]
If \(D_2=0\), the projective line is tangent to the absolute quadric over
the splitting field; its two reference roots coincide. An **ordinary**
cross-ratio with two distinct reference points is not defined, although
\(s([x],[y])\) is still a valid guarded Gram ratio.

Example: take \(y=x+e_2\) with \(N(x)=1\) and
\(\langle x,e_2\rangle=N(e_2)=0\). Then the two non-null rays
\([x],[y]\) are distinct, but \(D_2=0\).

**Consequence:** the Gram-ratio spread is primary; ordinary Cayley–Klein
cross-ratio reconstruction is an appropriately guarded secondary theorem.

## 5. Exactness and test scope

The `gram_geometry` functions reuse `ExactField` multiplication and
checked division, introduce **no new field implementation**, and perform no
floating-point computation. The matrix-rank test is a small bounded
polynomial loop of 56 minors; it does not use heuristic tolerance, a
noncanonical finite-field ordering or probabilistic search.

The dataset includes, for each p in 3,5,7: a planar triple, independent
orthogonal triple, Gram-null/nonplanar radical witness, tangent absolute
line, null-ray normalization refusal, and proportional triple.

The Python fixture generator is an independent oracle. Its success and
the Mojo replay establish implementation conformance on those cases, not an
unrestricted proof. Existing RT and Cayley results retain their imported
or independently reviewed statuses. Future Aschbacher / tensor-stabilizer /
spread-controlled complex use may consume these exact rank and Gram tools
without acquiring a new interpretation of them.


## 6. Unrestricted three-ray Gram defect (separate guarded operation)

The **planar** function above retains its coordinate-rank guard. The new
[three-ray Gram-defect contract](three-ray-gram-defect.md) records the
field-generic cleared-denominator identity
`(N(x)N(y)N(z))² * triple_defect =
  detGram3 * (4*<x,y>*<y,z>*<z,x> - detGram3)`
on the non-null domain. The associated `unrestricted_triple_spread_defect8`
and independent `gram_triple_spread_defect8` functions agree without a
planarity assumption, but **their shared value is not always zero**.
The contract includes a nonplanar, nonsingular-Gram *zero-defect*
example, so a vanishing triple-defect test must never replace the 56
coordinate 3-minors used by `rank_le_two8`.

Wildberger (2017), §“Cross matrices, cross and det-cross”, already
develops higher-rank normalized-trace cross/spread and determinant cross
(doi:10.31896/k.21.2). This prior art is explicit in the companion note;
no novelty claim follows from implementing these elementary identities.
