# Chromatic planar quadratic forms, determinant, and guarded spread.
# N. J. Wildberger, "Chromogeometry", Mathematical Intelligencer (2010);
# arXiv:0806.3617.  All claims here are field algebra, no analytic metrics.
#
# Requires 2 != 0 for spread laws. Invalid/null inputs reject through ExactField.
# This package is domain-neutral. Consumers choose their own agent dynamics.

from finite_exact.field import ExactField


struct ChromoVec2[K: ExactField](Copyable):
    var x: Self.K.Element
    var y: Self.K.Element

    def __init__(out self, x: Self.K.Element, y: Self.K.Element):
        self.x = x.copy()
        self.y = y.copy()

    def accepted(self) -> Bool:
        return Self.K.accepted(self.x) and Self.K.accepted(self.y)


def chromo_det[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return K.sub(K.mul(u.x, v.y), K.mul(u.y, v.x))


def chromo_blue[K: ExactField](u: ChromoVec2[K]) -> K.Element:
    return K.add(K.mul(u.x, u.x), K.mul(u.y, u.y))


def chromo_red[K: ExactField](u: ChromoVec2[K]) -> K.Element:
    return K.sub(K.mul(u.x, u.x), K.mul(u.y, u.y))


def chromo_green[K: ExactField](u: ChromoVec2[K]) -> K.Element:
    return K.mul(K.from_int(2), K.mul(u.x, u.y))


def chromo_blue_b[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return K.add(K.mul(u.x, v.x), K.mul(u.y, v.y))


def chromo_red_b[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return K.sub(K.mul(u.x, v.x), K.mul(u.y, v.y))


def chromo_green_b[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return K.add(K.mul(u.x, v.y), K.mul(u.y, v.x))


def _guarded_spread[K: ExactField](
    u: ChromoVec2[K], v: ChromoVec2[K],
    qu: K.Element, qv: K.Element, b: K.Element
) -> K.Element:
    if not u.accepted() or not v.accepted() or K.is_zero(K.from_int(2)):
        return K.rejected()
    var den = K.mul(qu, qv)
    if not K.accepted(den) or K.is_zero(den):
        return K.rejected()
    return K.sub(K.one(), K.div(K.mul(b, b), den))


def chromo_blue_spread[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return _guarded_spread(u, v, chromo_blue(u), chromo_blue(v), chromo_blue_b(u, v))


def chromo_red_spread[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return _guarded_spread(u, v, chromo_red(u), chromo_red(v), chromo_red_b(u, v))


def chromo_green_spread[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> K.Element:
    return _guarded_spread(u, v, chromo_green(u), chromo_green(v), chromo_green_b(u, v))


def chromo_pythagoras[K: ExactField](u: ChromoVec2[K]) -> Bool:
    """Q_blue(u)^2 = Q_red(u)^2 + Q_green(u)^2."""
    if not u.accepted():
        return False
    var b = chromo_blue(u)
    var r = chromo_red(u)
    var g = chromo_green(u)
    return K.eq(K.mul(b, b), K.add(K.mul(r, r), K.mul(g, g)))


def chromo_harmonic_spread[K: ExactField](u: ChromoVec2[K], v: ChromoVec2[K]) -> Bool:
    """1/s_blue + 1/s_red + 1/s_green = 2, only where all inverses exist."""
    if K.is_zero(K.from_int(2)):
        return False
    var b = chromo_blue_spread(u, v)
    var r = chromo_red_spread(u, v)
    var g = chromo_green_spread(u, v)
    if not K.accepted(b) or not K.accepted(r) or not K.accepted(g):
        return False
    if K.is_zero(b) or K.is_zero(r) or K.is_zero(g):
        return False
    return K.eq(
        K.add(K.add(K.div(K.one(), b), K.div(K.one(), r)), K.div(K.one(), g)),
        K.from_int(2)
    )


def chromo_gram_identity[K: ExactField](
    u: ChromoVec2[K], v: ChromoVec2[K], color: Int
) -> Bool:
    """Q(u)Q(v)-b(u,v)^2 = det(M_color)*det(u,v)^2.

    The color ID is 0=blue, 1=red, 2=green. Invalid ID returns False.
    """
    if not u.accepted() or not v.accepted():
        return False
    var qu: K.Element
    var qv: K.Element
    var b: K.Element
    if color == 0:
        qu = chromo_blue(u)
        qv = chromo_blue(v)
        b = chromo_blue_b(u, v)
    elif color == 1:
        qu = chromo_red(u)
        qv = chromo_red(v)
        b = chromo_red_b(u, v)
    elif color == 2:
        qu = chromo_green(u)
        qv = chromo_green(v)
        b = chromo_green_b(u, v)
    else:
        return False
    var d = chromo_det(u, v)
    var rhs = K.mul(d, d)
    if color != 0:
        rhs = K.neg(rhs)
    return K.eq(K.sub(K.mul(qu, qv), K.mul(b, b)), rhs)
