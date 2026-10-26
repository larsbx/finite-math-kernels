# Mojo-first exact RT route operators (2026-10-26)

**Authority:** shared mathematical kernel in `kernel/projective_limits/rt_route.mojo`; consumer `larsbx/novelty-lab` retains separate acceptance authority for finite P3–P6 experiments and JSON receipt replay. The classical local affine identity and guarded rank-two Gram construction do not constitute a new theorem or novel mathematical result.

## What moved into Mojo
The domain-neutral operators now use `ExactField`, `FpField[p]`, `List[K.Element]` and the established split hyperbolic 8-space (norm `2 sum x_i*x_{i+4}`). No second finite field arithmetic or geometric normalization is introduced.

| Mojo function | Mathematical meaning | Failure contract |
| --- | --- | --- |
| `affine_step8[K]` | `x +(1+g*x[probe])*offset + x[probe]*shear` | Bad probe, invalid coordinates/field scalars or null declared offset return rejected vector |
| `swap_residual8[K]` | `U_b(U_a(x))-U_a(U_b(x))` at exact prefix | Rejected inputs propagate |
| `swap_equal8[K]` | All eight residual coordinates exactly zero | Invalid inputs never pass |
| `guarded_spread8[K]` | Projectively invariant guarded RT spread in specified finite gate | Null rays or rejected elements fail closed |
| `gram2_spread8[K]` | `1-det(M12)^2/(det(M11)*det(M22))` | Degenerate planes/zero denominators reject |
| `guarded_gram2_spread8[K]` | Rank-two Gram spread in declared gate | Rejected or out-of-gate fail closed |
| `certified_swap8[K]` | Exact computational equality **and** ray or plane direction geometry at common prefix | Both conditions required; rank must be 1 or 2 |

This **reuses** `hyperbolic_rt.mojo` and `gram_geometry.mojo`. Scalar pairs are exact. Because the state space is an affine tensor proxy, intermediate state norms may be zero; only the observed directions are non-null.

## Conformance

`pixi run test-projective-limits` now executes `tests/projective_limits/test_rt_route.mojo`. It checks:
- Commuting translations versus state-dependent scalar gain (noncommuting despite spread=0).
- Nonzero but *isotropic* whole-vector residual is **not** computational equality.
- Guarded rank-two Grassmann basis changes, null/degenerate frame refusal and invalid probe refusal.
- F5 and F7 specialization using the canonical `FpField[p]` implementation.

A second Mojo program, `tests/projective_limits/test_rt_route_census.mojo`, exhaustively constructs all **720 six-event permutations** and replays their **1800 adjacent-swap contexts** at actual prefix states. It tests F5 frozen translations (1800 equal), scalar state coupling (1680 equal), a nonzero isotropic residual model (1680 equal with 120 nonzero-null residuals), and rank-two geometric gating on all 1800 frozen updates. This is a bounded independent Mojo differential check against the existing Python consumer experiment, **not** a signed receipt parser or P6 cellular homology port.

Mojo CI evidence must be taken from an actually run workflow. A test written in a PR does not by itself establish compilation or success.

## What explicitly remains outside upstream mathematical authority

The existing `novelty-lab` code provides bounded P3/P4/P5/P6 *consumer-specific* enumerations and combinatorial CW incidence, per-prefix route trace search, audit schema versions, canonical JSON serialization, SHA-256 digests, chunk hash-chain replays, terminal EOF sealing and literature/claim governance. Those are **not** silently claimed to have been ported to Mojo by this kernel PR. Real-model optimization, trusted interpreter binaries, signatures, trace provenance and a field-to-float transfer theorem also remain open.

Next consumer integration (a distinct PR) should use an immutable upstream Mojo revision and independent Python differential fixtures, without hand-modifying `novelty-lab/vendor/`. This respects the repository's vendoring and authority contracts.
