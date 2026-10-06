# mobius_transformation.mojo
#
# Moebius transformations of P^1(K) over an exact field K, exactly.
#
# z -> (a z + b)/(c z + d) with ad - bc != 0, held as the matrix [[a, b], [c, d]]
# and acting on homogeneous pairs by [x:y] -> [a x + b y : c x + d y], so it is
# defined everywhere, infinity included; composition is the matrix product,
# and the group is PGL_2(K). References: A. F. Moebius, *Der barycentrische
# Calcul* (1827) and "Theorie der Kreisverwandtschaft in rein geometrischer
# Darstellung", Abh. Koenigl. Saechs. Ges. Wiss. 2 (1855); L. V. Ahlfors,
# *Complex Analysis* (3rd ed., McGraw-Hill, 1979), chapter 3, section 3.
#
# Previously in line.mojo, which keeps P^1(K) and the chordal metric and still
# re-exports every name here.

from finite_exact.field import ExactField, QField
from projective_limits.line import P1Over, p1, p1_rejected


struct MobiusOver[K: ExactField](Copyable):
    """z -> (a z + b)/(c z + d) with ad - bc != 0, as the matrix [[a,b],[c,d]]."""

    var a: Self.K.Element
    var b: Self.K.Element
    var c: Self.K.Element
    var d: Self.K.Element
    var rejected: Bool

    def __init__(out self):
        self.a = Self.K.one()
        self.b = Self.K.zero()
        self.c = Self.K.zero()
        self.d = Self.K.one()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


comptime Mobius = MobiusOver[QField]


def mobius[K: ExactField = QField](
    a: K.Element, b: K.Element, c: K.Element, d: K.Element
) -> MobiusOver[K]:
    var out = MobiusOver[K]()
    out.a = a.copy()
    out.b = b.copy()
    out.c = c.copy()
    out.d = d.copy()
    var det = K.sub(K.mul(a, d), K.mul(b, c))
    out.rejected = not K.accepted(det) or K.is_zero(det)
    return out^


def mobius_apply[K: ExactField](m: MobiusOver[K], p: P1Over[K]) -> P1Over[K]:
    """[x:y] -> [a x + b y : c x + d y]: defined everywhere, infinity included."""
    if not m.accepted() or not p.accepted():
        return p1_rejected[K]()
    return p1[K](
        K.add(K.mul(m.a, p.x), K.mul(m.b, p.y)), K.add(K.mul(m.c, p.x), K.mul(m.d, p.y))
    )


def mobius_compose[K: ExactField](m: MobiusOver[K], n: MobiusOver[K]) -> MobiusOver[K]:
    """m after n, the matrix product m n."""
    return mobius[K](
        K.add(K.mul(m.a, n.a), K.mul(m.b, n.c)),
        K.add(K.mul(m.a, n.b), K.mul(m.b, n.d)),
        K.add(K.mul(m.c, n.a), K.mul(m.d, n.c)),
        K.add(K.mul(m.c, n.b), K.mul(m.d, n.d)),
    )
