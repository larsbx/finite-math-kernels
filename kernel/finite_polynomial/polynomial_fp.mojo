# polynomial_fp.mojo
#
# Univariate polynomials over Z/m with a run-time modulus, and over F_p when
# m is prime: ring operations, division with remainder, gcd and Bezout
# cofactors, modular powers, and the Frobenius map h -> h^p mod f as a linear
# map. The named algorithms built on this arithmetic have modules of their own:
#
#   miller_rabin           deterministic primality below 2^31
#   distinct_degree        distinct-degree factorization (Cantor-Zassenhaus)
#   rabin_irreducibility   Rabin's irreducibility test and its certificate
#   hensel_lifting         one Hensel step from a simple root mod p to mod p^2
#
# finite_exact.fp is the compile-time-modulus element type. This module is for
# certificates that range over a list of primes chosen at run time, and keeps
# fp's arithmetic contract at run time:
#
# Overflow. A Modulus is admitted only below FP_MODULUS_BOUND = 2^31, and every
# residue a PolyFp stores is canonical, 0 <= r < m. A product of two residues
# is then below 2^62, and a product plus a residue below 2^63, so every product
# here is exact in Int by that invariant. Integer inputs of any size (Int by
# floored remainder, BigZ limb by limb) are reduced before they meet a product;
# nothing multiplies two unreduced integers.
#
# Failure. An impossible question raises: a modulus out of range, a non-unit
# inverse, division by zero, operands over different moduli, a field
# algorithm over a composite modulus. Nothing returns a wrong value. What an
# accepted value proves (about Z[x], about a dynamical relation) is the
# consumer's decision.
#
# reference/polynomial_fp_reference.py is the independent Python oracle;
# tests/finite_polynomial/test_polynomial_fp.mojo and its _reference.py twin
# assert the same pinned values.

from finite_exact.bigint_z import BigZ, bigz_abs_mod_small
from finite_exact.fp import FP_MODULUS_BOUND
from finite_polynomial.miller_rabin import is_prime
from finite_polynomial.polynomial_z import PolyZ

comptime MODULUS_BOUND = Int(FP_MODULUS_BOUND)


# --- residues ------------------------------------------------------------------
# The underscore helpers take canonical residues below n < 2^31 only.


def _add(a: Int, b: Int, n: Int) -> Int:
    var s = a + b
    return s - n if s >= n else s


def _sub(a: Int, b: Int, n: Int) -> Int:
    var s = a - b
    return s + n if s < 0 else s


def _mul(a: Int, b: Int, n: Int) -> Int:
    return a * b % n


struct Modulus(ImplicitlyCopyable, Writable):
    """Z/n for 2 <= n < 2^31; `prime` records whether it is the field F_n."""

    var n: Int
    var prime: Bool

    def __init__(out self, n: Int) raises:
        if n < 2 or n >= MODULUS_BOUND:
            raise Error("modulus must satisfy 2 <= m < 2^31")
        self.n = n
        self.prime = is_prime(n)

    def reduce(self, x: Int) -> Int:
        """The canonical residue of any Int (Int % is floored)."""
        return x % self.n

    def reduce_bigz(self, x: BigZ) -> Int:
        var r = Int(bigz_abs_mod_small(x, UInt64(self.n)))
        return self.reduce(-r) if x.sign < 0 else r

    def add(self, a: Int, b: Int) -> Int:
        return _add(self.reduce(a), self.reduce(b), self.n)

    def sub(self, a: Int, b: Int) -> Int:
        return _sub(self.reduce(a), self.reduce(b), self.n)

    def mul(self, a: Int, b: Int) -> Int:
        return _mul(self.reduce(a), self.reduce(b), self.n)

    def pow(self, a: Int, e: Int) raises -> Int:
        if e < 0:
            raise Error("negative exponent")
        var result = 1 % self.n
        var base = self.reduce(a)
        var k = e
        while k > 0:
            if k % 2 == 1:
                result = _mul(result, base, self.n)
            base = _mul(base, base, self.n)
            k //= 2
        return result

    def inverse(self, a: Int) raises -> Int:
        """a^-1 by the extended Euclidean algorithm; a non-unit raises. The
        cofactors stay below 2n in magnitude, so k * s stays below 2^63."""
        var r0 = self.n
        var r1 = self.reduce(a)
        var s0 = 0
        var s1 = 1
        while r1 != 0:
            var k = r0 // r1
            (r0, r1) = (r1, r0 - k * r1)
            (s0, s1) = (s1, s0 - k * s1)
        if r0 != 1:
            raise Error("not a unit modulo " + String(self.n))
        return self.reduce(s0)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Z/", self.n)


def prime_field(p: Int) raises -> Modulus:
    """F_p: a Modulus that is checked prime."""
    var m = Modulus(p)
    if not m.prime:
        raise Error(String(p) + " is not prime")
    return m


# --- polynomials ---------------------------------------------------------------


struct PolyFp(Copyable, Movable, Writable):
    """A polynomial over Z/m: canonical residues, low degree first, no trailing
    zero; the zero polynomial has no coefficients and degree -1."""

    var modulus: Modulus
    var coeffs: List[Int]

    def __init__(out self, modulus: Modulus, var coefficients: List[Int]):
        for i in range(len(coefficients)):
            coefficients[i] = modulus.reduce(coefficients[i])
        while len(coefficients) > 0 and coefficients[len(coefficients) - 1] == 0:
            _ = coefficients.pop()
        self.modulus = modulus
        self.coeffs = coefficients^

    def degree(self) -> Int:
        return len(self.coeffs) - 1

    def is_zero(self) -> Bool:
        return len(self.coeffs) == 0

    def coefficient(self, i: Int) -> Int:
        return self.coeffs[i] if 0 <= i and i < len(self.coeffs) else 0

    def lead(self) -> Int:
        return self.coefficient(self.degree())

    def write_to(self, mut writer: Some[Writer]):
        writer.write("[")
        for i in range(len(self.coeffs)):
            if i > 0:
                writer.write(", ")
            writer.write(self.coeffs[i])
        writer.write("] mod ", self.modulus.n)


def poly_fp_from_bigz(modulus: Modulus, coefficients: List[BigZ]) -> PolyFp:
    var out = List[Int](capacity=len(coefficients))
    for c in coefficients:
        out.append(modulus.reduce_bigz(c))
    return PolyFp(modulus, out^)


def poly_fp_reduce(f: PolyZ, modulus: Modulus) raises -> PolyFp:
    """The image of a BigZ polynomial (finite_polynomial.polynomial_z) in Z/m[x]."""
    if f.rejected:
        raise Error("rejected polynomial")
    return poly_fp_from_bigz(modulus, f.coeffs)


def poly_fp_constant(modulus: Modulus, c: Int) -> PolyFp:
    return PolyFp(modulus, [c])


def poly_fp_x(modulus: Modulus) -> PolyFp:
    return PolyFp(modulus, [0, 1])


def require_same_modulus(a: PolyFp, b: PolyFp) raises:
    """Raise unless a and b are over the same modulus."""
    if a.modulus.n != b.modulus.n:
        raise Error("polynomials over different moduli")


def require_field(f: PolyFp) raises:
    """Raise unless f is over a prime modulus: the field algorithms need F_p."""
    if not f.modulus.prime:
        raise Error("field algorithm over the composite modulus " + String(f.modulus.n))


def poly_fp_equal(a: PolyFp, b: PolyFp) -> Bool:
    if a.modulus.n != b.modulus.n or len(a.coeffs) != len(b.coeffs):
        return False
    for i in range(len(a.coeffs)):
        if a.coeffs[i] != b.coeffs[i]:
            return False
    return True


def poly_fp_add(a: PolyFp, b: PolyFp) raises -> PolyFp:
    require_same_modulus(a, b)
    var n = a.modulus.n
    var out = List[Int](length=max(len(a.coeffs), len(b.coeffs)), fill=0)
    for i in range(len(out)):
        out[i] = _add(a.coefficient(i), b.coefficient(i), n)
    return PolyFp(a.modulus, out^)


def poly_fp_sub(a: PolyFp, b: PolyFp) raises -> PolyFp:
    require_same_modulus(a, b)
    var n = a.modulus.n
    var out = List[Int](length=max(len(a.coeffs), len(b.coeffs)), fill=0)
    for i in range(len(out)):
        out[i] = _sub(a.coefficient(i), b.coefficient(i), n)
    return PolyFp(a.modulus, out^)


def poly_fp_scale(a: PolyFp, c: Int) -> PolyFp:
    var k = a.modulus.reduce(c)
    var out = List[Int](capacity=len(a.coeffs))
    for x in a.coeffs:
        out.append(_mul(x, k, a.modulus.n))
    return PolyFp(a.modulus, out^)


def poly_fp_mul(a: PolyFp, b: PolyFp) raises -> PolyFp:
    require_same_modulus(a, b)
    if a.is_zero() or b.is_zero():
        return PolyFp(a.modulus, [])
    var n = a.modulus.n
    var out = List[Int](length=len(a.coeffs) + len(b.coeffs) - 1, fill=0)
    for i in range(len(a.coeffs)):
        var x = a.coeffs[i]
        if x != 0:
            for j in range(len(b.coeffs)):
                out[i + j] = (out[i + j] + x * b.coeffs[j]) % n
    return PolyFp(a.modulus, out^)


struct PolyFpDivMod(Movable):
    var quotient: PolyFp
    var remainder: PolyFp

    def __init__(out self, var quotient: PolyFp, var remainder: PolyFp):
        self.quotient = quotient^
        self.remainder = remainder^


def poly_fp_divmod(a: PolyFp, b: PolyFp) raises -> PolyFpDivMod:
    """a = q b + r with deg r < deg b; b must have a unit leading coefficient."""
    require_same_modulus(a, b)
    if b.is_zero():
        raise Error("polynomial division by zero")
    var n = a.modulus.n
    var inverse = a.modulus.inverse(b.lead())
    var db = b.degree()
    if a.degree() < db:
        return PolyFpDivMod(PolyFp(a.modulus, []), a.copy())
    var r = a.coeffs.copy()
    var q = List[Int](length=len(r) - db, fill=0)
    for i in range(len(r) - 1 - db, -1, -1):
        var c = _mul(r[i + db], inverse, n)
        q[i] = c
        if c != 0:
            for j in range(db + 1):
                r[i + j] = _sub(r[i + j], _mul(c, b.coeffs[j], n), n)
    r.resize(db, 0)
    return PolyFpDivMod(PolyFp(a.modulus, q^), PolyFp(a.modulus, r^))


def poly_fp_rem(a: PolyFp, b: PolyFp) raises -> PolyFp:
    return poly_fp_divmod(a, b).remainder.copy()


def poly_fp_quo(a: PolyFp, b: PolyFp) raises -> PolyFp:
    return poly_fp_divmod(a, b).quotient.copy()


def poly_fp_monic(a: PolyFp) raises -> PolyFp:
    if a.is_zero():
        raise Error("the zero polynomial has no monic associate")
    return poly_fp_scale(a, a.modulus.inverse(a.lead()))


def poly_fp_derivative(a: PolyFp) -> PolyFp:
    var out = List[Int](capacity=max(len(a.coeffs) - 1, 0))
    for i in range(1, len(a.coeffs)):
        out.append(_mul(a.modulus.reduce(i), a.coeffs[i], a.modulus.n))
    return PolyFp(a.modulus, out^)


def poly_fp_eval(a: PolyFp, x: Int) -> Int:
    """a(x) mod m by Horner, for any Int x."""
    var n = a.modulus.n
    var v = a.modulus.reduce(x)
    var acc = 0
    for i in range(len(a.coeffs) - 1, -1, -1):
        acc = (acc * v + a.coeffs[i]) % n
    return acc


def poly_fp_root_count(a: PolyFp) -> Int:
    """The number of residues r with a(r) = 0, by evaluation at every residue:
    O(m deg a), and independent of every factorization routine here."""
    var count = 0
    for r in range(a.modulus.n):
        if poly_fp_eval(a, r) == 0:
            count += 1
    return count


struct PolyFpBezout(Movable):
    """gcd = s a + t b, with gcd monic (or zero when a = b = 0)."""

    var gcd: PolyFp
    var s: PolyFp
    var t: PolyFp

    def __init__(out self, var gcd: PolyFp, var s: PolyFp, var t: PolyFp):
        self.gcd = gcd^
        self.s = s^
        self.t = t^


def poly_fp_xgcd(a: PolyFp, b: PolyFp) raises -> PolyFpBezout:
    require_same_modulus(a, b)
    require_field(a)
    var r0 = a.copy()
    var r1 = b.copy()
    var s0 = poly_fp_constant(a.modulus, 1)
    var s1 = PolyFp(a.modulus, [])
    var t0 = PolyFp(a.modulus, [])
    var t1 = poly_fp_constant(a.modulus, 1)
    while not r1.is_zero():
        var qr = poly_fp_divmod(r0, r1)
        var s2 = poly_fp_sub(s0, poly_fp_mul(qr.quotient, s1))
        var t2 = poly_fp_sub(t0, poly_fp_mul(qr.quotient, t1))
        r0 = r1^
        r1 = qr.remainder.copy()
        s0 = s1^
        s1 = s2^
        t0 = t1^
        t1 = t2^
    if r0.is_zero():
        return PolyFpBezout(r0^, s1^, t1^)
    var u = a.modulus.inverse(r0.lead())
    return PolyFpBezout(poly_fp_scale(r0, u), poly_fp_scale(s0, u), poly_fp_scale(t0, u))


def poly_fp_gcd(a: PolyFp, b: PolyFp) raises -> PolyFp:
    """The monic gcd over F_p; gcd(0, 0) = 0."""
    require_same_modulus(a, b)
    require_field(a)
    var x = a.copy()
    var y = b.copy()
    while not y.is_zero():
        var r = poly_fp_rem(x, y)
        x = y^
        y = r^
    return x^ if x.is_zero() else poly_fp_monic(x)


def poly_fp_powmod(base: PolyFp, e: Int, f: PolyFp) raises -> PolyFp:
    """base^e mod f, e >= 0, by square and multiply."""
    require_same_modulus(base, f)
    if e < 0:
        raise Error("negative exponent")
    var result = poly_fp_rem(poly_fp_constant(f.modulus, 1), f)
    var b = poly_fp_rem(base, f)
    var k = e
    while k > 0:
        if k % 2 == 1:
            result = poly_fp_rem(poly_fp_mul(result, b), f)
        b = poly_fp_rem(poly_fp_mul(b, b), f)
        k //= 2
    return result^


def poly_fp_frobenius_power(f: PolyFp, k: Int) raises -> PolyFp:
    """x^(p^k) mod f, k >= 0, by k p-th powers (square and multiply, no
    Frobenius matrix)."""
    require_field(f)
    if k < 0:
        raise Error("negative exponent")
    var h = poly_fp_rem(poly_fp_x(f.modulus), f)
    for _ in range(k):
        h = poly_fp_powmod(h, f.modulus.n, f)
    return h^


struct FrobeniusMap(Movable):
    """h -> h^p mod f as the F_p-linear map it is: rows[j] = x^(p j) mod f."""

    var f: PolyFp
    var rows: List[PolyFp]

    def __init__(out self, f: PolyFp) raises:
        require_field(f)
        if f.degree() < 1:
            raise Error("Frobenius map modulo a constant")
        self.f = f.copy()
        var xp = poly_fp_powmod(poly_fp_x(f.modulus), f.modulus.n, f)
        self.rows = [poly_fp_constant(f.modulus, 1)]
        for j in range(1, f.degree()):
            self.rows.append(poly_fp_rem(poly_fp_mul(self.rows[j - 1], xp), f))

    def apply(self, h: PolyFp) raises -> PolyFp:
        var reduced = poly_fp_rem(h, self.f)
        var n = self.f.modulus.n
        var out = List[Int](length=self.f.degree(), fill=0)
        for j in range(len(reduced.coeffs)):
            var c = reduced.coeffs[j]
            if c != 0:
                var row = self.rows[j].coeffs.copy()
                for t in range(len(row)):
                    out[t] = (out[t] + c * row[t]) % n
        return PolyFp(self.f.modulus, out^)


def poly_fp_is_squarefree(f: PolyFp) raises -> Bool:
    """f is nonzero and coprime to f' over F_p."""
    return not f.is_zero() and poly_fp_gcd(f, poly_fp_derivative(f)).degree() == 0
