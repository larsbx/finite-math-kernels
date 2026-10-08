# rational.mojo
#
# Exact rational-address combinatorics over the unbounded BigZ backend.
#
# A ReducedFraction is a canonical nonnegative rational p/q with q > 0 and
# gcd(p,q) = 1. It is an ordinary rational fraction, not implicitly a point of
# Q/Z. Operations that need Q/Z semantics, such as double_mod_one, say so
# explicitly and reduce modulo the denominator at that boundary.
#
# No operation in this package measures an angle or interprets a fraction as
# a dynamical object. Consumers own those meanings.
#
# The named objects built on ReducedFraction live in modules named after them,
# each citing its source, and are re-exported here unchanged:
# continued_fractions.mojo (continued fractions and convergents) and
# farey.mojo (the Farey determinant and adjacency).

from finite_exact.bigint_z import (
    BigZ,
    bigz_abs,
    bigz_add,
    bigz_div_exact,
    bigz_divmod,
    bigz_eq,
    bigz_from_i64,
    bigz_gcd,
    bigz_is_canonical,
    bigz_lt,
    bigz_mul,
    bigz_sub,
    bigz_zero,
)
from rational_dynamics.continued_fractions import (
    ContinuedFractionResult,
    ConvergentsResult,
    continued_fraction,
    convergents,
    rejected_cf,
    rejected_convergents,
)
from rational_dynamics.farey import farey_adjacent, farey_determinant


struct ReducedFraction(Copyable):
    var num: BigZ
    var den: BigZ
    var rejected: Bool

    def __init__(out self):
        self.num = bigz_zero()
        self.den = bigz_from_i64(1)
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


struct SignedFraction(Copyable):
    """A reduced signed numerator over a positive denominator.

    Used for the centered modular-inverse representative. The numerator lies
    in (-q/2, q/2] when accepted.
    """

    var num: BigZ
    var den: BigZ
    var rejected: Bool

    def __init__(out self):
        self.num = bigz_zero()
        self.den = bigz_from_i64(1)
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


struct BigZResult(Copyable):
    var value: BigZ
    var rejected: Bool

    def __init__(out self):
        self.value = bigz_zero()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_fraction() -> ReducedFraction:
    var out = ReducedFraction()
    out.rejected = True
    return out^


def rejected_signed_fraction() -> SignedFraction:
    var out = SignedFraction()
    out.rejected = True
    return out^


def rejected_bigz_result() -> BigZResult:
    var out = BigZResult()
    out.rejected = True
    return out^


def _nonnegative_mod(value: BigZ, modulus: BigZ) -> BigZ:
    """Canonical remainder in [0, modulus), for positive modulus."""
    var division = bigz_divmod(value, modulus)
    if division.rejected:
        return bigz_zero()
    var remainder = division.remainder.copy()
    if remainder.sign < 0:
        remainder = bigz_add(remainder, modulus)
    return remainder^


def reduce_fraction(numerator: BigZ, denominator: BigZ) -> ReducedFraction:
    """Normalize a nonnegative rational fraction exactly.

    Negative numerators and nonpositive denominators are outside this package's
    address/combinatorics boundary and reject rather than being reinterpreted.
    """
    if not bigz_is_canonical(numerator) or not bigz_is_canonical(denominator):
        return rejected_fraction()
    if numerator.sign < 0 or denominator.sign <= 0:
        return rejected_fraction()

    var common = bigz_gcd(numerator, denominator)
    var n = bigz_div_exact(numerator, common)
    var d = bigz_div_exact(denominator, common)
    if n.rejected or d.rejected:
        return rejected_fraction()

    var out = ReducedFraction()
    out.num = n.quotient.copy()
    out.den = d.quotient.copy()
    return out^


def fraction_from_i64(numerator: Int64, denominator: Int64) -> ReducedFraction:
    return reduce_fraction(bigz_from_i64(numerator), bigz_from_i64(denominator))


def fraction_equal(left: ReducedFraction, right: ReducedFraction) -> Bool:
    return (
        not left.rejected and not right.rejected and
        bigz_eq(left.num, right.num) and bigz_eq(left.den, right.den)
    )


def double_mod_one(value: ReducedFraction) -> ReducedFraction:
    """The doubling map on the class of value modulo one."""
    if value.rejected:
        return rejected_fraction()
    var doubled = bigz_mul(value.num, bigz_from_i64(2))
    var remainder = _nonnegative_mod(doubled, value.den)
    return reduce_fraction(remainder, value.den)


def mod_inverse(value: ReducedFraction) -> ReducedFraction:
    """p^(-1) / q with the inverse numerator in [1,q), or rejection.

    The inverse is taken modulo q. A zero residue (including modulus one) has
    no inverse in this contract.
    """
    if value.rejected:
        return rejected_fraction()
    var residue = _nonnegative_mod(value.num, value.den)
    if residue.is_zero():
        return rejected_fraction()
    if not bigz_eq(bigz_gcd(residue, value.den), bigz_from_i64(1)):
        return rejected_fraction()

    # Extended Euclid on positive (den, residue).
    var t = bigz_zero()
    var new_t = bigz_from_i64(1)
    var r = value.den.copy()
    var new_r = residue.copy()

    while not new_r.is_zero():
        var division = bigz_divmod(r, new_r)
        if division.rejected:
            return rejected_fraction()
        var next_t = bigz_sub(t, bigz_mul(division.quotient, new_t))
        t = new_t.copy()
        new_t = next_t.copy()
        r = new_r.copy()
        new_r = division.remainder.copy()

    if not bigz_eq(r, bigz_from_i64(1)):
        return rejected_fraction()
    return reduce_fraction(_nonnegative_mod(t, value.den), value.den)


def signed_mod_inverse(value: ReducedFraction) -> SignedFraction:
    """Centered inverse representative in (-q/2, q/2]."""
    var inverse = mod_inverse(value)
    if inverse.rejected:
        return rejected_signed_fraction()

    var centered = inverse.num.copy()
    var twice = bigz_mul(centered, bigz_from_i64(2))
    if bigz_lt(inverse.den, twice):
        centered = bigz_sub(centered, inverse.den)

    var out = SignedFraction()
    out.num = centered.copy()
    out.den = inverse.den.copy()
    return out^
