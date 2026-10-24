# Exact MAX-backed enumeration of finite quadratic shells.
#
# Reuses the estate's established parallel_fold.map_fold (MAX thread pool).
# Each map step is pure, computes one N(x) exactly using the canonical Fp[p],
# and contributes 0 or 1 to an associative integer sum. The reduction is
# deterministic at any worker count. No float, approximate MAX Tensor, GPU
# kernel or unguarded inverse is involved.
#
# The field has 8 coordinates. Enumeration is explicitly capped at 1,000,000
# points; hitting this cap is a REFUSAL, never a theorem or an exhaustive result.

from finite_exact.fp import Fp, FpField
from projective_limits.hyperbolic_rt import norm8
from parallel_fold.map_fold import parallel_map_fold


def add_counts(a: Int, b: Int) -> Int:
    return a + b


def norm_one_case[p: Int64](index: Int) -> Int:
    """Lexicographic vector enumeration; 1 iff hyperbolic norm is 1."""
    var n = index
    var x = List[Fp[p]]()
    for _ in range(8):
        x.append(Fp[p](Int64(n % Int(p))))
        n //= Int(p)
    return 1 if norm8[FpField[p]](x) == Fp[p](1) else 0


def norm_one_count_max[p: Int64](workers: Int) raises -> Int:
    """Exact F_p^8 norm-one shell census using MAX deterministic map-fold.

    Refuses excessive enumerations and invalid workers. Each product in Fp
    uses modular canonical residues, not overflow-prone raw dot products.
    """
    if workers < 1:
        raise Error("norm_one_count_max requires workers >= 1")
    var size = 1
    for _ in range(8):
        if size > 1000000 // Int(p):
            raise Error("norm_one_count_max exceeds explicit enumeration budget")
        size *= Int(p)
    return parallel_map_fold(norm_one_case[p], add_counts, 0, size, workers)


def norm_one_count_formula[p: Int64]() -> Int:
    """Classical hyperbolic norm-shell count, m=4: q^3 (q^4 - 1).

    Only used with primes small enough that the Int products fit. Independent
    of, and not a replacement for, exhaustive enumeration.
    """
    var q = Int(p)
    if q > 10:
        return -1  # Outside the vetted finite enumeration scope.
    return q * q * q * (q * q * q * q - 1)
