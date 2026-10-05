"""Row-major square non-negative integer matrices on any alphabet size.

The alphabet-3 kernel uses the fixed-size `Mat3` of `finite_linear_algebra`;
sweeps over a variable alphabet need the same primitivity decision without a
fixed dimension. Wielandt's bound makes it a finite check: a non-negative
`n x n` matrix is primitive exactly when `M^k` is strictly positive for some
`k <= n^2 - 2n + 2`, so the test is exact integer arithmetic and terminates.
The first consumer, `larsbx/pisot-substitution-conjecture-research`, pins agreement with its `Mat3`
primitivity test on the three-letter incidence matrices, so this is one
decision procedure with two representations, not two definitions.
"""


def wielandt_bound(size: Int) -> Int:
    """`n^2 - 2n + 2`: the largest exponent primitivity can need."""
    return size * size - 2 * size + 2


def matmul(a: List[Int], b: List[Int], size: Int) -> List[Int]:
    var out = List[Int](length=size * size, fill=0)
    for i in range(size):
        for k in range(size):
            var aik = a[size * i + k]
            if aik == 0:
                continue
            for j in range(size):
                out[size * i + j] += aik * b[size * k + j]
    return out^


def is_positive(m: List[Int]) -> Bool:
    for i in range(len(m)):
        if m[i] <= 0:
            return False
    return True


def is_nonnegative(m: List[Int]) -> Bool:
    for i in range(len(m)):
        if m[i] < 0:
            return False
    return True


def is_primitive(m: List[Int], size: Int) -> Bool:
    """Some power of `m` is strictly positive (Wielandt's exponent bound)."""
    if not is_nonnegative(m):
        return False
    var power = m.copy()
    for _ in range(wielandt_bound(size)):
        if is_positive(power):
            return True
        power = matmul(power, m, size)
    return False
