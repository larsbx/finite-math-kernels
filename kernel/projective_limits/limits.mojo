# limits.mojo
#
# Limits of rational functions over an exact field K, computed as points of
# P^1(K). K is QField by default or a prime field FpField[p]; the code is
# the same.
#
# One kernel does all the work. Near a point, write numerator and denominator
# in a local parameter s. The pair (p(s), q(s)) enters the origin of the plane
# along the direction of its lowest nonvanishing order k, so
#
#     lim [p(s) : q(s)] = [p_k : q_k],
#
# the point where the lifted curve meets the exceptional divisor of the
# blow-up at the origin. `landing` computes it. Continuity, poles, the degree
# rule at infinity, L'Hopital, tangent slopes, asymptotes, and directional
# limits of bivariate quotients are each one choice of local parameter.
#
# The landing [p_k : q_k] is built from coefficients of polynomials over K, so
# a limit of f in K(x) at a point of P^1(K) is again a point of P^1(K): no
# exact limit leaves the field it started in. Landing needs no derivatives, so
# it stays correct in characteristic p where L'Hopital's k! can vanish.
#
# Everything is exact. A finite search that finds no path dependence proves
# nothing about existence; only a found witness is a certificate.

from finite_exact.field import ExactField, QField
from projective_limits.line import (
    P1Over,
    p1,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_is_infinity,
    p1_rejected,
)


struct PolyOver[K: ExactField](Copyable, Movable):
    """A univariate polynomial over K, coefficients from degree 0 upward."""

    var coeffs: List[Self.K.Element]

    def __init__(out self):
        self.coeffs = List[Self.K.Element]()

    def __init__(out self, coeffs: List[Self.K.Element]):
        self.coeffs = coeffs.copy()

    def coeff(self, k: Int) -> Self.K.Element:
        if k < 0 or k >= len(self.coeffs):
            return Self.K.zero()
        return self.coeffs[k].copy()

    def accepted(self) -> Bool:
        """Every stored coefficient is a valid exact field element."""
        for k in range(len(self.coeffs)):
            if not Self.K.accepted(self.coeffs[k]):
                return False
        return True

    def degree(self) -> Int:
        """Degree, or -1 for the zero polynomial. Call only after accepted()."""
        var k = len(self.coeffs) - 1
        while k >= 0 and Self.K.is_zero(self.coeffs[k]):
            k -= 1
        return k

    def add(self, other: Self) -> Self:
        var out = Self()
        for k in range(max(len(self.coeffs), len(other.coeffs))):
            out.coeffs.append(Self.K.add(self.coeff(k), other.coeff(k)))
        return out^

    def scale(self, c: Self.K.Element) -> Self:
        var out = Self()
        for k in range(len(self.coeffs)):
            out.coeffs.append(Self.K.mul(self.coeffs[k], c))
        return out^

    def sub(self, other: Self) -> Self:
        return self.add(other.scale(Self.K.from_int(-1)))

    def mul(self, other: Self) -> Self:
        var out = Self()
        for _ in range(len(self.coeffs) + len(other.coeffs) - 1):
            out.coeffs.append(Self.K.zero())
        for i in range(len(self.coeffs)):
            for j in range(len(other.coeffs)):
                out.coeffs[i + j] = Self.K.add(
                    out.coeffs[i + j], Self.K.mul(self.coeffs[i], other.coeffs[j])
                )
        return out^

    def pow(self, n: Int) -> Self:
        if n < 0:
            return constant[Self.K](Self.K.rejected())
        var out = constant[Self.K](Self.K.one())
        for _ in range(n):
            out = out.mul(self)
        return out^

    def eval(self, t: Self.K.Element) -> Self.K.Element:
        var acc = Self.K.zero()
        for k in range(len(self.coeffs) - 1, -1, -1):
            acc = Self.K.add(Self.K.mul(acc, t), self.coeffs[k])
        return acc^

    def shift(self, a: Self.K.Element) -> Self:
        """p(a + s) in the local parameter s at a (Horner over polynomials)."""
        var local = linear[Self.K](a, Self.K.one())
        var acc = Self()
        for k in range(len(self.coeffs) - 1, -1, -1):
            acc = acc.mul(local).add(constant[Self.K](self.coeffs[k]))
        return acc^

    def at_infinity(self, d: Int) -> Self:
        """s^d p(1/s), the local form at [1:0] in the chart s = 1/x."""
        var out = Self()
        for k in range(d + 1):
            out.coeffs.append(self.coeff(d - k))
        return out^


comptime Poly = PolyOver[QField]


def constant[K: ExactField = QField](c: K.Element) -> PolyOver[K]:
    var coeffs = List[K.Element]()
    coeffs.append(c.copy())
    return PolyOver[K](coeffs)


def linear[K: ExactField = QField](c0: K.Element, c1: K.Element) -> PolyOver[K]:
    var coeffs = List[K.Element]()
    coeffs.append(c0.copy())
    coeffs.append(c1.copy())
    return PolyOver[K](coeffs)


def poly_i64[K: ExactField = QField](ints: List[Int]) -> PolyOver[K]:
    var out = PolyOver[K]()
    for k in range(len(ints)):
        out.coeffs.append(K.from_int(Int64(ints[k])))
    return out^


struct RationalMapOver[K: ExactField](Copyable, Movable):
    """x -> num(x)/den(x), read as a map P^1 -> P^1."""

    var num: PolyOver[Self.K]
    var den: PolyOver[Self.K]

    def __init__(out self, num: PolyOver[Self.K], den: PolyOver[Self.K]):
        self.num = num.copy()
        self.den = den.copy()


comptime RationalMap = RationalMapOver[QField]


def landing[K: ExactField](p_local: PolyOver[K], q_local: PolyOver[K]) -> P1Over[K]:
    """lim_{s->0} [p(s) : q(s)]: the first order k with (p_k, q_k) != (0, 0)."""
    for k in range(max(len(p_local.coeffs), len(q_local.coeffs))):
        var pk = p_local.coeff(k)
        var qk = q_local.coeff(k)
        if not K.accepted(pk) or not K.accepted(qk):
            return p1_rejected[K]()
        if not K.is_zero(pk) or not K.is_zero(qk):
            return p1[K](pk, qk)
    return p1_rejected[K]()


def rational_limit[K: ExactField](f: RationalMapOver[K], point: P1Over[K]) -> P1Over[K]:
    """lim_{x -> point} f(x) in P^1, for any point of P^1 including infinity."""
    if not point.accepted():
        return p1_rejected[K]()
    # Degree trimming inspects numerators, so reject malformed coefficients
    # before a rejected coefficient can masquerade as a valid zero.
    if not f.num.accepted() or not f.den.accepted():
        return p1_rejected[K]()
    if p1_is_infinity(point):
        var d = max(f.num.degree(), f.den.degree())
        return landing(f.num.at_infinity(d), f.den.at_infinity(d))
    return landing(f.num.shift(point.x), f.den.shift(point.x))


def tangent_slope[K: ExactField](x: PolyOver[K], y: PolyOver[K], t0: K.Element) -> P1Over[K]:
    """Limit of secant slopes of t -> (x(t), y(t)) at t0, in the pencil at P.

    The secant through P = (x(t0), y(t0)) and Q = (x(t), y(t)) has slope
    [y(t) - y(t0) : x(t) - x(t0)]; vertical tangents are the point infinity.
    """
    var dy = y.sub(constant[K](y.eval(t0)))
    var dx = x.sub(constant[K](x.eval(t0)))
    return rational_limit(RationalMapOver(dy, dx), p1_affine[K](t0))


struct Asymptote[K: ExactField](Copyable, Movable):
    """y = slope x + intercept: the tangent at the branch's point at infinity."""

    var slope: P1Over[Self.K]
    var intercept: P1Over[Self.K]

    def __init__(out self, slope: P1Over[Self.K], intercept: P1Over[Self.K]):
        self.slope = slope.copy()
        self.intercept = intercept.copy()


def asymptote[K: ExactField](f: RationalMapOver[K]) -> Asymptote[K]:
    """m = lim f(x)/x and c = lim (f(x) - m x) at infinity.

    An infinite m means the branch meets the line at infinity at [0:1:0],
    in the vertical direction, and no line y = m x + c is tangent there.
    """
    var x = linear[K](K.zero(), K.one())
    var m = rational_limit(RationalMapOver(f.num, f.den.mul(x)), p1_infinity[K]())
    if not m.accepted() or p1_is_infinity(m):
        return Asymptote(m, p1_rejected[K]())
    var residual = f.num.sub(f.den.mul(x).scale(m.x))
    return Asymptote(m, rational_limit(RationalMapOver(residual, f.den), p1_infinity[K]()))


struct MonomialOver[K: ExactField](Copyable, Movable):
    var i: Int
    var j: Int
    var c: Self.K.Element

    def __init__(out self, i: Int, j: Int, c: Self.K.Element):
        self.i = i
        self.j = j
        self.c = c.copy()


comptime Monomial = MonomialOver[QField]


struct Poly2Over[K: ExactField](Copyable, Movable):
    """A bivariate polynomial over K, as a sum of c x^i y^j."""

    var terms: List[MonomialOver[Self.K]]

    def __init__(out self):
        self.terms = List[MonomialOver[Self.K]]()

    def along(self, x: PolyOver[Self.K], y: PolyOver[Self.K]) -> PolyOver[Self.K]:
        """P(x(t), y(t)) as a polynomial in t."""
        var acc = PolyOver[Self.K]()
        for k in range(len(self.terms)):
            var m = self.terms[k].copy()
            acc = acc.add(x.pow(m.i).mul(y.pow(m.j)).scale(m.c))
        return acc^


comptime Poly2 = Poly2Over[QField]


def poly2_monomial[K: ExactField = QField](i: Int, j: Int, c: K.Element) -> Poly2Over[K]:
    var out = Poly2Over[K]()
    out.terms.append(MonomialOver[K](i, j, c))
    return out^


def poly2_sum[K: ExactField](a: Poly2Over[K], b: Poly2Over[K]) -> Poly2Over[K]:
    var out = a.copy()
    for k in range(len(b.terms)):
        out.terms.append(b.terms[k].copy())
    return out^


def curve_limit[K: ExactField](
    num: Poly2Over[K], den: Poly2Over[K], x: PolyOver[K], y: PolyOver[K]
) -> P1Over[K]:
    """lim num/den at the origin along the arc t -> (x(t), y(t)), t -> 0.

    The arc must pass through the origin at t = 0; otherwise it rejects.
    Lines are one blow-up; higher-contact arcs such as y = x^2 are iterated ones.
    """
    if not K.is_zero(x.coeff(0)) or not K.is_zero(y.coeff(0)):
        return p1_rejected[K]()
    return landing(num.along(x, y), den.along(x, y))


def directional_limit[K: ExactField](
    num: Poly2Over[K], den: Poly2Over[K], direction: P1Over[K]
) -> P1Over[K]:
    """The value of num/den on the exceptional divisor at the direction [a:b]."""
    if not direction.accepted():
        return p1_rejected[K]()
    return curve_limit(
        num, den, linear[K](K.zero(), direction.x), linear[K](K.zero(), direction.y)
    )


struct PathWitness[K: ExactField](Copyable, Movable):
    """Two directions with distinct exact directional limits, when found."""

    var found: Bool
    var first: P1Over[Self.K]
    var second: P1Over[Self.K]
    var first_limit: P1Over[Self.K]
    var second_limit: P1Over[Self.K]

    def __init__(out self):
        self.found = False
        self.first = p1_rejected[Self.K]()
        self.second = p1_rejected[Self.K]()
        self.first_limit = p1_rejected[Self.K]()
        self.second_limit = p1_rejected[Self.K]()


def path_dependence_witness[K: ExactField](
    num: Poly2Over[K], den: Poly2Over[K], search: Int
) -> PathWitness[K]:
    """Scan the directions [1:0] and [t:1], |t| <= search, for two limits that differ.

    A found witness certifies that the limit at the origin does not exist.
    Not finding one is inconclusive. Over FpField[p] the directions repeat mod p,
    and search >= p // 2 covers all of P^1(F_p), so a miss there is exhaustive.
    """
    var directions = List[P1Over[K]]()
    directions.append(p1_infinity[K]())
    for t in range(-search, search + 1):
        directions.append(p1_affine[K](K.from_int(Int64(t))))

    var out = PathWitness[K]()
    for k in range(len(directions)):
        var value = directional_limit(num, den, directions[k])
        if not value.accepted():
            continue
        if not out.first_limit.accepted():
            out.first = directions[k].copy()
            out.first_limit = value.copy()
        elif not p1_equal(value, out.first_limit):
            out.found = True
            out.second = directions[k].copy()
            out.second_limit = value.copy()
            return out^
    return out^
