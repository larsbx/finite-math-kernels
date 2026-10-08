"""Transcript of `quadratic_orbit.escape_criterion` and `quadratic_orbit.multiplier_classification`.

`tests/quadratic_orbit/test_escape_criterion_oracle.py` runs this program and
recomputes every line from `oracles/closed_interval` and its own forms of the
escape bound, the certificate and the trichotomy. The corpus is printed with
the results, so a corpus that drifted between the sides fails as loudly as a
verdict that disagrees. Rationals print as `p/q`, a refusal as `rejected`.
"""

from finite_exact.closed_interval import ComplexIQ, IQ, complex_box
from finite_exact.exact_decimal import q_decimal
from finite_exact.rat_q import Q
from quadratic_orbit.escape_criterion import certificate_holds, escape_bound_quadrance, escapes, growth_form, threshold_form
from quadratic_orbit.multiplier_classification import multiplier_regime


def boxes() -> List[Int64]:
    # re_lo, re_hi, im_lo, im_hi over a denominator; the last one is reversed.
    return [
        0, 0, 0, 0, 1,
        1, 1, 0, 0, 4,
        -2, -2, 0, 0, 1,
        2, 2, 0, 0, 1,
        5, 5, 0, 0, 1,
        3, 3, 4, 4, 1,
        3, 3, 4, 4, 5,
        0, 0, -1, -1, 1,
        3, 4, 3, 4, 1,
        5, 6, 5, 6, 2,
        -1, 1, -1, 1, 4,
        3, 5, 0, 0, 4,
        4, 5, 0, 0, 4,
        1, 3, 0, 0, 1,
        -9, 9, -9, 9, 1,
        1, -1, 0, 0, 1,
    ]


def box(i: Int) -> ComplexIQ:
    var b = boxes()
    return complex_box(b[5 * i], b[5 * i + 1], b[5 * i + 2], b[5 * i + 3], b[5 * i + 4])


def rationals() -> List[Int64]:
    # The certificate grid's values; the last one is rejected.
    return [0, 1, 1, 1, 51, 50, 3, 2, 2, 1, 4, 1, 9, 2, 5, 1, 26, 5, 9, 1, 163, 31, 98, 19, 263, 19, 1, 0]


def rational(i: Int) -> Q:
    var r = rationals()
    return Q(r[2 * i], r[2 * i + 1])


def box_token(z: ComplexIQ) -> String:
    if not z.accepted():
        return String("rejected")
    return q_decimal(z.re.lo) + "," + q_decimal(z.re.hi) + "," + q_decimal(z.im.lo) + "," + q_decimal(z.im.hi)


def flag(value: Bool) -> String:
    return String("1") if value else String("0")


def main():
    print("HEADER quadratic-orbit-escape 1")
    var n = len(boxes()) // 5
    for i in range(n):
        print("B", box_token(box(i)), q_decimal(escape_bound_quadrance(box(i))), String(multiplier_regime(box(i))))
    for i in range(n):
        for j in range(n):
            print("E", box_token(box(i)), box_token(box(j)), flag(escapes(box(i), box(j))))
    var k = len(rationals()) // 2
    for a in range(k):
        for b in range(k):
            for c in range(k):
                var t = rational(a)
                var m = rational(b)
                var r = rational(c)
                print(
                    "C", q_decimal(t), q_decimal(m), q_decimal(r),
                    q_decimal(threshold_form(t, r)), q_decimal(growth_form(t, m, r)), flag(certificate_holds(t, m, r)),
                )
    print("END")
