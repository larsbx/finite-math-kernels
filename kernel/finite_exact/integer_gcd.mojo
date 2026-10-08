# Canonical Euclidean gcd helpers for finite certificate kernels.
#
# Int and Int64 entry points remain explicit so callers do not narrow values.
# Rational normalization uses the separately named zero-to-one policy.
#
# Reference: the Euclidean algorithm, Euclid, *Elements* VII.1-2; D. E. Knuth,
# *The Art of Computer Programming*, vol. 2 (3rd ed., 1997), section 4.5.2,
# Algorithm A. Remainders are taken on nonpositive magnitudes so that the
# signed minimum needs no negation; this is not the binary (Stein) gcd.


def gcd_int(a0: Int, b0: Int) raises -> Int:
    """Nonnegative GCD; raise only when its magnitude cannot fit in Int."""
    var a = a0
    var b = b0
    # Every signed magnitude fits in the nonpositive half of the range.
    if a > 0:
        a = -a
    if b > 0:
        b = -b
    while b != 0:
        # MIN % -1 would overflow in the signed division behind remainder.
        if b == -1:
            return 1
        var remainder = a % b
        a = b
        b = remainder
    if a == Int.MIN:
        raise Error("integer gcd is not representable in Int")
    return -a


def gcd_i64(a0: Int64, b0: Int64) raises -> Int64:
    """Nonnegative GCD; raise only when its magnitude cannot fit in Int64."""
    var a = a0
    var b = b0
    if a > 0:
        a = -a
    if b > 0:
        b = -b
    while b != 0:
        if b == -1:
            return 1
        var remainder = a % b
        a = b
        b = remainder
    if a == Int64.MIN:
        raise Error("integer gcd is not representable in Int64")
    return -a


def gcd_i64_or_one(a: Int64, b: Int64) raises -> Int64:
    var divisor = gcd_i64(a, b)
    if divisor == 0:
        return 1
    return divisor
