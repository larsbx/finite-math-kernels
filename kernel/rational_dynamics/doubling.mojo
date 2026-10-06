# doubling.mojo
#
# The doubling map `t -> 2t` on `Q/Z`, exactly and without a cap.
#
# The type of an angle is read off its denominator, not searched for: for
# `t = p/q` in lowest terms write `q = 2^l m` with `m` odd; then
#
#   preperiod(t) = l = v_2(q)        period(t) = ord_m(2)   (1 when m = 1)
#
# the closed forms of the fixed-width `angle_doubling` package, here over the
# unbounded BigZ backend with no cap on the denominator and none on the order.
# The order is `multiplicative_order.order_of_two`, exact and uncapped: the
# cost of a huge `m` with a huge order is time, never a wrong answer and never
# a silent cap. A `ReducedFraction` is an ordinary rational; every function
# here reads it modulo one, which leaves the reduced denominator unchanged.
#
# Independent reference: `oracles/rational_dynamics_py/doubling.py`, which
# `tests/rational_dynamics/test_doubling_twin.py` replays against a transcript
# of this module. Values agree; the Python plane returns a binary string where
# this module returns a list of 0/1 digits, and refuses by raising where this
# module returns a rejected value.

from finite_exact.bigint_z import BigZ, bigz_abs_div_small, bigz_add, bigz_lt, bigz_mul, bigz_sub, bigz_zero, bigz_from_i64
from rational_dynamics.integers import bigz_is_even, bigz_mod, bigz_one, bigz_result, bigz_to_int
from rational_dynamics.moebius import moebius
from rational_dynamics.multiplicative_order import order_of_two
from rational_dynamics.rational import BigZResult, ReducedFraction, rejected_bigz_result


struct DoublingType(Copyable):
    """`(preperiod, period)` of an angle, or a refusal carrying no type."""

    var preperiod: Int
    var period: BigZ
    var rejected: Bool

    def __init__(out self, preperiod: Int, period: BigZ, rejected: Bool):
        self.preperiod = preperiod
        self.period = period.copy()
        self.rejected = rejected

    def accepted(self) -> Bool:
        return not self.rejected


struct DigitsResult(Copyable, Movable):
    """Binary digits, each `0` or `1`, or a refusal carrying none."""

    var digits: List[Int]
    var rejected: Bool

    def __init__(out self, digits: List[Int], rejected: Bool):
        self.digits = digits.copy()
        self.rejected = rejected

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_digits() -> DigitsResult:
    return DigitsResult(List[Int](), True)


def _two_adic_split(den: BigZ) -> Tuple[Int, BigZ]:
    """`(l, m)` with `den = 2^l m` and `m` odd, for `den >= 1`."""
    var l = 0
    var odd = den.copy()
    while bigz_is_even(odd):
        odd = bigz_abs_div_small(odd, 2)
        l += 1
    return (l, odd^)


def preperiod(value: ReducedFraction) -> Int:
    """`v_2` of the reduced denominator of `value mod 1`; `-1`, which is not a
    preperiod, for a rejected fraction."""
    if value.rejected:
        return -1
    return _two_adic_split(value.den)[0]


def period(value: ReducedFraction) -> BigZResult:
    """The length of the cycle `value mod 1` falls into under doubling.

    `ord_m(2)` for `m` the odd part of the reduced denominator; `1` when
    `m = 1`, because zero is fixed. This is the eventual period: a strictly
    preperiodic angle (`preperiod > 0`) still has one.
    """
    if value.rejected:
        return rejected_bigz_result()
    return order_of_two(_two_adic_split(value.den)[1])


def exact_type(value: ReducedFraction) -> DoublingType:
    """`(preperiod, period)` of `value mod 1`."""
    var k = period(value)
    if k.rejected:
        return DoublingType(0, bigz_zero(), True)
    return DoublingType(preperiod(value), k.value, False)


def binary_digits(value: ReducedFraction, n: Int) -> DigitsResult:
    """The first `n` binary digits of `value mod 1` after the point.

    For a dyadic rational the terminating expansion is used (`1/2 = 0.1000...`),
    which is the orbit of doubling: digit `i` is `1` exactly when
    `2^i t mod 1 >= 1/2`. A negative count is refused.
    """
    if value.rejected or n < 0:
        return rejected_digits()
    var digits = List[Int]()
    var t = bigz_mod(value.num, value.den)
    for _ in range(n):
        t = bigz_add(t, t)
        if bigz_lt(t, value.den):
            digits.append(0)
        else:
            digits.append(1)
            t = bigz_sub(t, value.den)
    return DigitsResult(digits, False)


def binary_block(value: ReducedFraction) -> DigitsResult:
    """The repeating block of the minimal expansion `value mod 1 = 0.prefix (block)^infinity`.

    `len(prefix) == preperiod(value)` and `len(block) == period(value)`; `0`
    and `1/2` have block `0`. For a periodic angle `j / (2^k - 1)` it is `j`
    written in `k` bits. A block too long to hold as a list of machine-indexed
    digits is refused, not truncated.
    """
    var found = exact_type(value)
    if found.rejected:
        return rejected_digits()
    var k: Int
    try:
        k = bigz_to_int(found.period)
    except:
        return rejected_digits()
    if k > Int.MAX - found.preperiod:
        return rejected_digits()
    var all = binary_digits(value, found.preperiod + k)
    if all.rejected:
        return rejected_digits()
    var block = List[Int]()
    for i in range(found.preperiod, len(all.digits)):
        block.append(all.digits[i])
    return DigitsResult(block, False)


def exact_type_count(l: Int, k: Int) -> BigZResult:
    """The number of angles in `Q/Z` of exact type `(l, k)`.

    `phi(2^l) * sum_{d | k} mu(k/d) (2^d - 1)`: an angle of exact type
    `(l, k)` is `p / (2^l m)` in lowest terms with `m` odd and `ord_m(2) = k`,
    and every one lies over `2^l (2^k - 1)`. `l < 0` or `k < 1` names no type
    and is refused.
    """
    if l < 0 or k < 1:
        return rejected_bigz_result()
    var total = bigz_zero()
    var power = bigz_one()
    for d in range(1, k + 1):
        power = bigz_add(power, power)
        if k % d == 0:
            var mu: Int
            try:
                mu = moebius(k // d)
            except:
                return rejected_bigz_result()
            total = bigz_add(total, bigz_mul(bigz_from_i64(Int64(mu)), bigz_sub(power, bigz_one())))
    for _ in range(l - 1):
        total = bigz_add(total, total)
    return bigz_result(total)
