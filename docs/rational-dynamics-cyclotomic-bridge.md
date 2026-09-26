# Rational dynamics and cyclotomic exactness bridge

**Status:** representation contract and extraction roadmap. R1 is
implemented in Mojo; C1, C2, Q1 and Q2 have an independent Python reference
(`tools/cyclotomic_reference.py`) and pinned vectors
(`fixtures/cyclotomic_germ_v1.json`). No executable authority is added by
this document, and the reference does not substitute for the canonical Mojo
stage.

Several consumers currently carry neighboring pieces of the same finite
arithmetic:

- reduced rational addresses and doubling orbits in `Q/Z`;
- tuning substitutions on finite address words;
- modular inverses and continued-fraction ancestry of reduced fractions;
- local quadratic dynamics at a root of unity;
- exact low-order jets and residue-like coefficient extraction.

The overlap should be extracted by mathematical object, not by domain name.

## 1. `rational_dynamics`

**R1 implemented on this branch.** The package owns exact arithmetic on a reduced rational class
`p/q`, with `q > 0` and `gcd(p,q)=1`. Its first contract is finite integer
combinatorics only:

```text
reduce(p,q)
double_mod_one(p,q)
mod_inverse(p,q)
signed_mod_inverse(p,q)
continued_fraction(p,q)
convergents(p,q)
farey_determinant(p,q,r,s) = p*s - q*r
farey_adjacent(...) <=> |farey_determinant| = 1
```

`signed_mod_inverse` returns the representative of `p^(-1) mod q` in
`(-q/2, q/2]`. It is an integer numerator together with the existing
denominator `q`; the package does not turn it into a measured angle.

The package owns no Mandelbrot, Julia, tuning, Ford-circle, or continued-
fraction interpretation. Consumers supply those meanings.

## 2. `cyclotomic_exact`

General roots of unity should not be manufactured with `exp`, `pi`, sine,
cosine, or floating-point coordinates. The proposed exact object is a
canonical quotient representation of

```text
Q[zeta_q] = Q[X] / (Phi_q(X))
```

with a reduced coefficient basis of degree `phi(q)`.

The minimum v1 surface is:

```text
cyclotomic(q, coefficients)
zeta(q)
add, sub, mul, neg
exact_equal
automorphism(a): zeta -> zeta^a     when gcd(a,q)=1
canonical_bytes
```

The constructor rejects a nonpositive conductor, a noncanonical coefficient
vector, or a coefficient that the exact rational layer rejects. Arithmetic
reduces modulo `Phi_q` after every operation.

Canonical serialization must include the conductor and the full reduced
coefficient vector. Equality is equality of canonical quotient
representatives, never equality of numerical approximations.

## 3. Quadratic-germ consumer

Once the cyclotomic layer exists, a separate domain-neutral finite kernel may
form

```text
g_lambda(w) = lambda*w + w^2
```

for an exact root of unity `lambda`, iterate it as a truncated polynomial,
and expose finite coefficient facts such as

```text
w - g_lambda^q(w) = w^(q+1) P(w).
```

Extraction of a coefficient of `1/P` is finite algebra when the constant
coefficient of `P` is invertible. The kernel may report that coefficient. It
does not call the coefficient a dynamical theorem; naming or interpreting it
belongs to the consumer.

## 4. Promotion order

The extraction should be staged:

1. **R1 — rational combinatorics: IMPLEMENTED.** Reduced nonnegative fractions over unbounded BigZ, explicit doubling modulo one, modular inverse, signed inverse, continued fractions, convergents, and Farey determinant are executable and tested.
2. **C1 — cyclotomic representation: REFERENCE.** Exact quotient arithmetic,
   field inverse by extended Euclid in `Q[X]`, and canonical bytes
   `Z(q) || Q(c_0) || ... || Q(c_{phi(q)-1})` in the encoding of
   `docs/canonical-encoding.md`. `Phi_q` is computed by exact division of
   `X^q - 1`, never imported from a computer-algebra system.
3. **C2 — Galois action: REFERENCE.** `zeta -> zeta^a` for `gcd(a,q)=1`;
   tested as a ring map, with `sigma_s . sigma_t = sigma_st`.
4. **Q1 — quadratic germ jets: REFERENCE.** Truncated composition of
   `g_lambda` over `Q[zeta_q]`, and the parabolic factor `P`, refused unless
   the residual vanishes to order `q+1`.
5. **Q2 — reciprocal-series coefficient: REFERENCE.** Refused when the
   constant coefficient is zero. The pinned vectors carry `[w^q] 1/P` for
   `q <= 8` and every unit `p`; the tests check the exact Galois
   equivariance `coefficient(zeta^p) = sigma_p(coefficient(zeta))`.
6. **consumer adapters:** parameter-plane, dynamical-plane, and arithmetic-
   correction projects interpret those finite outputs under their own
   theorem/evidence policies.

Each stage receives independent differential replay before a later stage may
depend on it. The first consumer replay is
`larsbx/mandelbrot-bulbs-and-ford-circles-research`, which checks the pinned
vectors against its own separately written `Q(zeta_q)` series code and its
ball-arithmetic oracle. A Mojo implementation of C1-Q2 is the remaining step;
until it lands, the stages are reference-only.

## 5. Authority boundary

This roadmap deliberately does **not**:

- identify a rational address with a geometric angle measurement;
- infer ray landing from address arithmetic;
- infer bulb size from a local coefficient;
- infer connectivity or local connectivity;
- make a numerical root-of-unity approximation certificate-bearing;
- move domain claim ownership into this repository.

The reusable kernel returns exact finite algebra. Consumers decide what those
facts establish.
