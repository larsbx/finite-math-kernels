"""Transcript of `finite_exact.closed_q` on a fixed corpus, for the Python twin.

`tests/closed_interval/test_closed_q_twin.py` runs this program and recomputes
every line with `oracles/closed_interval`. The corpus is printed with the
results, so a corpus that drifted between the two sides fails as loudly as an
operation that disagrees. Rationals print as `p/q` (`q_decimal`); a rejected
interval prints as `rejected`; a predicate prints `1`, `0`, or `R` when an
operand is rejected.
"""

from finite_exact.closed_q import IQ, ComplexIQ, IQBoolResult
from finite_exact.exact_decimal import q_decimal
from finite_exact.rat_q import Q


def corpus() -> List[Int64]:
    # lo_num, lo_den, hi_num, hi_den per interval; the last one is reversed.
    return [
        -3, 1, -1, 2,
        -1, 1, 1, 1,
        0, 1, 0, 1,
        1, 4, 1, 2,
        -1, 4, 1, 4,
        2, 1, 5, 1,
        1, 3, 7, 3,
        -5, 2, 0, 1,
        0, 1, 3, 4,
        -7, 3, 5, 6,
        2, 1, 1, 1,
    ]


def count() -> Int:
    return len(corpus()) // 4


def interval(i: Int) -> IQ:
    var c = corpus()
    return IQ(Q(c[4 * i], c[4 * i + 1]), Q(c[4 * i + 2], c[4 * i + 3]))


def iq_token(x: IQ) -> String:
    if x.rejected:
        return String("rejected")
    return q_decimal(x.lo) + "," + q_decimal(x.hi)


def bool_token(result: IQBoolResult) -> String:
    if result.rejected:
        return String("R")
    return String("1") if result.value else String("0")


def main():
    print("HEADER closed-q-twin 1")
    var n = count()
    for i in range(n):
        var x = interval(i)
        var sign = x.sign()
        var sign_token = String("R") if sign.rejected else String(sign.code)
        print(
            "I1", iq_token(x), iq_token(x.square()), iq_token(x.neg()), iq_token(x.reciprocal()),
            sign_token, bool_token(x.contains_zero()), bool_token(x.excludes_zero()),
        )
    for i in range(n):
        for j in range(n):
            var x = interval(i)
            var y = interval(j)
            print(
                "I2", iq_token(x), iq_token(y), iq_token(x.add(y)), iq_token(x.sub(y)), iq_token(x.mul(y)),
                bool_token(x.subset_of(y)), bool_token(x.strict_subset_of(y)),
            )
    for i in range(n):
        for j in range(n):
            var z = ComplexIQ(interval(i), interval(j))
            var sq = z.square()
            print("C1", iq_token(z.re), iq_token(z.im), iq_token(sq.re), iq_token(sq.im), iq_token(z.quadrance()))
    for i in range(0, n, 3):
        for j in range(1, n, 3):
            for k in range(2, n, 3):
                var z = ComplexIQ(interval(i), interval(j))
                var w = ComplexIQ(interval(k), interval(i))
                var product = z.mul(w)
                var total = z.add(w)
                print(
                    "C2", iq_token(z.re), iq_token(z.im), iq_token(w.re), iq_token(w.im),
                    iq_token(product.re), iq_token(product.im), iq_token(total.re), iq_token(total.im),
                    bool_token(z.subset_of(w)), bool_token(z.strict_subset_of(w)),
                )
    print("END")
