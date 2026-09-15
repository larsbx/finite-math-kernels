# property_probe.mojo
#
# Specification: docs/rational-interval-arithmetic-spec.md (section 7).
# Public boundary: docs/exact-arithmetic-public-boundary.md.
#
# Executable property probe for the BigZ / Q public boundary. It draws
# deterministic pseudo-random operands, applies the public operations, and
# prints one transcript line per case using only the canonical byte encodings
# of docs/canonical-encoding.md. tools/property_oracle.py (run with
# `--layers zq`; the interval layer of the grammar is exercised by the
# larsbx/interval_q probe, which extends this one)
# regenerates the same operands from the same generator, recomputes every
# result with Python int and fractions.Fraction, and compares the transcripts
# token by token. No parser of Mojo output is trusted: the comparison is on
# canonical bytes and boolean codes only.
#
# The probe also runs two in-process self-checks per case: long division
# agrees with the retained shift-and-subtract reference, and every produced
# value is canonical. It prints PASS/FAIL codes for those instead of aborting,
# so the oracle sees the failing case.
#
# Transcript grammar (tokens separated by single spaces):
#   HEADER exact-arithmetic-property-probe 1 <seed> <z_cases> <q_cases> <i_cases>
#   Z <i> <a> <b> <a+b> <a-b> <a*b> <a<b> <a==b> <gcd> <q> <r> <selfcheck>
#   Q <i> <a> <b> <a+b> <a-b> <a*b> <a/b> <a<b> <a<=b> <a==b> <selfcheck>
#   (I lines, printed only by the interval_q probe, follow the Q lines)
# Integer and rational values are their canonical bytes as decimal octets
# joined by "."; a rejected value prints as "rejected"; booleans print 0/1.

from finite_exact.bigint_z import BIGZ_BASE, BigZ, BigZCanonicalBytes, bigz_abs_divmod, bigz_abs_divmod_shift_subtract, bigz_add, bigz_canonical_bytes, bigz_divmod, bigz_eq, bigz_from_i64, bigz_gcd, bigz_is_canonical, bigz_lt, bigz_mul, bigz_sub
from finite_exact.rat_q import Q, QCanonicalBytes, q_canonical_bytes, q_from_bigz, q_max, q_min

comptime PROBE_SEED = UInt64(11400714819323198485)
comptime PROBE_Z_CASES = 300
comptime PROBE_Q_CASES = 200
comptime PROBE_MAX_LIMBS = 6


struct Xorshift64Star(Copyable):
    # xorshift64* (Vigna). Wrapping UInt64 arithmetic; the Python oracle masks
    # to 64 bits at every step.
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        var x = self.state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        self.state = x
        return x * UInt64(2685821657736338717)


def random_bigz(mut rng: Xorshift64Star, max_limbs: Int) -> BigZ:
    # One draw in four is a small signed value near zero; the rest are random
    # limb vectors, with one limb in five forced to BIGZ_BASE - 1 to reach the
    # carry, borrow, and add-back branches of long division.
    var mode = rng.next() % 4
    if mode == 0:
        return bigz_from_i64(Int64(rng.next() % 2001) - 1000)
    var count = Int(rng.next() % UInt64(max_limbs)) + 1
    var out = BigZ()
    out.sign = 1
    for _ in range(count):
        var pick = rng.next()
        if pick % 5 == 0:
            out.limbs.append(BIGZ_BASE - 1)
        else:
            out.limbs.append(pick % BIGZ_BASE)
    out.normalize()
    if out.sign != 0 and rng.next() % 2 == 1:
        out.sign = -1
    return out^


def random_nonzero_bigz(mut rng: Xorshift64Star, max_limbs: Int) -> BigZ:
    var value = random_bigz(rng, max_limbs)
    if value.is_zero():
        return bigz_from_i64(1)
    return value^


def octets(bytes: List[UInt8], rejected: Bool) -> String:
    if rejected:
        return String("rejected")
    var out = String("")
    for idx in range(len(bytes)):
        if idx > 0:
            out += "."
        out += String(Int(bytes[idx]))
    return out^


def z_token(value: BigZ) -> String:
    var encoded = bigz_canonical_bytes(value)
    return octets(encoded.bytes, encoded.rejected)


def q_token(value: Q) -> String:
    var encoded = q_canonical_bytes(value)
    return octets(encoded.bytes, encoded.rejected)


def bool_token(value: Bool) -> String:
    return String("1") if value else String("0")


def divmod_tokens(dividend: BigZ, divisor: BigZ) -> String:
    var division = bigz_divmod(dividend, divisor)
    if division.rejected:
        return String("rejected rejected")
    return z_token(division.quotient) + " " + z_token(division.remainder)


def z_selfcheck(a: BigZ, b: BigZ, sum: BigZ, difference: BigZ, product: BigZ, common: BigZ) -> Bool:
    var long = bigz_abs_divmod(a, b)
    var reference = bigz_abs_divmod_shift_subtract(a, b)
    var division_agrees = (
        long.rejected == reference.rejected and
        bigz_eq(long.quotient, reference.quotient) and
        bigz_eq(long.remainder, reference.remainder)
    )
    return (
        division_agrees and
        bigz_is_canonical(sum) and bigz_is_canonical(difference) and
        bigz_is_canonical(product) and bigz_is_canonical(common)
    )


def q_selfcheck(values: List[Q]) -> Bool:
    for value in values:
        if value.rejected:
            continue
        if not bigz_is_canonical(value.num) or not bigz_is_canonical(value.den) or value.den.sign != 1:
            return False
        if bigz_gcd(value.num, value.den).limb_count() > 0 and not bigz_eq(bigz_gcd(value.num, value.den), bigz_from_i64(1)):
            return False
    return True


def print_z_case(index: Int, a: BigZ, b: BigZ):
    var sum = bigz_add(a, b)
    var difference = bigz_sub(a, b)
    var product = bigz_mul(a, b)
    var common = bigz_gcd(a, b)
    print(
        "Z", index, z_token(a), z_token(b), z_token(sum), z_token(difference), z_token(product),
        bool_token(bigz_lt(a, b)), bool_token(bigz_eq(a, b)), z_token(common), divmod_tokens(a, b),
        bool_token(z_selfcheck(a, b, sum, difference, product, common)),
    )


def print_q_case(index: Int, a: Q, b: Q):
    var sum = a.add(b)
    var difference = a.sub(b)
    var product = a.mul(b)
    var quotient = a.div(b)
    var values = List[Q]()
    values.append(sum.copy())
    values.append(difference.copy())
    values.append(product.copy())
    values.append(quotient.copy())
    print(
        "Q", index, q_token(a), q_token(b), q_token(sum), q_token(difference), q_token(product),
        q_token(quotient), bool_token(a.lt(b)), bool_token(a.le(b)), bool_token(a.eq(b)),
        bool_token(q_selfcheck(values)),
    )


def random_q(mut rng: Xorshift64Star) -> Q:
    var numerator = random_bigz(rng, PROBE_MAX_LIMBS)
    var denominator = random_nonzero_bigz(rng, PROBE_MAX_LIMBS)
    return q_from_bigz(numerator, denominator)


def main():
    var rng = Xorshift64Star(PROBE_SEED)
    print("HEADER exact-arithmetic-property-probe 1", PROBE_SEED, PROBE_Z_CASES, PROBE_Q_CASES, 0)
    for index in range(PROBE_Z_CASES):
        var a = random_bigz(rng, PROBE_MAX_LIMBS)
        var b = random_bigz(rng, PROBE_MAX_LIMBS)
        print_z_case(index, a, b)
    for index in range(PROBE_Q_CASES):
        var a = random_q(rng)
        var b = random_q(rng)
        print_q_case(index, a, b)
    print("END")
