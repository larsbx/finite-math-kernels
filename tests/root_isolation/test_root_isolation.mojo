"""Executable laws for the root_isolation package.

Run with `pixi run test-root-isolation`
(`mojo run -I kernel tests/root_isolation/test_root_isolation.mojo`).

The same known roots as tests/root_isolation/test_root_isolation.py, in one
complex variable: the square root of two, the fourth roots of unity, the
period-two parameter `-2` of Mandelbrot's witness, and the refusals.
"""

from finite_exact.closed_interval import ComplexIQ, IQ, IQBoolResult
from finite_exact.rat_q import Q
from root_isolation import (
    centre,
    disjoint,
    exact_inverse,
    excludes_zero,
    krawczyk_image,
    rejected_box,
    strictly_inside,
)


def box(re_num: Int64, re_den: Int64, im_num: Int64, im_den: Int64, r_den: Int64) -> ComplexIQ:
    var re = Q(re_num, re_den)
    var im = Q(im_num, im_den)
    var r = Q(1, r_den)
    return ComplexIQ(IQ(re.sub(r), re.add(r)), IQ(im.sub(r), im.add(r)))


def point(re: Int64, im: Int64) -> ComplexIQ:
    return ComplexIQ.singleton(Q(re, 1), Q(im, 1))


def holds(result: IQBoolResult) -> Bool:
    return result.value and not result.rejected


# z^2 - 2 and its derivative 2z.
def sqrt2_value(z: ComplexIQ) -> ComplexIQ:
    return z.mul(z).sub(point(2, 0))


def sqrt2_slope(z: ComplexIQ) -> ComplexIQ:
    return point(2, 0).mul(z)


def isolates_sqrt2(x: ComplexIQ) -> IQBoolResult:
    var m = centre(x)
    var image = krawczyk_image(x, m, exact_inverse(sqrt2_slope(m)), sqrt2_value(m), sqrt2_slope(x))
    return strictly_inside(image, x)


# z^4 - 1 and its derivative 4z^3.
def unity4_value(z: ComplexIQ) -> ComplexIQ:
    return z.mul(z).mul(z).mul(z).sub(point(1, 0))


def unity4_slope(z: ComplexIQ) -> ComplexIQ:
    return point(4, 0).mul(z.mul(z).mul(z))


def isolates_unity4(x: ComplexIQ) -> Bool:
    var m = centre(x)
    return holds(strictly_inside(krawczyk_image(x, m, exact_inverse(unity4_slope(m)), unity4_value(m), unity4_slope(x)), x))


def test_the_centre_and_the_exact_inverse() -> Bool:
    var c = centre(ComplexIQ(IQ(Q(1, 3), Q(1, 2)), IQ(Q(-1, 1), Q(0, 1))))
    var inverse = exact_inverse(point(3, 4))
    return (
        c.re.lo.eq(Q(5, 12)) and c.im.hi.eq(Q(-1, 2)) and
        inverse.re.lo.eq(Q(3, 25)) and inverse.im.lo.eq(Q(-4, 25)) and
        not centre(rejected_box()).accepted()
    )


def test_the_exact_inverse_refuses() -> Bool:
    var not_a_point = ComplexIQ(IQ(Q(1, 1), Q(2, 1)), IQ(Q.zero(), Q.zero()))
    return (
        not exact_inverse(not_a_point).accepted() and
        not exact_inverse(point(0, 0)).accepted() and
        not exact_inverse(rejected_box()).accepted()
    )


def test_the_square_root_of_two() -> Bool:
    var positive = holds(isolates_sqrt2(box(17, 12, 0, 1, 16)))
    var negative = holds(isolates_sqrt2(box(-17, 12, 0, 1, 16)))
    # Both roots in one box: no contraction, and not a rejection either.
    var wide = ComplexIQ(IQ(Q(-2, 1), Q(3, 1)), IQ(Q(-1, 1), Q(1, 1)))
    var across = isolates_sqrt2(wide)
    # At the critical point the inverse is refused, and so is the image.
    var at_zero = isolates_sqrt2(box(0, 1, 0, 1, 8))
    var excluded = holds(excludes_zero(sqrt2_value(box(0, 1, 0, 1, 8))))
    return positive and negative and not across.value and not across.rejected and at_zero.rejected and excluded


def test_the_fourth_roots_of_unity_in_disjoint_boxes() -> Bool:
    var boxes = [box(1, 1, 0, 1, 64), box(0, 1, 1, 1, 64), box(-1, 1, 0, 1, 64), box(0, 1, -1, 1, 64)]
    for i in range(4):
        if not isolates_unity4(boxes[i]):
            return False
        for j in range(i + 1, 4):
            if not holds(disjoint(boxes[i], boxes[j])):
                return False
    return True


def test_the_mandelbrot_witness_at_minus_two() -> Bool:
    # P(C) = C^2 + 2C, P'(C) = 2C + 2, on the box of half-width 2^-8 at -2.
    var x = box(-2, 1, 0, 1, 256)
    var m = centre(x)
    var y = exact_inverse(point(2, 0).mul(m).add(point(2, 0)))
    var image = krawczyk_image(x, m, y, m.mul(m).add(point(2, 0).mul(m)), point(2, 0).mul(x).add(point(2, 0)))
    return y.re.lo.eq(Q(-1, 2)) and y.im.lo.eq(Q.zero()) and holds(strictly_inside(image, x))


def test_refusals_are_values() -> Bool:
    var x = box(17, 12, 0, 1, 16)
    var one = point(1, 0)
    var image = krawczyk_image(x, centre(x), rejected_box(), one, one)
    var strict = strictly_inside(image, x)
    var degenerate = ComplexIQ(IQ(Q(1, 2), Q(2, 1)), IQ(Q.zero(), Q.zero()))
    return (
        not image.accepted() and strict.rejected and not strict.value and
        excludes_zero(rejected_box()).rejected and disjoint(rejected_box(), x).rejected and
        not holds(isolates_sqrt2(degenerate)) and
        not holds(strictly_inside(x, x))
    )


def test_disjointness_is_strict() -> Bool:
    var a = ComplexIQ(IQ(Q.zero(), Q(1, 1)), IQ(Q.zero(), Q(1, 1)))
    var touching = ComplexIQ(IQ(Q(1, 1), Q(2, 1)), IQ(Q.zero(), Q(1, 1)))
    var apart = ComplexIQ(IQ(Q.zero(), Q(1, 1)), IQ(Q(3, 2), Q(2, 1)))
    return holds(disjoint(a, apart)) and not disjoint(a, touching).value


def main() raises:
    if not test_the_centre_and_the_exact_inverse():
        raise Error("centre or exact_inverse is wrong")
    if not test_the_exact_inverse_refuses():
        raise Error("exact_inverse accepted a box, zero or a rejection")
    if not test_the_square_root_of_two():
        raise Error("the square root of two is not isolated as specified")
    if not test_the_fourth_roots_of_unity_in_disjoint_boxes():
        raise Error("the fourth roots of unity are not isolated in disjoint boxes")
    if not test_the_mandelbrot_witness_at_minus_two():
        raise Error("the Mandelbrot witness at -2 is not reproduced")
    if not test_refusals_are_values():
        raise Error("a refusal aborted or was accepted")
    if not test_disjointness_is_strict():
        raise Error("disjointness is not strict separation")
    print("root_isolation laws passed.")
