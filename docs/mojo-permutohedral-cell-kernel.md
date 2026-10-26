# Exact permutohedral face incidence in Mojo (2026-10-26)

**Authority:** shared bounded discrete CW face combinatorics, exported by `kernel/finite_graph/permutohedral_cells.mojo`. **Classical reference:** A. Postnikov, *Permutohedra, Associahedra, and Beyond* (2009), ordered-partition face poset; A. Hatcher, *Algebraic Topology* (2002), §2.2 cellular boundaries. These computations do not establish a novel topology result.

## Exact representation

A P_n ordered-partition face is encoded by an `n`-entry vector of consecutive block IDs. For example:

```
[0,0,1,1,2,3]  <=>  ((0,1),(2,3),(4),(5)) in P6
```

The kernel checks that the block IDs are contiguous and all blocks nonempty, enumerates **only immediate ordered block splits**, and derives the CW face dimension as `n - blocks`. Its integer oriented incidence uses:
1. twice the parent/child face barycenters in the permutohedron's standard coordinate arrangement;
2. the child-minus-parent outward vector as the first column;
3. one `e_j-e_root` per nonroot block coordinate as the remaining columns;
4. an exact integer Leibniz determinant with at most 120 terms.

The result is ±1 for a valid facet or 0 to reject a non-facet. The kernel checks `d_(k-1) d_k=0` directly by summing signed two-step incidences. There are no floating limits, orders on finite fields, square roots, unguarded inverses or interpolation.

## Quantitative bounded scope

Only `2 <= n <= 6` is exposed, with deterministic finite loops. The library provides face-vector counts `(n-d)! S(n,n-d)` and on-demand facet enumeration. The exact test pins P3/P4/P5/P6 vectors:

| Object | CW dimension | f-vector |
| --- | ---: | --- |
| P3 | 2 | 6, 6, 1 |
| P4 | 3 | 24, 36, 14, 1 |
| P5 | 4 | 120, 240, 150, 30, 1 |
| P6 | 5 | 720, 1800, 1560, 540, 62, 1 |

It checks d²=0 on the P6 top cell, a whole P5 facet, a square and a hexagon, plus a signed P5-to-P6 orientation cross-check. This is an **exact bounded implementation test**, not a mathematical proof for arbitrary rank R. The permutation dimension is `n-1`, whereas an n-additive-updates cube is dimension n.

## Integration boundary

This module is independent of projective RT and `novelty-lab` certificates: its oriented faces are **potential**, not automatically justified computational rewrites. The separate `rt_route.mojo` upstream module checks geometric admissibility **and** whole-vector local effect equality. A consumer must check complete certificate boundary coverage before attaching a face; neither a geometric gate nor a hash commitment alone is a semantic proof. The existing `novelty-lab` consumer owns its P6 audit protocol and historical ledger; porting those receipts and trust policies to Mojo remains separate.

**Test:** `pixi run test-finite-graph`, and the aggregate `pixi run test`. Report actual hosted results before merging; no test is claimed to have passed merely because it is added.
