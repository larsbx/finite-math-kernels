# Mojo report: exact fields, rotors and the cyclotomic port

**Status:** report, 2026-10-05.

- **Scope:** branch `claude/pi-algebraic-rational-trig-1m75i8`, merged with
  `main` at `bf3f95c` (section 3.3).
- **Toolchain:** Mojo `1.1.0.dev2026090805` (`34562fa1`), pinned in `pixi.toml`.
- **Downstream:** the consumer side lives in
  `larsbx/mandelbrot-bulbs-and-ford-circles-research`.

## 1. Summary

The question was how to make π "algebraic" in the finite regime. It cannot
be: π is transcendental (Lindemann, 1882). It also never has to be computed.
π enters only as the size of a turn, and a turn can be kept exactly.

- **Over ℚ and 𝔽_p:** a turn is a point of the projective line, and the
  half-turn is the involution `J : t ↦ −1/t`.
- **Over ℚ(ζ_q):** a turn is a root of unity built from its polynomial `Φ_q`,
  never from `exp(2πi·)`.

The Mojo kernel now carries this in three layers.

| Commit | Layer | What it adds |
|---|---|---|
| `6de258d` | field-generic `projective_limits` | `ExactField`, a field as a structure over its `Element` type; `QField`, `FpField[p]`; every limit kernel over any exact field |
| `4ee9f09` | `projective_limits.rotor` | the rotation group of `x² + y² = 1` as the non-isotropic points of `P¹(K)`; turns, orders, spreads |
| `621202a`, then the merge | `kernel/finite_polynomial/cyclotomic_field.mojo` | `Q(ζ_q)` for the field-generic kernels: `Cyc[q]` with a compile-time conductor and operators, the Galois action, trace, norm, and `CyclotomicField[q]` as an `ExactField` |

The arithmetic of `Q(ζ_q)` itself is `main`'s `finite_polynomial`.
`621202a` first carried its own copy; the merge retired it (section 3.3).

`pixi run test` passes in full: every pre-existing gate, plus 40 new Mojo law
tests and 226 new reference vectors.

## 2. The mathematics the kernel now guarantees

The closure and half-turn results are in
`docs/projective-limits-over-exact-fields.md`.

1. **Closure.** `landing` returns `[p_k : q_k]`, built from polynomial
   coefficients in `K`. So for `f ∈ K(x)` and `a ∈ P¹(K)`,
   `lim_{x→a} f(x) ∈ P¹(K)`. No exact limit leaves its field. If one landed
   on π over a number field, π would be algebraic. The exclusion of π is
   therefore a structural property of the kernel, not a policy.
2. **The half-turn.** In the half-angle chart `t = tan(θ/2)`, rotations are
   the Möbius maps `R_a = [[1, a], [−a, 1]]`, and π becomes
   `J = R_∞ : t ↦ −1/t`. Its fixed points `t² = −1` are exactly the
   isotropic points.
3. **The rotor group.** `T(K) = P¹(K) ∖ {x² + y² = 0}`, with
   `a ⊕ b = R_a(b)`. Over `𝔽_p` (p odd) it is cyclic of order
   `N_p = p − (−1/p)`. A turn `a/n` is `g^{aN/n}` through a chosen generator.
   - The half-turn `1/2 ↦ ∞` is the same for every generator.
   - The quarter-turn `1/4 ↦ ±1` is the same up to sign.
4. **Niven's limit and how ℚ(ζ_q) passes it.** Over ℚ only the rotors
   `0, ∞, 1, −1` have finite order. Over `ℚ(ζ_q)` the rotor of the turn `1/q`
   has exact order `q`. This is tested for `q = 8, 12, 20`, using
   `i = ζ_q^{q/4}`.
5. **Rational trigonometry.**
   - The squared chordal metric is 4 × spread.
   - `rotor_spread = sin²θ`, and `s(nθ) = S_n(s(θ))` with the spread
     polynomials `S_n`; `S_n ∘ S_m = S_{nm}`.
   - The spread of the turn `1/q` is a root of `S_q`, and the eighth turn has
     spread exactly ½.

The finite fields `𝔽_p` admit exhaustive checks, so most of these laws are
checked on every point of `P¹(𝔽_7)` and `P¹(𝔽_13)`, not on samples.

## 3. Evidence

### 3.1 Tests and vectors

| Suite | Tests | Kind |
|---|---|---|
| `tests/projective_limits/test_projective_limits.mojo` | 18 | pre-existing laws over ℚ, unchanged |
| `tests/projective_limits/test_reference_vectors.mojo` | 466 vectors | pre-existing Python-reference replay, unchanged |
| `tests/projective_limits/test_field_generic.mojo` | 13 | exhaustive over `𝔽_7`, `𝔽_13`: normal form, `\|P¹\| = p+1`, `J`, rotation invariance of `χ²`, Wilson as a limit, landing where L'Hôpital fails |
| `tests/projective_limits/test_rotor.mojo` | 16 | group law = Möbius composition = circle multiplication, axioms, chart bijection, `N_p`, Lagrange and `φ(N)` generators, turn homomorphism, spreads |
| `tests/finite_polynomial/test_cyclotomic_field.mojo` | 11 | see the list below |
| `tests/finite_polynomial/test_cyclotomic_field_vectors.mojo` | 226 vectors | Python-reference replay of `conformance/cyclotomic_field_v1.txt` through `Cyc[q]` |

The 11 cyclotomic-field law tests check:

- the totient, the Möbius function and `Cyc[q].DEGREE`;
- `ζ` has exact order `q`;
- the field axioms through the operators, and sticky rejection;
- the Galois group law, with negative exponents;
- `Tr ζ_q = μ(q)` and `N(1 − ζ_q) = Φ_q(1)`, with the norm multiplicative;
- a landing over `ℚ(ζ_5)`;
- turns beyond Niven.

`main`'s own suites (`tests/finite_polynomial/`) cover `Φ_q`, reduction and
the germ.

**Independence of the replays.** Each kernel and its Python reference use
different algorithms, so agreement is evidence and not a transliteration.

| Quantity | Mojo kernel | Python reference |
|---|---|---|
| `Φ_q` | the divisor product identity, exact monic division over `BigZ` (`finite_polynomial.polynomial_z`) | recursive division of `X^q − 1` |
| inverses | exact RREF of the multiplication matrix (`finite_polynomial.cyclotomic_q`) | the extended Euclidean algorithm |
| limits | landing on the exceptional divisor | `gcd` cancellation and evaluation |

`tools/make_cyclotomic_field_vectors.py --check` runs in `pixi run test`, so
the fixture cannot drift from the reference.

### 3.3 Reconciliation with `main`

While this branch was in flight, `main` landed its own Mojo stage for
`Q(ζ_q)` and the germ, in `kernel/finite_polynomial`. Two implementations of
one field would be the worst outcome, so the merge made `main`'s canonical:

- **Removed.** `kernel/cyclotomic`, this branch's arithmetic, was deleted.
- **Kept.** What only this branch adds became
  `kernel/finite_polynomial/cyclotomic_field.mojo`: the compile-time-typed
  view `Cyc[q]` with operators, the `ExactField` adapter, trace and norm.
  The law tests and the reference replay moved with it, and now exercise
  `main`'s arithmetic.

**The replay found a bug on `main`.** `cyclotomic_canonical_bytes` prefixed
the conductor, the coefficient count and every coefficient with a `u64`
length. The documented contract of C1 is
`Z(q) ‖ Q(c_0) ‖ … ‖ Q(c_{φ(q)−1})` over `docs/canonical-encoding.md`, and
the reference and `conformance/cyclotomic_germ_v1.json` use it.

- **Why it went unnoticed.** `main`'s tests compared only byte strings with
  each other, never against pinned values.
- **The fix.** The merge restores the contract. Each `Z` and `Q` encoding is
  self-delimiting and the conductor fixes the coefficient count, so no prefix
  is needed.
- **What changes for consumers.** This is a behaviour change of an exported
  function: same signature, different bytes. A consumer that stored bytes
  from `main`'s version will see them change.

Every other line of the replay agreed with `main`'s arithmetic as it was:
`Φ_q`, products, inverses, the Galois action, and both germ quantities.

### 3.2 Mutation testing

Every new module was mutated by hand (one seeded fault per run) and the suite
re-run.

| Module | Mutants | Killed | Equivalent | Notes |
|---|---|---|---|---|
| `kernel/finite_exact/fp.mojo`, `kernel/finite_exact/field.mojo`, generic `line`/`limits` | 7 | 6 | 1 | the equivalent mutant drops a redundant `+ p` before `%`, which is already floored in Mojo |
| `kernel/projective_limits/rotor.mojo` | 12 | 12 | 0 | |
| `kernel/cyclotomic` as of `621202a`, retired at the merge (§3.3) | 11 | 10 | 1 | two killed **at compile time** (§4.1); the equivalent one is again floored `%` |

One survivor in the first round of the field work was a real gap: "a rejected
value counts as zero". The fix was a test that pins the `ExactField` contract
directly, not a change to the code.

## 4. Language features, and what they bought

### 4.1 Compile-time evaluation as verification

`Cyc[q]` declares `comptime DEGREE = euler_phi(q)` and asserts
`cyclotomic_degree(q) == DEGREE`. `cyclotomic_degree` is `main`'s, computed
with unbounded `BigZ` polynomial arithmetic, and the compiler evaluates it
for every conductor instantiated.

- **Mutants caught by the compiler.** At `621202a`, where `Φ_q` was this
  branch's own comptime table, two seeded faults in `Φ_q` (a wrong Möbius
  function, and `X^d + 1` in place of `X^d − 1`) failed **function
  instantiation** before any test ran.
- **Theorem-level checks.** The assertion `deg Φ_q = φ(q)` is a theorem about
  cyclotomic polynomials, and the compiler re-proves it numerically for every
  conductor instantiated.
- **Other compile-time contracts.**
  - `Fp[p]` asserts that `p` is prime and below `2^31`, so `Fp[8]` does not
    compile.
  - `turn_rotor[q]` in the tests asserts `4 ∣ q`, the condition for
    `i ∈ ℚ(ζ_q)`.

### 4.2 Associated types: a field as a structure

```mojo
trait ExactField:
    comptime Element: Copyable & Deinitable
    @staticmethod
    def add(a: Self.Element, b: Self.Element) -> Self.Element: ...
```

The field is kept apart from its elements, as in the mathematics. This was
also forced. `kernel/finite_exact/rat_q.mojo` must remain a byte-for-byte
copy of its upstream (`policy/provenance.json`), and Mojo has no retroactive
conformance (§5.3). The adaptor `QField` gives `Q` field structure without
editing it.

The cost is that `K` cannot be inferred from a `K.Element` argument, since
`Element` is not injective in `K`. Constructors therefore take `K = QField`
as a default, and `𝔽_p` call sites name the field:
`p1_affine[FpField[7]](Fp[7](3))`.

### 4.3 Other features used

| Feature | Use |
|---|---|
| default type parameters | the pre-existing ℚ API (`P1`, `Poly`, `p1_infinity()`, …) compiles unchanged on top of the generic kernel |
| operator overloading | `Cyc[q]` and `Fp[p]` have `+ − * / ==`; laws read as written: `a * (b + c) == a*b + a*c`, `(a*b).galois(s) == a.galois(s) * b.galois(s)` |
| `comptime for` | the vector replay dispatches a runtime conductor to the compile-time field `Cyc[q]` by an unrolled loop over `1 … 12` |
| `@fieldwise_init` | `CycSeries`, `CycCanonicalBytes` |
| `Writable` | a failing replay prints the field element itself |
| list comprehensions, `comptime for` over list literals | test tables (`comptime for q in [1, 6, 7, 8, 9, 10, 30]`) |
| floored `%` | canonical residues with one `%`; it also explains both equivalent mutants |

## 5. Language issues

Each issue has a self-contained reproduction, run with the pinned toolchain.

### 5.1 Bug: `use of uninitialized value` on a fully initialised struct

**Severity:** high. It rejects valid code, and the obvious workarounds also
fail. It occurred twice in real kernel tests.

```mojo
# Expected: prints True.   Actual: error: use of uninitialized value 's.x'
trait Field:
    comptime Element: Copyable & Deinitable


struct V(Copyable):
    var a: Int
    var b: Int

    def __init__(out self, a: Int):
        self.a = a
        self.b = 0

    def __eq__(self, other: Self) -> Bool:
        return self.a == other.a


struct VField(Field):
    comptime Element = V


struct S[K: Field](Copyable):
    var x: Self.K.Element

    def __init__(out self, x: Self.K.Element):
        self.x = x.copy()


def main():
    var v = V(0)
    var s = S[VField](V(0))
    print(s.x == v)
```

Evidence: `experiments/mojo_issues/uninit_associated_type/`.

- `repro.mojo` is the program above.
- `evidence.py` (`pixi run mojo-issue-evidence`) compiles and runs 24 cases
  with the pinned toolchain.
- `evidence.log` and `evidence.json` record the toolchain, platform, commit,
  exit codes and full diagnostics. All 24 cases agree with their declared
  outcome.
- `--check` exits 1 on any change, including the day the compiler is fixed.

| Variant | Result |
|---|---|
| as above | `error: use of uninitialized value 's.x'` |
| `S[T: Copyable & Deinitable]` with `x: Self.T` (no associated type) | compiles, `True` |
| `s.x == V(0)` (temporary, not a named local) | compiles, `True` |
| `v == s.x` (operands swapped) | same error |
| `var w = s.x.copy(); print(w == v)` | same error |
| `s.x.a == v.a` | compiles |
| `S` with a second field `flag` | same error, naming `s.flag` |
| `S` conforming to `Movable` too, or `Element: Copyable & Movable & Deinitable` | same error |
| `ImplicitlyCopyable` element | same error |

**The field counts interact.** An earlier version of this report said a
two-field element was necessary. That held only for an `S` with two fields.
The harness shows the dependence on both counts:

| element ↓ / fields of `S` → | 1 | 2 | 3 |
|---|---|---|---|
| `Int` | ✓ | ✓ | ✓ |
| `V`, 1 field | ✗ `s.x` | ✓ | ✓ |
| `V`, 2 fields | ✗ `s.x` | ✗ `s.f0` | ✓ |
| `V`, 3 fields | ✗ `s.x` | ✗ `s.f0` | ✗ `s.f1` |

In these minimal programs the error appears exactly when the element is a
struct with at least as many fields as `S`, and it always names the **last**
field of `S`. This is *consistent with* the definite-initialisation analysis
indexing the outer struct's fields by the element type's field indices. That
is a hypothesis, not a finding.

The two kernel witnesses in the harness show that a pure count rule is not
the whole story:

- `CirclePoint[FpField[13]]` has 3 fields, `Fp` has 2, and it still fails.
- The same comparison written with temporaries compiles.

Necessary in every case observed:

1. the field's type is a trait's associated type;
2. the field meets a named local in the call;
3. the element is a struct (never `Int`), with the field counts above.

**Workaround in the kernel.** Restructure the call site: compare against
temporaries, or split the conjunction into separate assertions. Or return the
whole struct: `turn_rotor` returns its `P1Over` rather than one of its fields.

### 5.2 `comptime` values of non-trivially-copyable type

```mojo
struct T[n: Int]:
    comptime SQUARES = table(Self.n)        # table returns List[Int]

    @staticmethod
    def third() -> Int:
        return Self.SQUARES[3]
        # error: cannot materialize comptime value of type 'List[Int]' to runtime
        #        because it is not 'ImplicitlyCopyable'
```

The fix it suggests, `materialize[Self.SQUARES]()`, works. The friction:

- Indexing and `len` on a comptime `List` each force a full runtime copy.
- `len(Self.PHI)` is rejected the same way; the compiler suggests evaluating
  the whole call at comptime, and the kernel writes
  `len(materialize[Self.PHI]())`.

A read-only comptime view, or comptime `InlineArray` materialisation of
known length, would make per-type constant tables such as `Φ_q` free at run
time.

### 5.3 No retroactive conformance

There is no way to declare that an existing type conforms to a new trait;
`extension T(Trait): …` is a parse error. For a monorepo that vendors exact
arithmetic byte-for-byte, this forces adaptor structures (§4.2).
Extension-style conformance would let `Q` be an `ExactField` directly.

### 5.4 Diagnostics

| Code | Diagnostic | What would help |
|---|---|---|
| `struct Pt[F: Field]: var x: Self.F` with `trait Field(Copyable, Movable)` | `field 'x' has non-'Deinitable' type 'F'` | suggest adding `Deinitable` to the trait or the bound; `Copyable` already implies `Movable` (that one *is* reported, as a warning) |
| `Box(xs[:2].copy())` where `Box` takes `List[Int]` | `no matching function in initialization`, listing the generated move constructor | name the argument type: the slice is `Span[Int, origin_of(xs)]`, which only an assignment reveals |
| `f(1 if k == 0 else 0)` with `f(n: Int64)` | `cannot be converted from 'Int' to 'Int64'` | the literal `f(1)` converts implicitly but the conditional expression does not; at least say why |

### 5.5 Toolchain

- **Compile-bound tests.** Build dominates the test loop. Measured at
  `15fb287`, before the merge:

  | File | Build | Run |
  |---|---|---|
  | `tests/finite_polynomial/test_cyclotomic_field.mojo` (then under `tests/cyclotomic/`, 14 tests) | 8.9 s | 0.32 s |
  | `tests/finite_polynomial/test_cyclotomic_field_vectors.mojo` (then under `tests/cyclotomic/`) | 10.6 s | 1.30 s |
  | `tests/projective_limits/test_rotor.mojo` | 4.0 s | 0.23 s |
  | `tests/projective_limits/test_projective_limits.mojo` | 3.7 s | 0.07 s |

  Mutation testing at this scale is dominated by recompilation.
- **Running outside pixi.** The bare `mojo` binary from the pixi environment
  fails with `unable to locate module 'std'`, and prints a Crashpad warning.
  `pixi run mojo` works.

## 6. Recommendations

1. **File §5.1 upstream** (`modular/modular`) with the reproduction and the
   variant table. It is the only issue that blocks valid code.
2. **Comptime tables.** Once §5.2 improves, `cyclotomic_q` could hold `Φ_q`
   per conductor as a comptime table instead of recomputing it per
   reduction.
3. **Wider fields.**
   - `FpField` over `BigZ` for primes `≥ 2^31`.
   - `CyclotomicField` conductors beyond the replayed `q ≤ 12`. The kernel
     accepts `q < 30030`; the law tests reach `q = 30`, and `Φ_q` is checked
     at `q = 105`.
4. **Consumers.**
   - The bulb–Ford repository replays the cyclotomic vectors from the Python
     reference today. It can replay `conformance/cyclotomic_field_v1.txt`
     against the canonical Mojo stage instead.
   - Any consumer that hashed `cyclotomic_canonical_bytes` output from `main`
     before this merge must re-derive it (§3.3).
