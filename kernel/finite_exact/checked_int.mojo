"""Machine-integer arithmetic that refuses rather than wraps.

Every theorem-facing integer operation in this repository has to be exact or
absent: a wrapped sum is a wrong number presented as a count, which is worse
than no answer. These are the primitives that decide that, in one place, so a
new kernel does not arrive with its own copy of the same four comparisons.

`Int` is 64-bit here while the Python oracle's `int` is arbitrary precision, so
a faithful Mojo port of an oracle routine is faithful *on the inputs whose
intermediates fit* and raises on the rest. That is the whole contract: a
successful run is exact, and a failure is inconclusive rather than evidence.
"""


def checked_abs(x: Int) raises -> Int:
    if x == Int.MIN:
        raise Error("checked integer arithmetic cannot take abs(Int.MIN)")
    return -x if x < 0 else x


def checked_neg(a: Int) raises -> Int:
    if a == Int.MIN:
        raise Error("checked integer negation overflow")
    return -a


def checked_add(a: Int, b: Int) raises -> Int:
    if b > 0 and a > Int.MAX - b:
        raise Error("checked integer addition overflow")
    if b < 0 and a < Int.MIN - b:
        raise Error("checked integer addition overflow")
    return a + b


def checked_sub(a: Int, b: Int) raises -> Int:
    if b > 0 and a < Int.MIN + b:
        raise Error("checked integer subtraction overflow")
    if b < 0 and a > Int.MAX + b:
        raise Error("checked integer subtraction overflow")
    return a - b


def checked_mul(a: Int, b: Int) raises -> Int:
    if a == 0 or b == 0:
        return 0
    # Unsigned magnitudes include abs(MIN), without ever negating MIN in
    # signed arithmetic. The negative range admits one extra magnitude.
    var aa = UInt64(-(a + 1)) + 1 if a < 0 else UInt64(a)
    var bb = UInt64(-(b + 1)) + 1 if b < 0 else UInt64(b)
    var limit = UInt64(Int.MAX)
    if (a < 0) != (b < 0):
        limit += 1
    if aa > limit // bb:
        raise Error("checked integer multiplication overflow")
    return a * b
