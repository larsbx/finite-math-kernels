# rotor.mojo
#
# Rotations of the circle x^2 + y^2 = 1 over an exact field K of
# characteristic not 2, without angles. In the half-angle chart
# t = tan(theta/2) a rotation is a point of P^1(K):
#
#     rotor [x:y]  <->  circle point ((y^2 - x^2), 2 x y) / (x^2 + y^2)
#                  <->  Moebius map R = [[y, x], [-x, y]],
#
# the identity is 0, the half-turn is infinity (R_inf : t -> -1/t), and the
# group law is the Moebius action a (+) b = R_a(b), which for affine points is
# (a + b) / (1 - a b). The rotor group T(K) is P^1(K) minus the isotropic
# points x^2 + y^2 = 0, where R is singular and every operation rejects.
#
# Over F_p (p odd) T is cyclic of order N_p = p - (-1/p). A turn a/n is a
# rotor only through a chosen generator g, as g^(a N / n) for n | N; the
# half-turn 1/2 -> infinity is the same for every generator, and nothing
# here measures an angle or uses pi. The spread of a rotor is sin^2(theta),
# and s(n theta) = S_n(s(theta)) for the spread polynomials S_n.

from finite_exact.field import ExactField, QField
from finite_exact.fp import FpField
from projective_limits.line import (
    MobiusOver,
    P1Over,
    mobius,
    mobius_apply,
    p1,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_rejected,
)


def _norm[K: ExactField](a: P1Over[K]) -> K.Element:
    """x^2 + y^2 of the normal form [x:y]."""
    return K.add(K.mul(a.x, a.x), K.mul(a.y, a.y))


def is_rotor[K: ExactField](a: P1Over[K]) -> Bool:
    """a is an accepted, non-isotropic point of P^1(K)."""
    return a.accepted() and not K.is_zero(_norm(a))


def rotor_identity[K: ExactField = QField]() -> P1Over[K]:
    return p1_affine[K](K.zero())


def half_turn[K: ExactField = QField]() -> P1Over[K]:
    return p1_infinity[K]()


def rotor[K: ExactField](a: P1Over[K]) -> MobiusOver[K]:
    """R_a = [[y, x], [-x, y]] for a = [x:y]; singular, so rejected, when isotropic."""
    if not a.accepted():
        return mobius[K](K.rejected(), K.zero(), K.zero(), K.one())
    return mobius[K](a.y, a.x, K.neg(a.x), a.y)


def rotor_add[K: ExactField](a: P1Over[K], b: P1Over[K]) -> P1Over[K]:
    """a (+) b = R_a(b): the rotation a followed by b, or b followed by a."""
    if not is_rotor(a) or not is_rotor(b):
        return p1_rejected[K]()
    return mobius_apply(rotor(a), b)


def rotor_neg[K: ExactField](a: P1Over[K]) -> P1Over[K]:
    """The inverse rotation, [x:y] -> [-x:y]."""
    if not is_rotor(a):
        return p1_rejected[K]()
    return p1[K](K.neg(a.x), a.y)


def rotor_power[K: ExactField](a: P1Over[K], n: Int) -> P1Over[K]:
    """The n-fold sum a (+) ... (+) a for any integer n, by repeated doubling."""
    if not is_rotor(a):
        return p1_rejected[K]()
    if n < 0:
        return rotor_power(rotor_neg(a), -n)
    var out = rotor_identity[K]()
    var base = a.copy()
    var k = n
    while k > 0:
        if k % 2 == 1:
            out = rotor_add(out, base)
        base = rotor_add(base, base)
        k //= 2
    return out^


def rotor_order[K: ExactField](a: P1Over[K], bound: Int) -> Int:
    """The least n in [1, bound] with n a = 0, or 0 when there is none.

    Over F_p a bound of N_p is exhaustive (Lagrange); over Q a miss is
    inconclusive by itself, and Niven's theorem says only 0, inf, 1, -1 are
    torsion.
    """
    if not is_rotor(a):
        return 0
    var zero = rotor_identity[K]()
    var b = a.copy()
    for n in range(1, bound + 1):
        if p1_equal(b, zero):
            return n
        b = rotor_add(b, a)
    return 0


struct CirclePoint[K: ExactField](Copyable):
    var x: Self.K.Element
    var y: Self.K.Element
    var rejected: Bool

    def __init__(out self, x: Self.K.Element, y: Self.K.Element):
        self.x = x.copy()
        self.y = y.copy()
        self.rejected = not Self.K.accepted(x) or not Self.K.accepted(y)

    def accepted(self) -> Bool:
        return not self.rejected


def circle_point[K: ExactField](a: P1Over[K]) -> CirclePoint[K]:
    """The rotor [x:y] as ((y^2 - x^2), 2 x y) / (x^2 + y^2) on x^2 + y^2 = 1."""
    if not is_rotor(a):
        return CirclePoint[K](K.rejected(), K.rejected())
    var n = _norm(a)
    var x = K.div(K.sub(K.mul(a.y, a.y), K.mul(a.x, a.x)), n)
    var y = K.div(K.mul(K.from_int(2), K.mul(a.x, a.y)), n)
    return CirclePoint[K](x, y)


def circle_rotor[K: ExactField = QField](x: K.Element, y: K.Element) -> P1Over[K]:
    """The rotor of (x, y) on x^2 + y^2 = 1: [y : 1 + x], or [1 - x : y] at (-1, 0)."""
    if not K.accepted(x) or not K.accepted(y):
        return p1_rejected[K]()
    if not K.eq(K.add(K.mul(x, x), K.mul(y, y)), K.one()):
        return p1_rejected[K]()
    var one_plus_x = K.add(K.one(), x)
    if K.is_zero(y) and K.is_zero(one_plus_x):
        return p1[K](K.sub(K.one(), x), y)
    return p1[K](y, one_plus_x)


def rotor_spread[K: ExactField](a: P1Over[K]) -> K.Element:
    """sin^2(theta) = 4 x^2 y^2 / (x^2 + y^2)^2, the square of the circle's y."""
    if not is_rotor(a):
        return K.rejected()
    var n = _norm(a)
    var xy = K.mul(a.x, a.y)
    return K.div(K.mul(K.from_int(4), K.mul(xy, xy)), K.mul(n, n))


def spread_polynomial[K: ExactField = QField](n: Int, s: K.Element) -> K.Element:
    """S_n(s): S_0 = 0, S_1 = s, S_{k+1} = 2 (1 - 2 s) S_k - S_{k-1} + 2 s; S_{-n} = S_n."""
    var m = n if n >= 0 else -n
    if m == 0:
        return K.zero()
    var two = K.from_int(2)
    var step = K.mul(two, K.sub(K.one(), K.mul(two, s)))
    var lift = K.mul(two, s)
    var prev = K.zero()
    var cur = s.copy()
    for _ in range(1, m):
        var next = K.add(K.sub(K.mul(step, cur), prev), lift)
        prev = cur^
        cur = next^
    return cur^


def rotor_group_order_fp(p: Int64) -> Int64:
    """N_p = |T(F_p)| = p - (-1/p) for odd p; 0 for p = 2, where T is undefined here."""
    if p == 2:
        return 0
    return p - 1 if p % 4 == 1 else p + 1


def turn[K: ExactField](generator: P1Over[K], order: Int, a: Int, n: Int) -> P1Over[K]:
    """The turn a/n through a rotor of order `order`: generator^(a order / n).

    Rejects unless n > 0 divides order. A homomorphism (1/order)Z/Z -> T(K) for
    any rotor; injective when the generator has exact order `order`.
    """
    if n <= 0 or order <= 0 or order % n != 0 or not is_rotor(generator):
        return p1_rejected[K]()
    return rotor_power(generator, (a % n) * (order // n))


def rotor_generator_fp[p: Int64]() -> P1Over[FpField[p]]:
    """The first generator of T(F_p) among 0, 1, ..., p - 1, inf; odd p only."""
    var n = Int(rotor_group_order_fp(p))
    if n == 0:
        return p1_rejected[FpField[p]]()
    for t in range(Int(p)):
        var a = p1_affine[FpField[p]](FpField[p].from_int(Int64(t)))
        if rotor_order(a, n) == n:
            return a^
    var inf = half_turn[FpField[p]]()
    if rotor_order(inf, n) == n:
        return inf^
    return p1_rejected[FpField[p]]()
