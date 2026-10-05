# Canonical Euclidean gcd helpers for finite certificate kernels.
#
# Int and Int64 entry points remain explicit so callers do not narrow values.
# Rational normalization uses the separately named zero-to-one policy.


def gcd_int(a0: Int, b0: Int) -> Int:
    var a = a0
    var b = b0
    if a < 0:
        a = -a
    if b < 0:
        b = -b
    while b != 0:
        var remainder = a % b
        a = b
        b = remainder
    return a


def gcd_i64(a0: Int64, b0: Int64) -> Int64:
    var a = a0
    var b = b0
    if a < 0:
        a = -a
    if b < 0:
        b = -b
    while b != 0:
        var remainder = a % b
        a = b
        b = remainder
    return a


def gcd_i64_or_one(a: Int64, b: Int64) -> Int64:
    var divisor = gcd_i64(a, b)
    if divisor == 0:
        return 1
    return divisor
