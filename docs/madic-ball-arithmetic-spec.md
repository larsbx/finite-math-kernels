# M-adic ball arithmetic: specification of the lattice-coset carrier

**Status:** specification of `finite_linear_algebra/madic_ball.mojo` and of its independent Python oracle `tools/madic_oracle.py`. Sections 0 to 5 are repository-independent and carry no theorem: the carrier removes one class of error from a computation and decides one membership question. Section 6 names the consumer and section 7 says how the specification is enforced.

This carrier exists because a consumer asked for a "shared real times 2-adic box kernel" and the obvious reading of that request is wrong. Section 3 is the reason, and it is the part of this document worth reading first.

Terminology is field-recognizable: lattice, coset, invariant factors, Smith normal form, determinantal divisor, conservative filter. No novel bridge term is introduced.

## 0. The problem being solved

Let `M` be an `n x n` integer matrix with `det M != 0`. Then

```text
Z^n  ⊇  M Z^n  ⊇  M^2 Z^n  ⊇  ...
```

is a descending filtration of finite index, with `[Z^n : M^k Z^n] = |det M|^k`. A
consumer that works modulo `M^k Z^n` needs three things and no more:

1. to say when two integer points agree modulo `M^k Z^n`;
2. to know what group `Z^n / M^k Z^n` is, not merely how large it is;
3. never to mistake "agree at this level" for "equal".

Point 3 is the one that costs certificates if it is got wrong, and point 2 is the
one that makes the natural shortcut unavailable.

## 1. Representation

An **`M`-adic ball of level `k`** is a coset

```text
v + M^k Z^n,      v ∈ Z^n,  k ≥ 0.
```

Its radius is the lattice `M^k Z^n`. The radius is **not a number**. There is no
exponent that names it, and section 3 shows that supplying one loses information
that the consumer needs.

Level `0` is the whole of `Z^n` in one coset, and the filtration is monotone: a
pair separated at level `k` is separated at every deeper level, because
`M^(k+1) Z^n ⊆ M^k Z^n`.

Inputs are machine integers, matching the `Mat3` convention of the consumers.
Every internal value is `Q` or `BigZ` from `finite_exact`, so no intermediate can
overflow: the entries of `M^k` grow like the spectral radius to the `k`, and a
64-bit ceiling inside a carrier whose purpose is exactness would be a defect and
not a bound.

## 2. The contract, which is the closed interval's transposed

`docs/rational-interval-arithmetic-spec.md` fixes the rule for closed rational
intervals: an interval that excludes zero certifies a strict sign, an interval
that contains zero is **unknown**, and unknown is never promoted to equality or
to certificate acceptance. This carrier inherits that rule verbatim, with the
lattice in place of the interval:

| Observation | Meaning |
| --- | --- |
| `a` and `b` lie in **different** cosets at level `k` | certified: `a != b` |
| `a` and `b` lie in the **same** coset at level `k` | unknown; refining `k` may still separate them |

Separation is therefore the only certificate this carrier issues. The
non-claim is pinned in code by `same_coset_means_equal`, which returns false, in
the same spirit as the interval layer's refusal to promote an unknown sign.

For an expanding `M` the intersection of every level is trivial, so equality is
decided only in the limit and never by any single level. A caller that needs
equality must obtain it elsewhere.

## 3. Why this is not a scalar p-adic ball

The natural shortcut is one scalar `Z_p` ball per rational prime, at a declared
precision `k`, radius `p^(-k)`. It does not model the quotient, and the failure
is not asymptotic or stylistic; it appears at the second level of the consumer's
own standing regression.

Take the determinant-two substitution `0 -> 1`, `1 -> 021`, `2 -> 001`, whose
incidence matrix is `M = [[0,1,2],[1,1,1],[0,1,0]]` with `det M = 2`. Its
invariant factors, level by level:

| `k` | `abs(det M^k)` | invariant factors | `Z^3 / M^k Z^3` | cyclic |
| --- | --- | --- | --- | --- |
| 0 | 1 | `(1, 1, 1)` | trivial | yes |
| 1 | 2 | `(1, 1, 2)` | `Z/2` | yes |
| 2 | 4 | `(1, 2, 2)` | `Z/2 x Z/2` | **no** |
| 3 | 8 | `(1, 2, 4)` | `Z/2 x Z/4` | **no** |
| 4 | 16 | `(1, 4, 4)` | `Z/4 x Z/4` | **no** |

A scalar `Z_2` ball at precision `k` is `Z / 2^k`, which is cyclic at every `k`.
At `k = 2` the two objects have the same order, four, and different groups. They
are therefore not the same object and cannot be checked against each other.

Two further observations, both of which the shortcut also fails to capture:

- The shape of the sequence changes with `k`. A single exponent `p^(-k)` has no
  room to record `(1,1,2)`, then `(1,2,2)`, then `(1,2,4)`, then `(1,4,4)`.
- Non-cyclicity is not automatic, so it cannot be assumed away either.
  `diag(2, 3)` has invariant factors `(1, 6)`: two elementary divisors that are
  coprime recombine into one cyclic factor. The carrier must report what the
  matrix actually gives.

For the adelic picture in full, the finite places are places of the number field
`Q(beta)` rather than of `Q`, so the factors are completions with their own
uniformizers and ramification indices. That layer is **deliberately not built
here**; flattening it to scalar `Q_p` would discard exactly the ramification
that distinguishes the non-unit branch from the unit one, and nothing yet needs
it. The gate that reached this conclusion is
`docs/padic-representation-literature-gate-2026-09-16.md` in the consumer
repository.

## 4. Operations

| Operation | Returns | Method |
| --- | --- | --- |
| `quotient_order(M, n, k)` | `abs(det M^k)` | elimination over `Q` |
| `quotient_invariants(M, n, k)` | invariant factors of `Z^n / M^k Z^n` | determinantal divisors |
| `contains(M, n, k, d)` | is `d ∈ M^k Z^n` | solve `M^k x = d` over `Q`, ask whether `x` is integral |
| `same_coset(M, n, k, a, b)` | agreement modulo `M^k Z^n` | `contains` on `a - b` |
| `separated(M, n, k, a, b)` | certified distinctness | negation of the above |

The invariant factors come from the determinantal divisors, `d_i = D_i / D_{i-1}`
with `D_i` the gcd of the `i x i` minors. That characterisation is classical and
terminates by construction. This is worth stating because the alternative does
not: the first draft of the Python oracle used a hand-rolled elimination sweep
and failed to terminate on `M^4` for the matrix above. Minor enumeration is
`C(n, s)^2` per size, which is why section 5 bounds the dimension.

## 5. Refusals

The carrier fails closed. Three inputs are refused rather than answered:

- **a singular `M`.** With `det M = 0` there is no filtration of finite index and
  no level to speak of, so `contains` aborts instead of returning a value that
  could be read as membership.
- **a dimension above `MAX_DIMENSION`.** Minor enumeration is exponential in the
  dimension; a larger one is refused rather than silently made slow.
- **a negative level.** The filtration is indexed by `k ≥ 0`.

A refusal is not a negative result. None of the three means "not a member".

## 6. Consumer bindings

| Consumer | Binding |
| --- | --- |
| `larsbx/pisot-substitution-conjecture-research` | `mojo/psc/finite_cokernel_address.mojo` computes `Z^3 / M^k Z^3` classes for the standing determinant-two regression by Cramer's-rule divisibility. That is an independent implementation of the membership question in section 4, so the two can be differentially tested where their domains meet. |

The consumer's own claim-status documents govern what any computation means
there. This specification carries no theorem and no claim about overlap
productivity, separation, or tiling.

## 7. Enforcement

- `pixi run test-madic` runs `tests/finite_linear_algebra/test_madic_ball.mojo`, which pins the table of section 3, the contract of section 2, and the refusals of section 5.
- `pixi run test-madic-oracle` runs `tests/finite_linear_algebra/test_madic_oracle.py`, which asserts the same pinned values against `tools/madic_oracle.py` and adds the enumeration properties: the number of distinct cosets equals `|det M^k|`, the lattice columns are members at their own level, and separation is monotone in the level.
- Both are in `pixi run test`, so CI runs them.

The oracle is written from the definitions in this document rather than
transliterated from the Mojo, so agreement between the two is evidence rather
than an echo. What is **not** implemented is the shared-transcript probe that
`tests/finite_exact/property_probe.mojo` uses against `tools/property_oracle.py`,
where the two languages exchange canonical bytes for the same generated cases.
That is the stronger form; this carrier has the weaker one, and this sentence
records the difference rather than letting the word "differential" carry more
weight than it earns here.
