# Exact arithmetic public boundary

Status: package invariant for `finite_exact/bigint_z.mojo` and `finite_exact/rat_q.mojo`. It declares which names, semantics, and encodings consumers may rely on. It states no theorem and enables no certificate acceptance: arithmetic readiness is a property of this package, acceptance is decided by each consumer.

Specification of the arithmetic itself: `docs/rational-interval-arithmetic-spec.md`. Encodings: `docs/canonical-encoding.md`. The interval layer (`IQ`, `ComplexIQ`) has its own boundary document in `larsbx/interval_q`.

## 1. Public names

| Layer | Type | Constructors | Operations | Predicates | Encoding |
| --- | --- | --- | --- | --- | --- |
| Z | `BigZ` | `bigz_zero`, `bigz_from_i64` | `bigz_add`, `bigz_sub`, `bigz_mul`, `bigz_neg`, `bigz_abs`, `bigz_divmod`, `bigz_div_exact`, `bigz_gcd` | `bigz_eq`, `bigz_lt`, `bigz_is_canonical`, `BigZ.is_zero` | `bigz_canonical_bytes`, `canonical_bytes_equal` |
| Q | `Q` | `Q(n, d)`, `Q.zero`, `Q.one`, `Q.from_int`, `q_from_bigz`, `q_rejected` | `add`, `sub`, `mul`, `div`, `neg`, `square`, `q_abs`, `q_min`, `q_max` | `eq`, `lt`, `le`, `accepted` | `q_canonical_bytes` |

Result carriers `BigZDivModResult`, `BigZExactDivisionResult`, `BigZCanonicalBytes`, and `QCanonicalBytes` are public, as is the constant `BIGZ_BASE`. Every other name in the two modules, in particular `bigz_abs_*`, `bigz_abs_divmod_shift_subtract`, `q_normalize_bigz`, `q_cross_terms`, `QCrossTerms`, and the `*_smoke` and `demo_*` entry points, is internal and may change without notice.

## 2. Semantics that consumers may rely on

1. **Exactness.** Every operation on accepted inputs returns the mathematically exact result. There is no rounding, saturation, or wraparound at any magnitude.
2. **Canonical form.** An accepted `BigZ` has `sign` in `{-1, 0, 1}`, no leading zero limb, and every limb below `10^9`; zero has no limbs. An accepted `Q` has a canonical numerator, a canonical strictly positive denominator, and `gcd(|num|, den) = 1`.
3. **Values are constructor-produced.** `BigZ.sign` and `BigZ.limbs` are storage, not an interface: a value whose fields a consumer has assigned directly is outside this boundary, and the `BigZ` operations neither detect nor reject it (they assume canonical operands, as the specification's invariant I3 places normalization in constructors). The validating entry into the rational layer is `q_from_bigz`, which rejects a non-canonical `BigZ` through `bigz_is_canonical`; a consumer that assembles `BigZ` values by hand tests `bigz_is_canonical` before any other operation.
4. **Rejection is explicit and sticky.** Invalid construction (non-canonical limbs, zero denominator), division by zero, and non-exact division produce a carrier whose `rejected` flag is true. Every operation with a rejected operand returns a rejected carrier. `eq`, `lt`, and `le` return `False` on a rejected operand; a consumer must test `rejected` before reading a value. Nothing in the package raises or aborts.
5. **Division convention.** `bigz_divmod` truncates toward zero: the remainder has the sign of the dividend and `|remainder| < |divisor|`. `bigz_div_exact` rejects unless the remainder is zero. `bigz_gcd` is non-negative and `bigz_gcd(0, 0) = 0`.
6. **Order agrees with value.** `Q.lt` and `Q.le` decide the rational order exactly; `Q.eq` is structural equality of canonical forms and coincides with rational equality.
7. **Encodings are injective and total on accepted values.** `bigz_canonical_bytes` is `Z(sign_code, byte_len, big_endian_magnitude)` with sign codes `0, 1, 2` for zero, positive, negative, an unsigned 64-bit big-endian length, and a magnitude with no leading zero byte. `q_canonical_bytes` is the concatenation of the numerator and denominator encodings. Equal values have equal bytes and distinct values have distinct bytes. Rejected values have no encoding.

## 3. Semantics that consumers must not rely on

- Limb base, limb width, or the internal representation of `BigZ`.
- Intermediate magnitudes: `Q.add`, `Q.sub`, `Q.lt`, and `Q.le` scale by denominator cofactors and `Q.mul` cross-cancels, but the bound on intermediate growth is an implementation property, not a contract.
- The algorithm behind `bigz_divmod`. Long division is current; the retained shift-and-subtract routine exists only as a reference for the property probe.
- Cost. No operation promises a complexity class.
- Any relation between arithmetic acceptance and certificate acceptance. `Q.accepted()` says the value is a well-formed rational, nothing more.

## 4. Verification of the boundary

- `tests/finite_exact/test_finite_exact.mojo` executes the field laws, the sticky-rejection rule, `bigz_long_division_smoke`, and `q_cancellation_smoke` on every CI run (`pixi run test-finite-exact`).
- `tests/finite_exact/property_probe.mojo` draws deterministic pseudo-random operands and prints the canonical bytes of every result; `tools/property_oracle.py --layers zq` recomputes them with Python `int` and `fractions.Fraction` and compares token by token. Long division is checked in-process against the shift-and-subtract reference on every case, and every produced value is checked for canonical form (`pixi run property`).
- `tests/finite_exact/test_property_oracle.py` checks the oracle's own encoder against the documented byte examples and, when a `mojo` binary is present, runs the full comparison; `tests/finite_exact/test_public_boundary.py` checks the wiring above (`pixi run test`).

## 5. Stability promise

Names and semantics in sections 1 and 2 change only with a note in this file, a matching change in `docs/rational-interval-arithmetic-spec.md`, and a passing property probe. Names outside section 1 carry no promise. Consumers pin a commit of this repository (`audit/CONSOLIDATION_PROVENANCE.md`); a change here reaches a consumer only when it moves its pin.
