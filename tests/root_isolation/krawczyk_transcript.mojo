"""Transcript of `root_isolation.krawczyk` on a fixed corpus, for the Python twin.

`tests/root_isolation/test_krawczyk_twin.py` runs this program and recomputes
every line with `oracles/root_isolation_py`. The map is `F(z) = z z + a`, with
`F'(z) = 2 z`, for each parameter `a` and box `X` of the corpus. Rationals
print as `p/q`, a rejected box as `rejected`, a test as `1`, `0` or `R`.
"""

from finite_exact.closed_q import IQ, ComplexIQ, IQBoolResult
from finite_exact.exact_decimal import q_decimal
from finite_exact.rat_q import Q
from root_isolation import centre, disjoint, exact_inverse, excludes_zero, krawczyk_image, strictly_inside


def boxes() -> List[Int64]:
    # re_num, re_den, im_num, im_den, radius_den per box; the last is degenerate.
    return [
        17, 12, 0, 1, 16,
        -17, 12, 0, 1, 16,
        0, 1, 0, 1, 8,
        1, 2, 1, 2, 2,
        -1, 2, 433, 500, 64,
        0, 1, 1, 1, 32,
        3, 1, -1, 1, 1,
        -2, 1, 0, 1, 256,
    ]


def parameters() -> List[Int64]:
    # re_num, re_den, im_num, im_den per parameter a.
    return [-2, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 4, -3, 4]


def box(i: Int) -> ComplexIQ:
    var b = boxes()
    var re = Q(b[5 * i], b[5 * i + 1])
    var im = Q(b[5 * i + 2], b[5 * i + 3])
    var r = Q(1, b[5 * i + 4])
    return ComplexIQ(IQ(re.sub(r), re.add(r)), IQ(im.sub(r), im.add(r)))


def parameter(j: Int) -> ComplexIQ:
    var p = parameters()
    return ComplexIQ.singleton(Q(p[4 * j], p[4 * j + 1]), Q(p[4 * j + 2], p[4 * j + 3]))


def value(z: ComplexIQ, a: ComplexIQ) -> ComplexIQ:
    return z.mul(z).add(a)


def slope(z: ComplexIQ) -> ComplexIQ:
    return ComplexIQ.singleton(Q(2, 1), Q.zero()).mul(z)


def iq_token(x: IQ) -> String:
    if x.rejected:
        return String("rejected")
    return q_decimal(x.lo) + "," + q_decimal(x.hi)


def box_token(z: ComplexIQ) -> String:
    if not z.accepted():
        return String("rejected")
    return iq_token(z.re) + ";" + iq_token(z.im)


def bool_token(result: IQBoolResult) -> String:
    if result.rejected:
        return String("R")
    return String("1") if result.value else String("0")


def main():
    print("HEADER krawczyk-twin 1")
    var nb = len(boxes()) // 5
    var np = len(parameters()) // 4
    for i in range(nb):
        var x = box(i)
        var m = centre(x)
        var y = exact_inverse(slope(m))
        for j in range(np):
            var a = parameter(j)
            var image = krawczyk_image(x, m, y, value(m, a), slope(x))
            print(
                "K", box_token(x), box_token(a), box_token(m), box_token(y), box_token(image),
                bool_token(strictly_inside(image, x)), bool_token(excludes_zero(value(x, a))),
                bool_token(disjoint(x, box((i + 1) % nb))),
            )
    print("END")
