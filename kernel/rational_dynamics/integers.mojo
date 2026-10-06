# integers.mojo
#
# Generic BigZ integer helpers the doubling-map number theory shares: a checked
# conversion to machine `Int` that refuses rather than truncates, the
# nonnegative remainder, divisibility, parity, modular powers of two, and the
# prime factorisation by trial division. Nothing here is named in the
# literature beyond its textbook algorithm; the named objects built on it
# live in their own modules (`multiplicative_order`, `carmichael`).

from finite_exact.bigint_z import (
    BigZ,
    BIGZ_BASE,
    bigz_abs_div_small,
    bigz_abs_mod_small,
    bigz_add,
    bigz_divmod,
    bigz_eq,
    bigz_from_i64,
    bigz_is_canonical,
    bigz_lt,
    bigz_mul,
)
from rational_dynamics.rational import BigZResult


def bigz_result(value: BigZ) -> BigZResult:
    var out = BigZResult()
    out.value = value.copy()
    return out^


def bigz_one() -> BigZ:
    return bigz_from_i64(1)


def bigz_is_even(value: BigZ) -> Bool:
    return bigz_abs_mod_small(value, 2) == 0


def bigz_mod(value: BigZ, modulus: BigZ) -> BigZ:
    """`value mod modulus` for `value >= 0` and `modulus > 0`."""
    return bigz_divmod(value, modulus).remainder.copy()


def bigz_divides(divisor: BigZ, value: BigZ) -> Bool:
    return bigz_mod(value, divisor).is_zero()


def bigz_quotient(value: BigZ, divisor: BigZ) -> BigZ:
    return bigz_divmod(value, divisor).quotient.copy()


def bigz_to_int(value: BigZ) raises -> Int:
    """`value` as a machine `Int`, refused rather than truncated when it does not fit."""
    if not bigz_is_canonical(value):
        raise Error("not a canonical BigZ")
    var magnitude = 0
    var limit = Int.MAX
    var index = value.limb_count() - 1
    while index >= 0:
        var limb = Int(value.limb(index))
        if magnitude > (limit - limb) // Int(BIGZ_BASE):
            raise Error("integer does not fit a machine Int")
        magnitude = magnitude * Int(BIGZ_BASE) + limb
        index -= 1
    return -magnitude if value.sign < 0 else magnitude


def power_of_two_mod(exponent: BigZ, modulus: BigZ) -> BigZ:
    """`2^exponent mod modulus` by square and multiply, for `exponent >= 0`."""
    var result = bigz_mod(bigz_one(), modulus)
    var base = bigz_mod(bigz_from_i64(2), modulus)
    var rest = exponent.copy()
    while not rest.is_zero():
        if not bigz_is_even(rest):
            result = bigz_mod(bigz_mul(result, base), modulus)
        base = bigz_mod(bigz_mul(base, base), modulus)
        rest = bigz_abs_div_small(rest, 2)
    return result^


def prime_factors(n: BigZ) -> List[Tuple[BigZ, Int]]:
    """The prime factorisation of `n >= 1` by trial division, ascending."""
    var out = List[Tuple[BigZ, Int]]()
    var rest = n.copy()
    var d = bigz_from_i64(2)
    while not bigz_lt(rest, bigz_mul(d, d)):
        var exponent = 0
        while bigz_divides(d, rest):
            rest = bigz_quotient(rest, d)
            exponent += 1
        if exponent > 0:
            out.append((d.copy(), exponent))
        d = bigz_add(d, bigz_one() if bigz_eq(d, bigz_from_i64(2)) else bigz_from_i64(2))
    if bigz_lt(bigz_one(), rest):
        out.append((rest.copy(), 1))
    return out^
