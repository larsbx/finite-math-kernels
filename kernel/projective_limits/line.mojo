# line.mojo
#
# The projective line P^1(K) over an exact field K, its Moebius maps, and the
# chordal metric, all exact. K is any ExactField: QField by default, or a
# prime field FpField[p]; points hold coordinates of type K.Element.
#
# A P1Over[K] is a homogeneous pair [x:y] != [0:0] held in its unique normal
# form: [t:1] for an affine point t, or [1:0] for the single unsigned infinity.
# Equality of normal forms is equality of points. The chordal metric is
# irrational in general, so the exact quantity is its square, which is four
# times the spread of rational trigonometry between (x0, y0) and (x1, y1).
# Over a field where x^2 + y^2 can vanish (Fp with p = 1 mod 4), such isotropic
# points have no chordal quadrance and it rejects.
#
# The Moebius maps live in mobius_transformation.mojo, which cites them; its
# names are re-exported here unchanged.

from finite_exact.field import ExactField, QField
from projective_limits.mobius_transformation import Mobius, MobiusOver, mobius, mobius_apply, mobius_compose


struct P1Over[K: ExactField](Copyable):
    var x: Self.K.Element
    var y: Self.K.Element
    var rejected: Bool

    def __init__(out self):
        self.x = Self.K.zero()
        self.y = Self.K.one()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


comptime P1 = P1Over[QField]


def p1_rejected[K: ExactField = QField]() -> P1Over[K]:
    var out = P1Over[K]()
    out.rejected = True
    return out^


def p1[K: ExactField = QField](x: K.Element, y: K.Element) -> P1Over[K]:
    """The point [x:y] in normal form; [0:0] and rejected inputs reject."""
    if not K.accepted(x) or not K.accepted(y):
        return p1_rejected[K]()
    var out = P1Over[K]()
    if not K.is_zero(y):
        out.x = K.div(x, y)
    elif not K.is_zero(x):
        out.x = K.one()
        out.y = K.zero()
    else:
        return p1_rejected[K]()
    return out^


def p1_affine[K: ExactField = QField](t: K.Element) -> P1Over[K]:
    return p1[K](t, K.one())


def p1_infinity[K: ExactField = QField]() -> P1Over[K]:
    return p1[K](K.one(), K.zero())


def p1_is_infinity[K: ExactField](p: P1Over[K]) -> Bool:
    return p.accepted() and K.is_zero(p.y)


def p1_equal[K: ExactField](a: P1Over[K], b: P1Over[K]) -> Bool:
    return a.accepted() and b.accepted() and K.eq(a.x, b.x) and K.eq(a.y, b.y)


def p1_value[K: ExactField](p: P1Over[K]) -> K.Element:
    """The affine coordinate t of [t:1]; infinity has none."""
    if not p.accepted() or p1_is_infinity(p):
        return K.rejected()
    return p.x.copy()


def chordal_distance_squared[K: ExactField](p: P1Over[K], r: P1Over[K]) -> K.Element:
    """chi^2 = 4 (x0 y1 - x1 y0)^2 / ((x0^2 + x1^2)(y0^2 + y1^2)), in [0, 4] over Q."""
    if not p.accepted() or not r.accepted():
        return K.rejected()
    var cross = K.sub(K.mul(p.x, r.y), K.mul(p.y, r.x))
    var norms = K.mul(
        K.add(K.mul(p.x, p.x), K.mul(p.y, p.y)), K.add(K.mul(r.x, r.x), K.mul(r.y, r.y))
    )
    return K.div(K.mul(K.from_int(4), K.mul(cross, cross)), norms)
