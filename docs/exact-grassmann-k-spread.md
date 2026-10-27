# Exact guarded k-plane spread over finite quadratic spaces (2026-10-26)

**Decision:** proceed with a narrow classical finite-math kernel. No new theorem or optimizer convergence claim. Implements exact basis-independent Grassmann `k`-plane spread for `k=1..4` over the authoritative `ExactField` quadratic layer, orthogonal to coherence rank `R` and tensor order `r`.

## Definition and guard

Let K be an odd-characteristic exact field, V=K^8 with split quadratic norm N and direct bilinear pairing B2/2 already implemented by `projective_limits.gram_geometry`. Let U and W be ordered k-tuples of vectors with nondegenerate restricted forms. Define G_UU=(B2(u_i,u_j)/2), G_WW and mixed G_UW analogously. Then

```text
s_k(U,W) = 1 - det(G_UW)^2 / (det(G_UU)*det(G_WW))
guard: det(G_UU) != 0 && det(G_WW) != 0
polynomial: det(G_UU)*det(G_WW)*(1-s_k) = det(G_UW)^2
```

No division by zero; no order, square roots, SVD, real principal angles or limits. Char 2 refuses. A basis change U→UA, W→WB for invertible k-by-k A,B multiplies the numerator/denominator by the same `det(A)^2det(B)^2`, proving basis invariance. For k=1, this is the familiar projective spread. **Caveat:** the scalar invariant is not a metric and is not injective on ordered pairs of planes. Determinant-zero mixed Gram can give spread 1 despite the planes not being orthogonal in the strong sense; this is not a universal angle formula.

## Algorithms

`kernel/projective_limits/grassmann_k_spread.mojo` provides `det_small` (exact Leibniz enumeration, max 4x4), `gram_block8`, `k_plane_spread8`, and `guarded_k_plane_spread8`. All field operations import `ExactField`; no new finite-field arithmetic or matrix library is introduced. Complexity O(k! k + k² dim(V)) field ops, with k≤4 by deliberate bounded compile/run contract. Inputs with invalid shape, rejected field values, degenerate Gram determinant, char2, or zero denominator are rejected.

## Independent acceptance

`tests/projective_limits/test_grassmann_k_spread.mojo` runs on the pinned Mojo/Max exact RT lane and checks F3/F5/F7 k=1 equivalence to `spread8`, rank-three same-plane and nontrivial distinct-plane examples, two-sided basis changes (including permutations), guard membership/refusal, degenerate/repeated frames, rank-four basis changes, and invalid k.

The distinct rank-three example uses U=(a,b,c), W=(a+d,b,c) for mutually orthogonal norm-one a,b,c,d. Exact Gram diagonals (1,1,1) and (2,1,1) yield `s_3=1-1/2`. It works over F3/F5/F7. Tests count as evidence **only after hosted Mojo workflow success**.

## Research boundary

Coherence rank describes multi-event reorderings (P3...P6), while k describes the dimension of the extracted tensor-direction subspace; they must not be conflated. This kernel alone cannot extract an equivariant Grassmann frame from arbitrary tensors, declare state-dependent update maps commuting, or authorize permutohedral face attachment. Those require a separately declared tensor-extraction adapter, exact prefix-effect certificates and higher face boundary closure. No finite-field-to-floating-model error theorem exists.

## Relevant prior art

- N. J. Wildberger, *Rational Trigonometry in Higher Dimensions and a Diagonal Rule* (KoG 21, 2017), prior RT source gate: https://master.grad.hr/hdgg/kog_stranica/kog21/KoG21.pdf.
- Classical exterior-power determinant and Gram form under change of basis, standard linear algebra; this is a bounded re-expression over an exact finite field, not a new principal-angles result.

**Status:** research kernel under review; no claim-promotion to the proof ledger.
