# field.mojo
#
# Q(zeta_q) = Q[X]/(Phi_q), with elements stored as their unique coordinates
# on 1, zeta, ..., zeta^(phi(q)-1). The conductor q is a compile-time
# parameter, so elements of different cyclotomic fields cannot be mixed, and
# Phi_q and phi(q) are compile-time constants of each field: the compiler
# evaluates them, and checks deg Phi_q = phi(q), for every conductor in use.
#
# Phi_q is the Moebius product prod_{d | q} (X^d - 1)^mu(q/d): multiply the
# factors with mu = 1, then divide exactly by those with mu = -1. For
# q < 30030 = 2 3 5 7 11 13 at most sixteen factors are multiplied, so every
# integer coefficient stays far inside Int.
#
# The inverse goes through the norm: a^-1 = prod_{e != 1} sigma_e(a) / N(a),
# with N(a) = prod_e sigma_e(a) in Q, nonzero exactly when a is. Rejection is
# sticky, and == is False whenever either side is rejected.

from finite_exact.bigint_z import BigZ, bigz_canonical_bytes, bigz_from_i64
from finite_exact.field import ExactField
from finite_exact.rat_q import Q, q_canonical_bytes, q_rejected

comptime CONDUCTOR_BOUND = 30030


def _gcd(a: Int, b: Int) -> Int:
    var x = a if a >= 0 else -a
    var y = b if b >= 0 else -b
    while y != 0:
        (x, y) = (y, x % y)
    return x


def mobius_mu(n: Int) -> Int:
    """mu(n): 0 if a square divides n, else (-1)^(number of prime factors)."""
    var m = n
    var sign = 1
    var p = 2
    while p * p <= m:
        if m % p == 0:
            m //= p
            if m % p == 0:
                return 0
            sign = -sign
        p += 1
    return -sign if m > 1 else sign


def euler_phi(n: Int) -> Int:
    var count = 0
    for k in range(1, n + 1):
        if _gcd(k, n) == 1:
            count += 1
    return count


def units(q: Int) -> List[Int]:
    """The exponents 1 <= e <= q with gcd(e, q) = 1: the Galois group."""
    var out = List[Int]()
    for e in range(1, q + 1):
        if _gcd(e, q) == 1:
            out.append(e)
    return out^


def cyclotomic_polynomial(q: Int) -> List[Int]:
    """Phi_q, integer coefficients low -> high; empty outside 1 <= q < 30030."""
    if q < 1 or q >= CONDUCTOR_BOUND:
        return List[Int]()
    var p: List[Int] = [1]
    for d in range(1, q + 1):
        if q % d == 0 and mobius_mu(q // d) == 1:
            var out = List[Int](length=len(p) + d, fill=0)
            for k in range(len(p)):
                out[k + d] += p[k]
                out[k] -= p[k]
            p = out^
    for d in range(1, q + 1):
        if q % d == 0 and mobius_mu(q // d) == -1:
            # p = r (X^d - 1): r_k = r_{k-d} - p_k, then the top d must agree.
            var r = List[Int]()
            for k in range(len(p) - d):
                r.append((r[k - d] if k >= d else 0) - p[k])
            for k in range(len(p) - d, len(p)):
                if p[k] != (r[k - d] if k >= d else 0):
                    return List[Int]()
            p = r^
    return p^


@fieldwise_init
struct CycCanonicalBytes(Copyable):
    var bytes: List[UInt8]
    var rejected: Bool


@fieldwise_init
struct Cyc[q: Int](Copyable, Writable):
    """An element of Q(zeta_q): coordinates on 1, zeta, ..., zeta^(phi(q)-1)."""

    comptime PHI = cyclotomic_polynomial(Self.q)
    comptime DEGREE = euler_phi(Self.q)

    var c: List[Q]
    var rejected: Bool

    # Construction. Every path reduces modulo Phi_q or is refused.

    @staticmethod
    def refused() -> Self:
        comptime assert Self.q >= 1 and Self.q < CONDUCTOR_BOUND, "conductor out of range"
        return Self(List[Q](), True)

    @staticmethod
    def from_poly(coefficients: List[Q]) -> Self:
        """The class of sum c_k X^k modulo Phi_q; a rejected coefficient rejects."""
        comptime assert Self.q >= 1 and Self.q < CONDUCTOR_BOUND, "conductor out of range"
        comptime assert len(materialize[Self.PHI]()) == Self.DEGREE + 1, "deg Phi_q != phi(q)"
        var phi_q = materialize[Self.PHI]()
        comptime n = Self.DEGREE
        var v = List[Q]()
        for k in range(len(coefficients)):
            if coefficients[k].rejected:
                return Self.refused()
            v.append(coefficients[k].copy())
        while len(v) < n:
            v.append(Q.zero())
        for k in range(len(v) - 1, n - 1, -1):
            var lead = v[k].copy()
            if lead.num.is_zero():
                continue
            for i in range(n + 1):
                if phi_q[i] != 0:
                    v[k - n + i] = v[k - n + i].sub(lead.mul(Q.from_int(Int64(phi_q[i]))))
        v.shrink(n)
        return Self(v^, False)

    @staticmethod
    def rational(r: Q) -> Self:
        return Self.from_poly([r.copy()])

    @staticmethod
    def zeta(k: Int = 1) -> Self:
        """zeta_q^k for any integer k."""
        var v = List[Q](length=Self.q, fill=Q.zero())
        v[k % Self.q] = Q.one()
        return Self.from_poly(v)

    # Predicates.

    def accepted(self) -> Bool:
        return not self.rejected

    def is_zero(self) -> Bool:
        if self.rejected:
            return False
        for x in self.c:
            if not x.num.is_zero():
                return False
        return True

    # Ring operations.

    def __neg__(self) -> Self:
        if self.rejected:
            return Self.refused()
        return Self([x.neg() for x in self.c], False)

    def __add__(self, other: Self) -> Self:
        if self.rejected or other.rejected:
            return Self.refused()
        return Self([self.c[k].add(other.c[k]) for k in range(len(self.c))], False)

    def __sub__(self, other: Self) -> Self:
        return self + (-other)

    def __mul__(self, other: Self) -> Self:
        if self.rejected or other.rejected:
            return Self.refused()
        var v = List[Q](length=len(self.c) + len(other.c) - 1, fill=Q.zero())
        for i in range(len(self.c)):
            if self.c[i].num.is_zero():
                continue
            for j in range(len(other.c)):
                v[i + j] = v[i + j].add(self.c[i].mul(other.c[j]))
        return Self.from_poly(v)

    def __truediv__(self, other: Self) -> Self:
        return self * other.inverse()

    def __eq__(self, other: Self) -> Bool:
        if self.rejected or other.rejected:
            return False
        for k in range(len(self.c)):
            if not self.c[k].eq(other.c[k]):
                return False
        return True

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    # C2: the Galois action, and what it gives.

    def galois(self, e: Int) -> Self:
        """sigma_e(zeta) = zeta^e; rejects unless gcd(e, q) = 1."""
        if self.rejected or _gcd(e, Self.q) != 1:
            return Self.refused()
        var v = List[Q](length=Self.q, fill=Q.zero())
        var em = e % Self.q
        for i in range(len(self.c)):
            var slot = (em * i) % Self.q
            v[slot] = v[slot].add(self.c[i])
        return Self.from_poly(v)

    def rational_part(self) -> Q:
        """self as a rational, rejecting unless every irrational coordinate vanishes."""
        if self.rejected:
            return q_rejected()
        for k in range(1, len(self.c)):
            if not self.c[k].num.is_zero():
                return q_rejected()
        return self.c[0].copy()

    def norm(self) -> Q:
        """N(a) = prod_e sigma_e(a), a rational."""
        var acc = Self.rational(Q.one())
        for e in units(Self.q):
            acc = acc * self.galois(e)
        return acc.rational_part()

    def trace(self) -> Q:
        """Tr(a) = sum_e sigma_e(a), a rational."""
        var acc = Self.rational(Q.zero())
        for e in units(Self.q):
            acc = acc + self.galois(e)
        return acc.rational_part()

    def inverse(self) -> Self:
        """a^-1 = prod_{e != 1} sigma_e(a) / N(a); zero and rejected values reject."""
        if self.rejected or self.is_zero():
            return Self.refused()
        var co = Self.rational(Q.one())
        for e in units(Self.q):
            if e % Self.q != 1 % Self.q:
                co = co * self.galois(e)
        var n = (self * co).rational_part()
        if not n.accepted() or n.num.is_zero():
            return Self.refused()
        return Self([x.div(n) for x in co.c], False)

    # Canonical encoding and display.

    def canonical_bytes(self) -> CycCanonicalBytes:
        """Z(q) || Q(c_0) || ... || Q(c_{phi(q)-1}) (docs/canonical-encoding.md)."""
        var refused = CycCanonicalBytes(List[UInt8](), True)
        if self.rejected:
            return refused^
        var head = bigz_canonical_bytes(bigz_from_i64(Int64(Self.q)))
        if head.rejected:
            return refused^
        var out = head.bytes.copy()
        for x in self.c:
            var enc = q_canonical_bytes(x)
            if enc.rejected:
                return refused^
            out.extend(enc.bytes.copy())
        return CycCanonicalBytes(out^, False)

    def write_to(self, mut writer: Some[Writer]):
        if self.rejected:
            writer.write("Cyc[", Self.q, "](rejected)")
            return
        writer.write("Cyc[", Self.q, "](")
        for k in range(len(self.c)):
            if k > 0:
                writer.write(", ")
            writer.write(_z_text(self.c[k].num))
            if not (self.c[k].den.limb_count() == 1 and self.c[k].den.limb(0) == 1):
                writer.write("/", _z_text(self.c[k].den))
        writer.write(")")


def _z_text(z: BigZ) -> String:
    """Decimal digits of z from its base-10^9 limbs, for diagnostics only."""
    if z.is_zero():
        return "0"
    var out = String("-") if z.sign < 0 else String()
    var top = z.limb_count() - 1
    out += String(z.limb(top))
    for k in range(top - 1, -1, -1):
        var digits = String(z.limb(k))
        out += "0" * (9 - digits.byte_length()) + digits
    return out


struct CyclotomicField[q: Int](ExactField):
    """Q(zeta_q), with elements Cyc[q]; each operation forwards to Cyc."""

    comptime Element = Cyc[Self.q]

    @staticmethod
    def zero() -> Cyc[Self.q]:
        return Cyc[Self.q].rational(Q.zero())

    @staticmethod
    def one() -> Cyc[Self.q]:
        return Cyc[Self.q].rational(Q.one())

    @staticmethod
    def from_int(n: Int64) -> Cyc[Self.q]:
        return Cyc[Self.q].rational(Q.from_int(n))

    @staticmethod
    def rejected() -> Cyc[Self.q]:
        return Cyc[Self.q].refused()

    @staticmethod
    def accepted(a: Cyc[Self.q]) -> Bool:
        return a.accepted()

    @staticmethod
    def is_zero(a: Cyc[Self.q]) -> Bool:
        return a.is_zero()

    @staticmethod
    def neg(a: Cyc[Self.q]) -> Cyc[Self.q]:
        return -a

    @staticmethod
    def add(a: Cyc[Self.q], b: Cyc[Self.q]) -> Cyc[Self.q]:
        return a + b

    @staticmethod
    def sub(a: Cyc[Self.q], b: Cyc[Self.q]) -> Cyc[Self.q]:
        return a - b

    @staticmethod
    def mul(a: Cyc[Self.q], b: Cyc[Self.q]) -> Cyc[Self.q]:
        return a * b

    @staticmethod
    def div(a: Cyc[Self.q], b: Cyc[Self.q]) -> Cyc[Self.q]:
        return a / b

    @staticmethod
    def eq(a: Cyc[Self.q], b: Cyc[Self.q]) -> Bool:
        return a == b
