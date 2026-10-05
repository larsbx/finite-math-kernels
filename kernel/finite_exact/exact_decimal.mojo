# exact_decimal.mojo
#
# Base-ten rendering of the vendored exact integers and rationals.
#
# Specification: docs/rational-interval-arithmetic-spec.md (binding 6.2).
#
# A renderer is a consumer of the kernel's public accessors: BigZ exposes its
# sign and its limbs, which is all base ten needs. First written in
# `larsbx/finite-mandelbrot-research`, beside a vendored copy of this package.
#
# Rendering is exact and total: it introduces no division, no rounding, and no
# floating point, so an exact rational can leave the repository readable
# without ever becoming approximate.

from finite_exact.bigint_z import BigZ
from finite_exact.rat_q import Q


def bigz_decimal(value: BigZ) -> String:
    """`value` in base ten, with a leading minus when it is negative.

    Limbs are little-endian base 10^9, so the decimal form is the top limb
    written plainly followed by every lower limb padded to nine digits."""
    if value.is_zero():
        return "0"
    var out = String("-") if value.sign < 0 else String("")
    var top = value.limb_count() - 1
    out += String(Int(value.limb(top)))
    for i in range(top - 1, -1, -1):
        var limb = String(Int(value.limb(i)))
        for _ in range(9 - limb.byte_length()):
            out += "0"
        out += limb
    return out^


def q_decimal(value: Q) -> String:
    """`p/q` in base ten, or `rejected` for a value that carries no number.

    The denominator is printed even when it is one, because these are ray
    addresses and densities: `4/9` and `1/1` are both answers, and dropping the
    denominator would make an exact rational look like a count."""
    if value.rejected:
        return "rejected"
    return bigz_decimal(value.num) + "/" + bigz_decimal(value.den)


def exact_decimal_smoke() -> Bool:
    """A limb value, both carry boundaries, a negative, and past Int64."""
    from finite_exact.bigint_z import bigz_add, bigz_from_i64, bigz_mul, bigz_neg, bigz_zero
    if bigz_decimal(bigz_zero()) != "0":
        return False
    if bigz_decimal(bigz_from_i64(1)) != "1":
        return False
    if bigz_decimal(bigz_from_i64(-1)) != "-1":
        return False
    if bigz_decimal(bigz_from_i64(999999999)) != "999999999":
        return False
    if bigz_decimal(bigz_from_i64(1000000000)) != "1000000000":
        return False
    if bigz_decimal(bigz_from_i64(1000000001)) != "1000000001":
        return False
    if bigz_decimal(bigz_from_i64(9223372036854775807)) != "9223372036854775807":
        return False
    var beyond = bigz_add(bigz_from_i64(9223372036854775807), bigz_from_i64(1))
    if bigz_decimal(beyond) != "9223372036854775808":
        return False
    var square = bigz_mul(beyond, beyond)
    if bigz_decimal(square) != "85070591730234615865843651857942052864":
        return False
    if bigz_decimal(bigz_neg(square)) != "-85070591730234615865843651857942052864":
        return False
    # A rational keeps its denominator, and a rejected one carries no number.
    if q_decimal(Q(4, 9)) != "4/9":
        return False
    if q_decimal(Q(2, 1)) != "2/1":
        return False
    if q_decimal(Q(-1, 2)) != "-1/2":
        return False
    var rejected = Q(1, 0)
    if not rejected.rejected or q_decimal(rejected) != "rejected":
        return False
    return True
