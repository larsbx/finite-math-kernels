# Projective limits over exact fields

`projective_limits` is written against `finite_exact.field.ExactField`, so the
same kernel computes limits over Q and over the prime fields F_p.

An `ExactField` is a field as a structure. It names an `Element` type and
supplies the operations on it, so a field is kept apart from its elements:

- `QField` has elements `Q`;
- `FpField[p]` has elements `Fp[p]`.

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
