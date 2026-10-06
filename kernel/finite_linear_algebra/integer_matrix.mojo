"""Row-major square non-negative integer matrices on any alphabet size.

The alphabet-3 kernel uses the fixed-size `Mat3` of `finite_linear_algebra`;
sweeps over a variable alphabet need the same primitivity decision without a
fixed dimension. Wielandt's bound (`wielandt_bound.mojo`, which cites it, and
re-exported here) makes it a finite check: a non-negative `n x n` matrix is
primitive exactly when `M^k` is strictly positive for some
`k <= n^2 - 2n + 2`. The decision computes Boolean support powers, since
nonnegative multiplication has no cancellation; weights cannot overflow it.
Numerical `matmul` separately checks every product and accumulation and raises
when a machine-integer intermediate is unrepresentable.
The first consumer, `larsbx/pisot-substitution-conjecture-research`, pins agreement with its `Mat3`
primitivity test on the three-letter incidence matrices, so this is one
decision procedure with two representations, not two definitions.
"""

from finite_exact.checked_int import checked_add, checked_mul
from finite_linear_algebra.wielandt_bound import wielandt_bound


def _square_entries(size: Int) raises -> Int:
    if size < 1:
        raise Error("integer matrix dimension must be positive")
    return checked_mul(size, size)


def matmul(a: List[Int], b: List[Int], size: Int) raises -> List[Int]:
    var entries = _square_entries(size)
    if len(a) != entries or len(b) != entries:
        raise Error("integer matrix dimensions do not agree")
    var out = List[Int](length=entries, fill=0)
    for i in range(size):
        for k in range(size):
            var aik = a[size * i + k]
            if aik == 0:
                continue
            for j in range(size):
                var index = size * i + j
                out[index] = checked_add(out[index], checked_mul(aik, b[size * k + j]))
    return out^


def _support_matmul(a: List[Int], b: List[Int], size: Int) -> List[Int]:
    var out = List[Int](length=len(a), fill=0)
    for i in range(size):
        for k in range(size):
            if a[size * i + k] == 0:
                continue
            for j in range(size):
                if b[size * k + j] != 0:
                    out[size * i + j] = 1
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


def is_primitive(m: List[Int], size: Int) raises -> Bool:
    """Some power of `m` is strictly positive (Wielandt's exponent bound)."""
    if len(m) != _square_entries(size):
        raise Error("integer matrix dimensions do not agree")
    if not is_nonnegative(m):
        return False
    var support = List[Int](length=len(m), fill=0)
    for i in range(len(m)):
        if m[i] > 0:
            support[i] = 1
    var power = support.copy()
    var bound = wielandt_bound(size)
    for k in range(1, bound + 1):
        if is_positive(power):
            return True
        if k < bound:
            power = _support_matmul(power, support, size)
    return False
