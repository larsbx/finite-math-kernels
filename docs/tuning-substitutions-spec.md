# Tuning substitutions, directive prefixes, and column coincidence: specification

**Status:** specification of three modules of the `substitution_dynamics` package: `substitution_dynamics/tuning.mojo`, `substitution_dynamics/sadic.mojo`, and `substitution_dynamics/coincidence.mojo`. Written before the code, as the package's extraction audit requires for new kernels; the executable reference is `tools/tuning_reference.py`, and `tests/substitution_dynamics/test_tuning_reference.py` and `tests/substitution_dynamics/test_tuning.mojo` pin the same constants. The package states no theorem: it computes finite combinatorial facts about words and substitutions. Which classical statements those facts support is each consumer's imported theorem, recorded in the consumer's own ledger (section 5).

Origin: item R1 of the round-two cross-pollination audit (`docs/cross-pollination-round-two-2026-09-16.md` in `larsbx/NLAP-JT` and `larsbx/pisot-substitution-conjecture-research`). That audit observed that the residual class of the NLAP-JT program, the infinitely renormalizable parameters, is described combinatorially by iterated tuning, and that tuning acts on kneading sequences as a constant-length substitution, an object this package already models. This specification fixes the finite objects; it does not restate the audit's literature claims.

Terminology is field-recognizable (kneading sequence, tuning, star product, constant-length substitution, S-adic directive sequence, coincidence). No novel bridge term is introduced.

## 0. Scope and non-scope

In scope:

- tuning patterns over the two-letter itinerary alphabet `{0, 1}` and the substitution each defines;
- the star product of patterns and its identity with composition of substitutions;
- finite directive prefixes of substitutions over one alphabet, their composite, and the determined kneading prefix;
- the column-coincidence predicate for constant-length substitutions over any alphabet of at most 60 letters.

Out of scope, by design:

- external angles, itineraries of the doubling map, Hubbard trees, and every other object of the quadratic family (consumer side, NLAP-JT);
- the height of a constant-length substitution and the spectral conclusion of Dekking's theorem (consumer's imported theorem; section 3.4);
- infinite directive sequences, S-adic limits, primitivity or recognizability of S-adic systems;
- any claim about fibres, local connectivity, renormalization, or pure discrete spectrum.

## 1. Tuning patterns

### 1.1 Objects

A **tuning pattern** is a pair `(A', eps)` with `A'` a non-empty word over `{0, 1}` and `eps` in `{0, 1}` (the *twist*). Its **period** is `p = |A'| + 1`.

Boundary: `TuningPattern.checked(prefix, twist)` rejects an empty prefix and any letter outside `{0, 1}`. The plain constructor performs no validation and exists for callers that already validated; the package's own kernels use it only on values they built.

### 1.2 The substitution of a pattern

```text
tau_{A',eps}(s) = A' . (s xor eps),     s in {0, 1}.
```

`tau` is a substitution on `{0, 1}` of constant length `p`. Both images share the prefix `A'` and differ exactly in their last letter. `TuningPattern.substitution()` returns it as a `Substitution` of size 2.

### 1.3 The twist: parity (real convention) and continuation (general)

Two twist rules are shipped. Both are definitions of this package; what either has to do with tuning is a consumer citation (section 5).

**Parity twist (DGP).**

```text
dgp_twist(A') = (number of 1 in A') mod 2.
```

`TuningPattern.dgp(prefix)` constructs the pattern with this twist. With the convention `0 = L`, `1 = R` for the itinerary of a real quadratic map, the period-2 centre has `A' = R`, so `dgp([1])` is `([1], 1)` and its substitution is `0 -> 11`, `1 -> 10`: the period-doubling substitution, whose fixed point beginning with `1` is `RLRRRLRL...`. This is the star product of Derrida, Gervois, and Pomeau for **real** unimodal kneading sequences and is not the general rule: on the prefix `11` (the kneading prefix of the rabbit angles `1/7`, `2/7` in the 0/1 convention of section 5) the parity twist is `0`, while tuning sends `1` to `110`, not `111`.

**Continuation twist (general).** Write `n = |A'| + 1` and index `A'` from 1. Let

```text
rho(m) = min { k in (m, n-1] : A'_k != A'_(k-m) }      (undefined when no such k exists),
S      = the last defined term of  1, rho(1), rho(rho(1)), ...
continuation_twist(A') = A'_(n-S).
```

`TuningPattern.continuation(prefix)` constructs the pattern with this twist, so that `tau(1) = A' . (1 - A'_(n-S))`.

*Characterization.* Of the two `n`-periodic continuations `A' . b` (`b` in `{0, 1}`), exactly one has `n` in its internal address `1 -> rho(1) -> rho(rho(1)) -> ...` (the `rho` function taken over the periodic sequence), namely `b = 1 - A'_(n-S)`; `tau(1)` is that continuation. Proof: the internal-address entries below `n` are decided by `A'` alone, and `S` is the largest of them; `n` is an entry iff `rho(S) = n`, i.e. iff `A'_k = A'_(k-S)` for `S < k < n` (automatic, since otherwise `rho(S) < n` would be a larger entry below `n`) and `b != A'_(n-S)`. The reference tests replay this characterization against a brute-force internal address for every prefix of length at most 10.

*Identity (continuation closure), bounded.* `continuation_twist(A * B) = continuation_twist(A') xor continuation_twist(B')` when `A`, `B` carry the continuation twist; checked exhaustively for `|A'| <= 6`, `|B'| <= 5` and replayed by the tests for `|A'| <= 5`, `|B'| <= 4`. It is recorded as a bounded check, not proved here.

The two rules agree on `1`, `10`, `100`, `101` and on every real kneading prefix the consumer binding has checked (section 5), and disagree on `11`. A consumer describing centres that are not real must use `continuation`.

### 1.4 The star product

```text
star_product((A', eps_A), (B', eps_B)) = (tau_{A',eps_A}(B') . A',  eps_A xor eps_B).
```

The prefix has length `p_A p_B - 1`, so the product has period `p_A p_B`.

**Identity (composition).** For all patterns `A`, `B`, whatever their twists,

```text
tuning_substitution(A * B) = compose(tuning_substitution(A), tuning_substitution(B)),
```

where `compose(outer, inner)(s) = outer(inner(s))`. Proof: `tau_A(tau_B(s)) = tau_A(B' . (s xor eps_B)) = tau_A(B') . A' . ((s xor eps_B) xor eps_A)`, which is `tau_{A*B}(s)` by definition of the product's prefix and twist.

**Identity (DGP closure).** If `A` and `B` both carry the DGP twist, so does `A * B`. Write `ones(w)` for the number of `1` in `w`. The prefix `tau_A(B') . A'` consists of `|B'|` blocks `A' . (b_i xor eps_A)` followed by `A'`, so

```text
ones(tau_A(B') . A') = p_B ones(A') + sum_i (b_i xor eps_A)
                     = p_B ones(A') + ones(B') + |B'| eps_A   (mod 2)
                     = p_B eps_A + eps_B + (p_B - 1) eps_A     (mod 2)
                     = eps_A + eps_B                            (mod 2),
```

which is the product's twist. Both identities are exercised by randomized tests against the reference model.

**Identity (associativity).** `(A * B) * C = A * (B * C)`, a consequence of the composition identity and injectivity of `pattern -> substitution`; tested.

### 1.5 Kneading prefix of a directive prefix

For patterns `A_1, ..., A_n`, `kneading_prefix([A_1, ..., A_n])` is the prefix of `A_1 * ... * A_n`, of length `p_1 ... p_n - 1`. Every image of `tau_{A_1} o ... o tau_{A_n}` begins with it and has exactly one more letter (section 1.2 applied to the product), so it is the part of the composite's images that does not depend on the last letter. For the constant sequence `A_i = dgp([1])` the prefixes are `1`, `101`, `1011101`, ...: the finite stages of the period-doubling fixed point.

## 2. Directive prefixes

A **directive prefix** is a non-empty list `sigma_1, ..., sigma_n` of substitutions over one alphabet. `compose(outer, inner)` rejects substitutions of different alphabet sizes. `directive_composite` returns `sigma_1 o ... o sigma_n`; `apply_directive(subs, w)` returns `sigma_1(sigma_2(... sigma_n(w)))` without forming the composite. Both reject an empty list. Nothing in this section concerns limits: the package models finite prefixes only, and a consumer that reasons about an infinite directive sequence does so in its own ledger.

## 3. Column coincidence

### 3.1 Objects

A substitution `sigma` over `A = {0, ..., n-1}` has **constant length** `q` when every image has length `q`. `constant_length(sigma)` returns `q` and rejects any other substitution; `is_constant_length` is the Boolean form. For such `sigma`, `sigma^k` has constant length `q^k`, and column `j` of `sigma^k` is the map `a -> sigma^k(a)[j]`.

### 3.2 The predicate

`column_coincidence(sigma)` returns the least `k >= 0` for which some column of `sigma^k` is constant over `A`, together with the base-`q` digits `(c_1, ..., c_k)` of that column (the column chosen at each level), or reports that no such column exists.

Algorithm: breadth-first search over subsets of `A`, starting from `A` itself, with the `q` transitions `S -> { sigma(a)[c] : a in S }`. A singleton reached at depth `k` by the digits `c_1 ... c_k` is a constant column of `sigma^k` at column index `sum c_i q^{k-i}`. The state space has `2^n` elements, so the search is exact and complete; the alphabet is capped at 60 letters so that a subset fits a machine word. A one-letter alphabet has depth 0 and no digits.

Pinned values: every tuning substitution has depth 1 with digits `(0)`, because both images share their first letter; `0 -> 01, 1 -> 10` (Thue–Morse) has no coincidence; `0 -> 01, 1 -> 20, 2 -> 21` has depth 2 with digits `(0, 1)`.

### 3.3 What the predicate does not decide

The column-coincidence predicate ignores the **height** of `sigma` and the primitivity of `sigma`. The package computes neither. A consumer that wants the spectral conclusion of Dekking's theorem (a primitive, aperiodic substitution of constant length has pure discrete spectrum if and only if its pure base satisfies the coincidence condition, the pure base being the substitution of height one obtained from `sigma`) must import that theorem with its hypotheses checked, and must compute the height itself or obtain it from a future version of this package. Until then, a `found` witness is a finite fact about columns of powers of `sigma`, nothing more.

### 3.4 Non-claims

- `found == True` is not a statement about spectrum.
- `found == False` is not a statement about spectrum either; Thue–Morse is the standard example of a constant-length substitution without coincidence, and its spectral classification is the consumer's citation.
- Nothing here bears on substitutions that are not of constant length; the balanced-pair machinery of the package remains the tool for those.

## 4. Conformance tests

`pixi run test-tuning` runs the Mojo regressions; `pixi run test-python` runs the reference-model tests. A conforming implementation passes:

1. boundary rejections (empty prefix, letter outside `{0, 1}`, mixed alphabets in composition, empty directive, non-constant length, alphabet above 60);
2. the period-doubling values of section 1.3 and the star square of section 1.4 (`([1,0,1], 0)`; images `1010`, `1011`);
3. the composition identity and DGP closure on random patterns (reference model) and on fixed patterns (Mojo);
4. the kneading prefixes `1`, `101`, `1011101`, and length 31 at five levels;
5. the prefix property of section 1.5 for random directive prefixes;
6. the three pinned coincidence values of section 3.2 and the depth-0 one-letter case.

## 5. Consumer bindings

The package ships no policy; each consumer binds these kernels to its own claims.

| Consumer | Binding | Where it lives |
| --- | --- | --- |
| `larsbx/NLAP-JT` | the kneading form of tuning (`tau_{A', continuation}` is Douady–Hubbard tuning on 0/1 kneading sequences) as the scaffolded theorem tag `TuningKneadingSubstitution`; the residual-class carrier of the C1 program as a directive prefix of continuation patterns computed from exact periodic ray addresses, with the twist checked against exact angle tuning on the doubling, rabbit, airplane, and both period-4 components for every base angle of period at most 10. The parity twist is never used there: it holds on the real centres checked and fails on the rabbit | `docs/C1_theorem_tag_import_ledger.md`, `docs/C1_residual_directive_carrier.md`, `src/checked_ray_address.mojo` (NLAP-JT) |
| `larsbx/pisot-substitution-conjecture-research` | constant-length coincidence as the alphabet-generic special case beside the balanced-pair and overlap coincidence kernels; Dekking's theorem as an imported theorem where a constant-length specimen is used as a calibration | `docs/overlap-finiteness-and-coincidence-density-2026-09-13.md` (PSC) for the coincidence vocabulary it must stay consistent with |

Citation targets for consumers, not for this package: Douady and Hubbard, *Étude dynamique des polynômes complexes* (tuning); Derrida, Gervois, and Pomeau, the star product for unimodal kneading; Milnor, *Periodic orbits, external rays and the Mandelbrot set*; Dekking, *The spectrum of dynamical systems arising from substitutions of constant length* (1978).

## 6. Roadmap: the remaining round-two items that touch this repository

Recorded here so that the monorepo carries the contract for each; none is implemented by this specification.

| Item | Contract for this repository |
| --- | --- |
| R2 ledger generation | a `tools/` generator reading `proof_records` records and emitting a consumer's TLA+ ledger, claim-governance claims table, and documentation index; consumers supply only the policy predicate and templates |
| R4 one canonical encoding, one outcome vocabulary | `docs/canonical-encoding.md` becomes the shared codec; a documented map from external evidence classes (sprucegoose's five, crypto-composer's two) onto the six proof-record states |
| R5 obstruction extractor | a subset-graph sink-SCC extractor with retained countermodels, alphabet-generic, in `substitution_dynamics`, mirroring the PSC overlap extractor's fail-closed semantics |
| R7 degree-`n` Pisot screen, p-adic module | exact Sturm-sequence Pisot test for monic integer polynomials of any degree in `finite_linear_algebra`; a `(mantissa, shift)` dyadic record usable as a real interval endpoint and as a 2-adic ball datum in `finite_exact` |
| height of a constant-length substitution | section 3.3; needed before any consumer can bind Dekking's theorem without computing the height itself |
