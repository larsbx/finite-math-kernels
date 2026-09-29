# fp.mojo
#
# Fp[p]: elements of the prime field Z/pZ, with the modulus as a compile-time
# parameter so elements of different fields cannot be mixed; FpField[p] is the
# field itself, the ExactField instance over Fp[p]. Elements are canonical
# residues 0 <= v < p; the modulus is checked prime at compile time and kept
# below 2^31 so every product fits in Int64. Division by zero rejects, and
# rejection is sticky, exactly as for Q.

from finite_exact.field import ExactField

comptime FP_MODULUS_BOUND: Int64 = 2147483648


def fp_modulus_ok(p: Int64) -> Bool:
    """p is a prime below 2^31 (trial division; evaluated at compile time)."""
    if p < 2 or p >= FP_MODULUS_BOUND:
        return False
    var d: Int64 = 2
    while d * d <= p:
        if p % d == 0:
            return False
        d += 1
    return True


struct Fp[p: Int64](Copyable, Writable):
    var v: Int64
    var rejected: Bool

    def __init__(out self, n: Int64):
        comptime assert fp_modulus_ok(Self.p), "Fp modulus must be a prime below 2^31"
        self.v = n % Self.p  # floored: 0 <= v < p for every n
        self.rejected = False

    @staticmethod
    def zero() -> Self:
        return Self(0)

    @staticmethod
    def one() -> Self:
        return Self(1)

    @staticmethod
    def rejected_value() -> Self:
        var out = Self(0)
        out.rejected = True
        return out^

    def accepted(self) -> Bool:
        return not self.rejected

    def is_zero(self) -> Bool:
        return not self.rejected and self.v == 0

    def __neg__(self) -> Self:
        if self.rejected:
            return Self.rejected_value()
        return Self(-self.v)

    def __add__(self, other: Self) -> Self:
        if self.rejected or other.rejected:
            return Self.rejected_value()
        return Self(self.v + other.v)

    def __sub__(self, other: Self) -> Self:
        if self.rejected or other.rejected:
            return Self.rejected_value()
        return Self(self.v - other.v)

    def __mul__(self, other: Self) -> Self:
        if self.rejected or other.rejected:
            return Self.rejected_value()
        return Self(self.v * other.v)

    def inverse(self) -> Self:
        """a^-1 by the extended Euclidean algorithm; zero rejects."""
        if self.rejected or self.v == 0:
            return Self.rejected_value()
        var r0 = Self.p
        var r1 = self.v
        var s0: Int64 = 0
        var s1: Int64 = 1
        while r1 != 0:
            var k = r0 // r1
            (r0, r1) = (r1, r0 - k * r1)
            (s0, s1) = (s1, s0 - k * s1)
        return Self(s0)

    def __truediv__(self, other: Self) -> Self:
        return self * other.inverse()

    def __eq__(self, other: Self) -> Bool:
        """Equal accepted residues; False whenever either side is rejected."""
        return not self.rejected and not other.rejected and self.v == other.v

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def write_to(self, mut writer: Some[Writer]):
        if self.rejected:
            writer.write("Fp[", Self.p, "](rejected)")
        else:
            writer.write(self.v, " mod ", Self.p)


struct FpField[p: Int64](ExactField):
    """The prime field F_p, with elements Fp[p]."""

    comptime Element = Fp[Self.p]

    @staticmethod
    def zero() -> Fp[Self.p]:
        return Fp[Self.p].zero()

    @staticmethod
    def one() -> Fp[Self.p]:
        return Fp[Self.p].one()

    @staticmethod
    def from_int(n: Int64) -> Fp[Self.p]:
        return Fp[Self.p](n)

    @staticmethod
    def rejected() -> Fp[Self.p]:
        return Fp[Self.p].rejected_value()

    @staticmethod
    def accepted(a: Fp[Self.p]) -> Bool:
        return a.accepted()

    @staticmethod
    def is_zero(a: Fp[Self.p]) -> Bool:
        return a.is_zero()

    @staticmethod
    def neg(a: Fp[Self.p]) -> Fp[Self.p]:
        return -a

    @staticmethod
    def add(a: Fp[Self.p], b: Fp[Self.p]) -> Fp[Self.p]:
        return a + b

    @staticmethod
    def sub(a: Fp[Self.p], b: Fp[Self.p]) -> Fp[Self.p]:
        return a - b

    @staticmethod
    def mul(a: Fp[Self.p], b: Fp[Self.p]) -> Fp[Self.p]:
        return a * b

    @staticmethod
    def div(a: Fp[Self.p], b: Fp[Self.p]) -> Fp[Self.p]:
        return a / b

    @staticmethod
    def eq(a: Fp[Self.p], b: Fp[Self.p]) -> Bool:
        return a == b
