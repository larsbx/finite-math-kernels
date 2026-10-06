# cyclotomic_field.mojo
#
# Q(zeta_q) for the field-generic kernels. The arithmetic is `cyclotomic_q`'s;
# this module only types it.
#
#   Cyc[q]               a CyclotomicQ whose conductor q is a compile-time
#                        parameter, so elements of different cyclotomic fields
#                        do not type-check together, with operators + - * / ==,
#                        the Galois action, trace and norm to Q.
#   CyclotomicField[q]   the finite_exact.field.ExactField over Cyc[q], so
#                        projective_limits and its rotor module run over Q(zeta_q).
#   CyclotomicRing       Q(zeta_n) for a conductor known only at run time, as a
#                        coefficient_ring.CoefficientField over CyclotomicQ, so
#                        truncated jets run over it.
#
# The compiler checks deg Phi_q = phi(q) for every conductor instantiated.
# Rejection is sticky, and == is False whenever either side is rejected. No
# angle, trigonometric function or floating-point number appears.
#
# Specification: docs/rational-interval-arithmetic-spec.md (coefficients are Q).

from finite_exact.exact_decimal import q_decimal
from finite_exact.field import ExactField
from finite_exact.bigint_z import bigz_eq, bigz_from_i64, bigz_gcd
from finite_exact.rat_q import Q, q_rejected
from finite_polynomial.coefficient_ring import CoefficientField
from finite_polynomial.cyclotomic_q import (
    CyclotomicCanonicalBytes,
    CyclotomicQ,
    cyclotomic_add,
    cyclotomic_automorphism,
    cyclotomic_canonical_bytes,
    cyclotomic_div,
    cyclotomic_equal,
    cyclotomic_from_coeffs,
    cyclotomic_inverse,
    cyclotomic_is_zero,
    cyclotomic_mul,
    cyclotomic_neg,
    cyclotomic_one,
    cyclotomic_pow,
    cyclotomic_sub,
    cyclotomic_zero,
    rejected_cyclotomic,
    zeta,
)
from finite_polynomial.polynomial_z import cyclotomic_degree


def _coprime(a: Int, b: Int) -> Bool:
    # This predicate is also evaluated at compile time for Cyc.DEGREE.
    # Reuse the unbounded canonical GCD to keep this field API non-raising.
    return bigz_eq(
        bigz_gcd(bigz_from_i64(Int64(a)), bigz_from_i64(Int64(b))),
        bigz_from_i64(1),
    )


def euler_phi(n: Int) -> Int:
    var count = 0
    for k in range(1, n + 1):
        if _coprime(k, n):
            count += 1
    return count


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


def units(q: Int) -> List[Int]:
    """The exponents 1 <= e <= q with gcd(e, q) = 1: the Galois group of Q(zeta_q)."""
    return [e for e in range(1, q + 1) if _coprime(e, q)]


struct Cyc[q: Int](Copyable, Writable):
    """An element of Q(zeta_q): a CyclotomicQ of conductor q, typed by q."""

    comptime DEGREE = euler_phi(Self.q)

    var value: CyclotomicQ

    def __init__(out self, value: CyclotomicQ):
        """Adopt `value` as an element of Q(zeta_q). The only constructor: a value
        of any other conductor, or a rejected one, becomes a rejected Cyc[q]."""
        comptime assert Self.q >= 1, "conductor must be positive"
        comptime assert cyclotomic_degree(Self.q) == Self.DEGREE, "deg Phi_q != phi(q)"
        if value.rejected or value.conductor != Self.q:
            self.value = rejected_cyclotomic()
        else:
            self.value = value.copy()

    @staticmethod
    def refused() -> Self:
        return Self(rejected_cyclotomic())

    @staticmethod
    def from_poly(coefficients: List[Q]) -> Self:
        """The class of sum c_k X^k modulo Phi_q."""
        return Self(cyclotomic_from_coeffs(Self.q, coefficients))

    @staticmethod
    def rational(r: Q) -> Self:
        return Self.from_poly([r.copy()])

    @staticmethod
    def zeta(k: Int = 1) -> Self:
        """zeta_q^k for any integer k."""
        return Self(cyclotomic_pow(zeta(Self.q), k % Self.q))

    def accepted(self) -> Bool:
        return not self.value.rejected

    def is_zero(self) -> Bool:
        return self.accepted() and cyclotomic_is_zero(self.value)

    def coefficients(self) -> List[Q]:
        """Coordinates on 1, zeta, ..., zeta^(phi(q)-1); empty when rejected."""
        return self.value.coeffs.copy() if self.accepted() else List[Q]()

    def __neg__(self) -> Self:
        return Self(cyclotomic_neg(self.value))

    def __add__(self, other: Self) -> Self:
        return Self(cyclotomic_add(self.value, other.value))

    def __sub__(self, other: Self) -> Self:
        return Self(cyclotomic_sub(self.value, other.value))

    def __mul__(self, other: Self) -> Self:
        return Self(cyclotomic_mul(self.value, other.value))

    def __truediv__(self, other: Self) -> Self:
        return Self(cyclotomic_div(self.value, other.value))

    def __eq__(self, other: Self) -> Bool:
        return self.accepted() and other.accepted() and cyclotomic_equal(self.value, other.value)

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def inverse(self) -> Self:
        return Self(cyclotomic_inverse(self.value))

    def galois(self, e: Int) -> Self:
        """sigma_e(zeta) = zeta^e for any integer e coprime to q (reduced mod q first)."""
        return Self(cyclotomic_automorphism(self.value, e % Self.q))

    def rational_part(self) -> Q:
        """self as a rational, rejecting unless every irrational coordinate vanishes."""
        if not self.accepted():
            return q_rejected()
        for k in range(1, len(self.value.coeffs)):
            if not self.value.coeffs[k].num.is_zero():
                return q_rejected()
        return self.value.coeffs[0].copy()

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

    def canonical_bytes(self) -> CyclotomicCanonicalBytes:
        return cyclotomic_canonical_bytes(self.value)

    def write_to(self, mut writer: Some[Writer]):
        if not self.accepted():
            writer.write("Cyc[", Self.q, "](rejected)")
            return
        writer.write("Cyc[", Self.q, "](")
        for k in range(len(self.value.coeffs)):
            if k > 0:
                writer.write(", ")
            writer.write(q_decimal(self.value.coeffs[k]))
        writer.write(")")


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


struct CyclotomicRing(CoefficientField):
    """Q(zeta_n), n fixed at run time, over CyclotomicQ.

    An element of another conductor is not accepted here, and every operation
    on one is rejected; a conductor below 1 accepts nothing.
    """

    comptime Element = CyclotomicQ
    var conductor: Int

    def __init__(out self, conductor: Int):
        self.conductor = conductor

    def zero(self) -> CyclotomicQ:
        return cyclotomic_zero(self.conductor)

    def one(self) -> CyclotomicQ:
        return cyclotomic_one(self.conductor)

    def rejected(self) -> CyclotomicQ:
        return rejected_cyclotomic()

    def accepted(self, a: CyclotomicQ) -> Bool:
        return a.accepted() and a.conductor == self.conductor

    def is_zero(self, a: CyclotomicQ) -> Bool:
        return self.accepted(a) and cyclotomic_is_zero(a)

    def _own(self, a: CyclotomicQ) -> CyclotomicQ:
        return a.copy() if self.accepted(a) else rejected_cyclotomic()

    def add(self, a: CyclotomicQ, b: CyclotomicQ) -> CyclotomicQ:
        return self._own(cyclotomic_add(a, b))

    def sub(self, a: CyclotomicQ, b: CyclotomicQ) -> CyclotomicQ:
        return self._own(cyclotomic_sub(a, b))

    def mul(self, a: CyclotomicQ, b: CyclotomicQ) -> CyclotomicQ:
        return self._own(cyclotomic_mul(a, b))

    def inverse(self, a: CyclotomicQ) -> CyclotomicQ:
        return self._own(cyclotomic_inverse(a))
