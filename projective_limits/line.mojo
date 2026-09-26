# line.mojo
#
# The rational projective line P^1(Q), its Moebius maps, and the chordal
# metric, all exact.
#
# A P1 is a homogeneous pair [x:y] != [0:0] held in its unique normal form:
# [t:1] for an affine point t, or [1:0] for the single unsigned infinity.
# Equality of normal forms is equality of points. The chordal metric is
# irrational in general, so the exact quantity is its square.

from finite_exact.rat_q import Q, q_rejected


struct P1(Copyable):
    var x: Q
    var y: Q
    var rejected: Bool

    def __init__(out self):
        self.x = Q.zero()
        self.y = Q.one()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def p1_rejected() -> P1:
    var out = P1()
    out.rejected = True
    return out^


def p1(x: Q, y: Q) -> P1:
    """The point [x:y] in normal form; [0:0] and rejected inputs reject."""
    if x.rejected or y.rejected:
        return p1_rejected()
    var out = P1()
    if not y.num.is_zero():
        out.x = x.div(y)
    elif not x.num.is_zero():
        out.x = Q.one()
        out.y = Q.zero()
    else:
        return p1_rejected()
    return out^


def p1_affine(t: Q) -> P1:
    return p1(t, Q.one())


def p1_infinity() -> P1:
    return p1(Q.one(), Q.zero())


def p1_is_infinity(p: P1) -> Bool:
    return p.accepted() and p.y.num.is_zero()


def p1_equal(a: P1, b: P1) -> Bool:
    return a.accepted() and b.accepted() and a.x.eq(b.x) and a.y.eq(b.y)


def p1_value(p: P1) -> Q:
    """The affine coordinate t of [t:1]; infinity has none."""
    if not p.accepted() or p1_is_infinity(p):
        return q_rejected()
    return p.x.copy()


struct Mobius(Copyable):
    """z -> (a z + b)/(c z + d) with ad - bc != 0, as the matrix [[a,b],[c,d]]."""

    var a: Q
    var b: Q
    var c: Q
    var d: Q
    var rejected: Bool

    def __init__(out self):
        self.a = Q.one()
        self.b = Q.zero()
        self.c = Q.zero()
        self.d = Q.one()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def mobius(a: Q, b: Q, c: Q, d: Q) -> Mobius:
    var out = Mobius()
    out.a = a.copy()
    out.b = b.copy()
    out.c = c.copy()
    out.d = d.copy()
    var det = a.mul(d).sub(b.mul(c))
    out.rejected = det.rejected or det.num.is_zero()
    return out^


def mobius_apply(m: Mobius, p: P1) -> P1:
    """[x:y] -> [a x + b y : c x + d y]: defined everywhere, infinity included."""
    if not m.accepted() or not p.accepted():
        return p1_rejected()
    return p1(m.a.mul(p.x).add(m.b.mul(p.y)), m.c.mul(p.x).add(m.d.mul(p.y)))


def mobius_compose(m: Mobius, n: Mobius) -> Mobius:
    """m after n, the matrix product m n."""
    return mobius(
        m.a.mul(n.a).add(m.b.mul(n.c)),
        m.a.mul(n.b).add(m.b.mul(n.d)),
        m.c.mul(n.a).add(m.d.mul(n.c)),
        m.c.mul(n.b).add(m.d.mul(n.d)),
    )


def chordal_distance_squared(p: P1, r: P1) -> Q:
    """chi^2 = 4 (x0 y1 - x1 y0)^2 / ((x0^2 + x1^2)(y0^2 + y1^2)), in [0, 4]."""
    if not p.accepted() or not r.accepted():
        return q_rejected()
    var cross = p.x.mul(r.y).sub(p.y.mul(r.x))
    var norms = p.x.square().add(p.y.square()).mul(r.x.square().add(r.y.square()))
    return Q.from_int(4).mul(cross.square()).div(norms)
