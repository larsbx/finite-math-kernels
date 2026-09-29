# Projective limits over exact fields

`projective_limits` is written against `finite_exact.field.ExactField`, so the
same kernel computes limits over Q and over the prime fields F_p.

An `ExactField` is a field as a structure. It names an `Element` type and
supplies the operations on it, so a field is kept apart from its elements:

- `QField` has elements `Q`;
- `FpField[p]` has elements `Fp[p]`;
- `cyclotomic.field.CyclotomicField[q]` has elements `Cyc[q]`, which is
  Q(zeta_q).

`P1`, `Poly`, `RationalMap`, `Mobius`, `Monomial` and `Poly2` are the `QField`
instances of `P1Over`, `PolyOver`, `RationalMapOver`, `MobiusOver`,
`MonomialOver` and `Poly2Over`. Code written against the Q names is
unchanged.

Constructors that take bare elements default to `QField`, so over F_p name
the field explicitly, for example `p1_affine[FpField[7]](Fp[7](3))`.

## Closure

`landing` returns `[p_k : q_k]`, the first nonvanishing coefficient pair of
the local expansions. For `f` in K(x) and a point `a` of P^1(K), every
coefficient involved lies in K, so

    lim_{x -> a} f(x)  lies in  P^1(K).

No exact limit leaves the field it started in. This is why the kernel can
never produce a transcendental number such as pi. If some landing over a
number field K returned pi, then pi would lie in K and so be algebraic,
contradicting Lindemann's theorem (1882). Quantities involving pi are handled
instead by the representations below, which keep every computed value inside
an exact field.

## Rational trigonometry on P^1

Write a rotation by the angle theta in the half-angle chart t = tan(theta/2).
The rotation by a = tan(phi/2) is then the Moebius map

    R_a = [[1, a], [-a, 1]] : t -> (t + a) / (1 - a t),

and composing rotations is the group law t1 (+) t2 = (t1 + t2) / (1 - t1 t2).
The half-turn is the involution

    J = R_inf = [[0, 1], [-1, 0]] : t -> -1/t.

- **Fixed points of J.** Over any field J satisfies J^2 = 1 in PGL_2. Its
  fixed points t^2 = -1 are the isotropic points, where x^2 + y^2 vanishes.
  Q has none. F_p has none when p = 3 (mod 4) and two when p = 1 (mod 4).
- **Chordal quadrance.** `chordal_distance_squared` is 4 x spread in the sense
  of rational trigonometry: 4 (x0 y1 - x1 y0)^2 / ((x0^2 + y0^2)(x1^2 + y1^2)).
  It is invariant under every R_a, and it rejects at isotropic points.
- **Size of the circle.** Over F_p, P^1(F_p) minus the isotropic points is in
  bijection with the circle x^2 + y^2 = 1, which has p - (-1/p) points, where
  (-1/p) is the Legendre symbol.

`tests/projective_limits/test_field_generic.mojo` checks these laws
exhaustively over F_7 and F_13.

## Rotors

`projective_limits.rotor` implements this rotation group for any field of
characteristic other than 2. The rotor group T(K) is P^1(K) minus the
isotropic points.

| Name | Meaning |
|---|---|
| `rotor(a)` | R_a = [[y, x], [-x, y]] for a = [x:y] |
| `rotor_add(a, b)` | the group law a (+) b = R_a(b), a Moebius action, so infinity needs no special case |
| `rotor_identity` | the identity, 0 |
| `half_turn` | the half-turn, infinity |
| `rotor_neg` | the inverse, [x:y] -> [-x:y] |
| `circle_point`, `circle_rotor` | the chart to x^2 + y^2 = 1 and back |
| `rotor_spread` | sin^2 of the rotation angle, 4 x^2 y^2 / (x^2 + y^2)^2 |
| `spread_polynomial` | S_n, with S_{k+1} = 2 (1 - 2 s) S_k - S_{k-1} + 2 s |

**Laws checked** in `tests/projective_limits/test_rotor.mojo`, exhaustively
over F_7 and F_13:

- the group law equals composition of the maps R_a;
- it also equals multiplication of points on the circle, an independent
  method: (x1, y1)(x2, y2) = (x1 x2 - y1 y2, x1 y2 + x2 y1);
- the group axioms hold;
- the chart is a bijection onto the circle;
- s(n theta) = S_n(s(theta)), and S_n o S_m = S_{nm}.

**Turns over F_p.** T(F_p) is cyclic of order `rotor_group_order_fp(p)`
= p - (-1/p).

- `turn(g, N, a, n)` sends the turn a/n to g^(a N / n) when n divides N.
  It is a homomorphism from (1/N)Z/Z.
- Which rotor a turn becomes depends on the chosen generator g, just as
  e^(2 pi i/n) depends on the choice of a primitive root.
- Two turns do not depend on g. The half-turn 1/2 always goes to infinity,
  the unique involution. The quarter-turn 1/4 always goes to +1 or -1.
- `rotor_generator_fp` fixes a choice: the first generator among
  0, ..., p - 1, infinity.

**Over Q.** The rotors of finite order are 0, infinity, 1 and -1 (Niven's
theorem). The test checks this on rationals of small height as evidence, not
proof. So a turn a/n with n not in {1, 2, 4} needs a larger field: Q(zeta_n),
or F_p with n dividing N_p.

**Characteristic 2** is excluded because there 2 t / (1 + t^2) = 0 and the
chart does not cover the circle. `rotor_group_order_fp(2)` is 0.

## Characteristic p

Landing reads the lowest order of a Taylor shift and takes no derivatives, so
it stays correct in characteristic p. L'Hopital, by contrast, can fail there:
the k-th derivative carries a factor k!, which is 0 for k >= p.

Example over F_7: x^7 - 3 = (x - 3)^7, so (x^7 - 3)/(x - 3)^7 lands on 1 at
x = 3, while every derivative L'Hopital could use is 0.

Wilson's theorem is the limit of (x^p - x)/(x - a) at any a in F_p, which
lands on -1.

## Prime fields

`Fp[p]` fixes the modulus at compile time, so elements of different fields
do not type-check together. The modulus must be a prime below 2^31, which
keeps every product inside Int64; a composite modulus is a compile error.
Elements are canonical residues, and division by zero is a sticky rejection,
as in Q.

`kernel/finite_exact/rat_q.mojo` is a byte-for-byte copy of
`larsbx/finite_exact`, as `policy/provenance.json` requires. Keeping the
field apart from its elements is what lets `QField` adapt `Q` without editing
that copy.
