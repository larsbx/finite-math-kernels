# limits.mojo
#
# Limits of rational functions over Q, computed as points of P^1.
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
# Everything is exact. A finite search that finds no path dependence proves
# nothing about existence; only a found witness is a certificate.

from finite_exact.rat_q import Q, q_rejected
from projective_limits.line import (
    P1,
    p1,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_is_infinity,
    p1_rejected,
)


struct Poly(Copyable, Movable):
    """A univariate polynomial over Q, coefficients from degree 0 upward."""

    var coeffs: List[Q]

    def __init__(out self):
        self.coeffs = List[Q]()

    def __init__(out self, coeffs: List[Q]):
        self.coeffs = coeffs.copy()

    def coeff(self, k: Int) -> Q:
        if k < 0 or k >= len(self.coeffs):
            return Q.zero()
        return self.coeffs[k].copy()

    def accepted(self) -> Bool:
        """Every stored coefficient is a valid exact rational."""
        for k in range(len(self.coeffs)):
            if self.coeffs[k].rejected:
                return False
        return True

    def degree(self) -> Int:
        """Degree, or -1 for the zero polynomial. Call only after accepted()."""
        var k = len(self.coeffs) - 1
        while k >= 0 and self.coeffs[k].num.is_zero():
            k -= 1
        return k

    def add(self, other: Poly) -> Poly:
        var out = Poly()
        for k in range(max(len(self.coeffs), len(other.coeffs))):
            out.coeffs.append(self.coeff(k).add(other.coeff(k)))
        return out^

    def scale(self, c: Q) -> Poly:
        var out = Poly()
        for k in range(len(self.coeffs)):
            out.coeffs.append(self.coeffs[k].mul(c))
        return out^

    def sub(self, other: Poly) -> Poly:
        return self.add(other.scale(Q.from_int(-1)))

    def mul(self, other: Poly) -> Poly:
        var out = Poly()
        for _ in range(len(self.coeffs) + len(other.coeffs) - 1):
            out.coeffs.append(Q.zero())
        for i in range(len(self.coeffs)):
            for j in range(len(other.coeffs)):
                out.coeffs[i + j] = out.coeffs[i + j].add(self.coeffs[i].mul(other.coeffs[j]))
        return out^

    def pow(self, n: Int) -> Poly:
        if n < 0:
            return constant(q_rejected())
        var out = constant(Q.one())
        for _ in range(n):
            out = out.mul(self)
        return out^

    def eval(self, t: Q) -> Q:
        var acc = Q.zero()
        for k in range(len(self.coeffs) - 1, -1, -1):
            acc = acc.mul(t).add(self.coeffs[k])
        return acc^

    def shift(self, a: Q) -> Poly:
        """p(a + s) in the local parameter s at a (Horner over polynomials)."""
        var local = linear(a, Q.one())
        var acc = Poly()
        for k in range(len(self.coeffs) - 1, -1, -1):
            acc = acc.mul(local).add(constant(self.coeffs[k]))
        return acc^

    def at_infinity(self, d: Int) -> Poly:
        """s^d p(1/s), the local form at [1:0] in the chart s = 1/x."""
        var out = Poly()
        for k in range(d + 1):
            out.coeffs.append(self.coeff(d - k))
        return out^


def constant(c: Q) -> Poly:
    var coeffs = List[Q]()
    coeffs.append(c.copy())
    return Poly(coeffs)


def linear(c0: Q, c1: Q) -> Poly:
    var coeffs = List[Q]()
    coeffs.append(c0.copy())
    coeffs.append(c1.copy())
    return Poly(coeffs)


def poly_i64(ints: List[Int]) -> Poly:
    var out = Poly()
    for k in range(len(ints)):
        out.coeffs.append(Q.from_int(Int64(ints[k])))
    return out^


struct RationalMap(Copyable, Movable):
    """x -> num(x)/den(x), read as a map P^1 -> P^1."""

    var num: Poly
    var den: Poly

    def __init__(out self, num: Poly, den: Poly):
        self.num = num.copy()
        self.den = den.copy()


def landing(p_local: Poly, q_local: Poly) -> P1:
    """lim_{s->0} [p(s) : q(s)]: the first order k with (p_k, q_k) != (0, 0)."""
    for k in range(max(len(p_local.coeffs), len(q_local.coeffs))):
        var pk = p_local.coeff(k)
        var qk = q_local.coeff(k)
        if pk.rejected or qk.rejected:
            return p1_rejected()
        if not pk.num.is_zero() or not qk.num.is_zero():
            return p1(pk, qk)
    return p1_rejected()


def rational_limit(f: RationalMap, point: P1) -> P1:
    """lim_{x -> point} f(x) in P^1, for any point of P^1 including infinity."""
    if not point.accepted():
        return p1_rejected()
    # Degree trimming inspects numerators, so reject malformed coefficients
    # before a rejected Q can masquerade as a valid zero coefficient.
    if not f.num.accepted() or not f.den.accepted():
        return p1_rejected()
    if p1_is_infinity(point):
        var d = max(f.num.degree(), f.den.degree())
        return landing(f.num.at_infinity(d), f.den.at_infinity(d))
    return landing(f.num.shift(point.x), f.den.shift(point.x))


def tangent_slope(x: Poly, y: Poly, t0: Q) -> P1:
    """Limit of secant slopes of t -> (x(t), y(t)) at t0, in the pencil at P.

    The secant through P = (x(t0), y(t0)) and Q = (x(t), y(t)) has slope
    [y(t) - y(t0) : x(t) - x(t0)]; vertical tangents are the point infinity.
    """
    var dy = y.sub(constant(y.eval(t0)))
    var dx = x.sub(constant(x.eval(t0)))
    return rational_limit(RationalMap(dy, dx), p1_affine(t0))


struct Asymptote(Copyable, Movable):
    """y = slope x + intercept: the tangent at the branch's point at infinity."""

    var slope: P1
    var intercept: P1

    def __init__(out self, slope: P1, intercept: P1):
        self.slope = slope.copy()
        self.intercept = intercept.copy()


def asymptote(f: RationalMap) -> Asymptote:
    """m = lim f(x)/x and c = lim (f(x) - m x) at infinity.

    An infinite m means the branch meets the line at infinity at [0:1:0],
    in the vertical direction, and no line y = m x + c is tangent there.
    """
    var x = linear(Q.zero(), Q.one())
    var m = rational_limit(RationalMap(f.num, f.den.mul(x)), p1_infinity())
    if not m.accepted() or p1_is_infinity(m):
        return Asymptote(m, p1_rejected())
    var residual = f.num.sub(f.den.mul(x).scale(m.x))
    return Asymptote(m, rational_limit(RationalMap(residual, f.den), p1_infinity()))


struct Monomial(Copyable, Movable):
    var i: Int
    var j: Int
    var c: Q

    def __init__(out self, i: Int, j: Int, c: Q):
        self.i = i
        self.j = j
        self.c = c.copy()


struct Poly2(Copyable, Movable):
    """A bivariate polynomial over Q, as a sum of c x^i y^j."""

    var terms: List[Monomial]

    def __init__(out self):
        self.terms = List[Monomial]()

    def along(self, x: Poly, y: Poly) -> Poly:
        """P(x(t), y(t)) as a polynomial in t."""
        var acc = Poly()
        for k in range(len(self.terms)):
            var m = self.terms[k].copy()
            acc = acc.add(x.pow(m.i).mul(y.pow(m.j)).scale(m.c))
        return acc^


def poly2_monomial(i: Int, j: Int, c: Q) -> Poly2:
    var out = Poly2()
    out.terms.append(Monomial(i, j, c))
    return out^


def poly2_sum(a: Poly2, b: Poly2) -> Poly2:
    var out = a.copy()
    for k in range(len(b.terms)):
        out.terms.append(b.terms[k].copy())
    return out^


def curve_limit(num: Poly2, den: Poly2, x: Poly, y: Poly) -> P1:
    """lim num/den at the origin along the arc t -> (x(t), y(t)), t -> 0.

    The arc must pass through the origin at t = 0; otherwise it rejects.
    Lines are one blow-up; higher-contact arcs such as y = x^2 are iterated ones.
    """
    if not x.coeff(0).num.is_zero() or not y.coeff(0).num.is_zero():
        return p1_rejected()
    return landing(num.along(x, y), den.along(x, y))


def directional_limit(num: Poly2, den: Poly2, direction: P1) -> P1:
    """The value of num/den on the exceptional divisor at the direction [a:b]."""
    if not direction.accepted():
        return p1_rejected()
    return curve_limit(
        num, den, linear(Q.zero(), direction.x), linear(Q.zero(), direction.y)
    )


struct PathWitness(Copyable, Movable):
    """Two directions with distinct exact directional limits, when found."""

    var found: Bool
    var first: P1
    var second: P1
    var first_limit: P1
    var second_limit: P1

    def __init__(out self):
        self.found = False
        self.first = p1_rejected()
        self.second = p1_rejected()
        self.first_limit = p1_rejected()
        self.second_limit = p1_rejected()


def path_dependence_witness(num: Poly2, den: Poly2, search: Int) -> PathWitness:
    """Scan the directions [1:0] and [t:1], |t| <= search, for two limits that differ.

    A found witness certifies that the limit at the origin does not exist.
    Not finding one is inconclusive.
    """
    var directions = List[P1]()
    directions.append(p1_infinity())
    for t in range(-search, search + 1):
        directions.append(p1_affine(Q.from_int(Int64(t))))

    var out = PathWitness()
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
