# Source-state RT gates for Coxeter square and hexagon faces

**Scope:** exact finite-field **geometric admissibility only**, not a theorem that
training operators commute. This is a reusable mathematical kernel in
`kernel/projective_limits/coxeter_gate.mojo`, supplementing
`projective_limits.rt_route.certified_swap8` and the separate
ordered-partition permutohedral incidence kernel (PR #85). The
tensor-direction k-plane extension is tracked independently in PR #86.

## 1. Mathematical object

Fix a finite field `F_q` of odd characteristic and nondegenerate quadratic
space `(V,Q)`. For non-null `u,v`, use the guarded projective spread

`s([u],[v]) = 1 - B_2(u,v)^2/(4Q(u)Q(v))`.

Let `S={0,...,m-1}` label **fixed, declared** non-null directions `d_j`.
For an ordering `pi` and an adjacent position `r`, let `s_r` exchange
positions `r,r+1`. The geometric edge gate is

`Gate(pi,r) = 1{s([d_{pi[r]}],[d_{pi[r+1]}]) in A}`

for a declared acceptance set `A subset F_q`. No ordering, floating point,
square roots, or unguarded inverse is involved.

**Square:** for `r+1 < s`, check every edge of the two paths
`s_r s_s` and `s_s s_r` from the **actual source permutation** at each step.

**Hexagon:** for `r+2 < m`, check every edge of the two paths
`s_r s_{r+1} s_r` and `s_{r+1} s_r s_{r+1}` from each intermediate
source. The two endpoints agree by the **Coxeter** relation in the symmetric
group. These are cells of a permutation-ordering complex, not new generator
relations in the Artin braid group (where `s_r^2=1` is absent).

The boundary of a square / hexagon is the difference between its two paths.
Because both paths have the same initial and terminal permutation,
`partial_1(partial_2(face)) = 0`. This is an elementary cellular
boundary identity, independent of geometric gates.

## 2. Source-state check and negative controls

`coxeter_square_gate8` and `coxeter_hexagon_gate8` use
`gated_swap_path8`; each swap computes `swap_gate_at_source8` on the
current ordering, and then advances the ordering by `adjacent_swap`.
All permutation labels are range-checked and pairwise distinct. A rejected
or null vector never passes; invalid paths return a rejected empty list.

Tests exercise exact `F5` hexagon and `F7` square cases. They distinguish:

* all required boundary pairs admitted => geometric face exists;
* only one of the three pairs admitted => **hexagon rejected**;
* an adjacent (not far) pair of generators => **square rejected**;
* invalid/duplicate ordering or out-of-bounds position => rejected.

These examples are finite regressions, not a proof that arbitrary
tensor update operations preserve endpoints.

## 3. Critical distinction: formal coherence versus effect equality

The group equality `pi s_r s_{r+1} s_r = pi s_{r+1} s_r s_{r+1}`
is **not** equality of state-dependent tensor operators. In particular,
spread zero may mean opposite direction, and even identical direction rays
do not imply commutation of nonlinear updates.

For an **operational reroute certificate**, replay each swap at its actual
prefix state and require **whole-vector equality** of both resulting states
(e.g. `rt_route.certified_swap8` for its supported affine family).
The kernel herein reports only geometric gate admission. A caller must not
attach a computational-equivalence 2-cell solely because this gate returns
`True`.

The fixed direction adapter used here may be replaced by a consumer's
declared tensor ray/k-plane interface; changes to source-dependent directions
require per-prefix replay, not cached label-only gating.

## 4. Verification and scope

Run `pixi run test-projective-limits`, or specifically:

```sh
pixi run mojo run -I kernel tests/projective_limits/test_coxeter_gate.mojo
```

The Mojo toolchain is pinned in `pixi.toml`. Hosted CI must actually
execute before a passing Mojo claim can be made; adding these tests does not
establish that they compiled. See
`docs/rt-route-kernels-mojo.md` and
`docs/theorems/gram-minor-rt-contract.md` for upstream geometry contracts.

The implementation is deliberately **not** an LLM-training verifier, a
Selmer/BSD equivalence, a signed certificate parser, or a generalized
rank-R permutohedral incidence implementation.
