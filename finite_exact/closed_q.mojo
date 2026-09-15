# closed_q.mojo
#
# Specification: larsbx/finite_exact:docs/rational-interval-arithmetic-spec.md (sections 2 and 3).
#
# Rational interval arithmetic scaffold for certificate witnesses.
# Endpoints are normalized rationals backed by dynamic-limb BigZ values.
# Public boundary: docs/exact-arithmetic-public-boundary.md.

from finite_exact.rat_q import Q, q_min, q_max, q_rejected


struct IQBoolResult(Copyable):
    var value: Bool
    var rejected: Bool

    def __init__(out self, value: Bool, rejected: Bool):
        self.value = value
        self.rejected = rejected


struct IQSignResult(Copyable):
    # code is -1 for strictly negative, 1 for strictly positive, and 0 for
    # indeterminate because the interval contains zero. Rejection is separate.
    var code: Int
    var rejected: Bool

    def __init__(out self, code: Int, rejected: Bool):
        self.code = code
        self.rejected = rejected


struct IQ(Copyable):
    var lo: Q
    var hi: Q
    var rejected: Bool

    def __init__(out self, lo: Q, hi: Q):
        self.lo = lo.copy()
        self.hi = hi.copy()
        self.rejected = lo.rejected or hi.rejected
        if not self.rejected and not lo.le(hi):
            self.rejected = True

    def accepted(self) -> Bool:
        return not self.rejected

    @staticmethod
    def singleton(x: Q) -> IQ:
        # Singleton box [x, x] with an exact rational endpoint. No ideal point
        # is introduced (larsbx/NLAP-JT:docs/no-points-invariant.md).
        return IQ(x, x)

    def contains_zero(self) -> IQBoolResult:
        if self.rejected:
            return IQBoolResult(False, True)
        return IQBoolResult(self.lo.le(Q.zero()) and Q.zero().le(self.hi), False)

    def excludes_zero(self) -> IQBoolResult:
        var contains = self.contains_zero()
        return IQBoolResult(not contains.value, contains.rejected)

    def sign(self) -> IQSignResult:
        if self.rejected:
            return IQSignResult(0, True)
        if Q.zero().lt(self.lo):
            return IQSignResult(1, False)
        if self.hi.lt(Q.zero()):
            return IQSignResult(-1, False)
        return IQSignResult(0, False)

    def reciprocal(self) -> IQ:
        var contains = self.contains_zero()
        if contains.rejected or contains.value:
            return IQ(q_rejected(), q_rejected())
        return IQ(Q.one().div(self.hi), Q.one().div(self.lo))

    def add(self, other: IQ) -> IQ:
        if self.rejected or other.rejected:
            return IQ(q_rejected(), q_rejected())
        return IQ(self.lo.add(other.lo), self.hi.add(other.hi))

    def sub(self, other: IQ) -> IQ:
        if self.rejected or other.rejected:
            return IQ(q_rejected(), q_rejected())
        return IQ(self.lo.sub(other.hi), self.hi.sub(other.lo))

    def neg(self) -> IQ:
        if self.rejected:
            return IQ(q_rejected(), q_rejected())
        return IQ(self.hi.neg(), self.lo.neg())

    def mul(self, other: IQ) -> IQ:
        if self.rejected or other.rejected:
            return IQ(q_rejected(), q_rejected())
        var p1 = self.lo.mul(other.lo)
        var p2 = self.lo.mul(other.hi)
        var p3 = self.hi.mul(other.lo)
        var p4 = self.hi.mul(other.hi)
        var lo = q_min(q_min(p1, p2), q_min(p3, p4))
        var hi = q_max(q_max(p1, p2), q_max(p3, p4))
        return IQ(lo, hi)

    def square(self) -> IQ:
        var contains = self.contains_zero()
        if contains.rejected:
            return IQ(q_rejected(), q_rejected())
        if contains.value:
            var a = self.lo.square()
            var b = self.hi.square()
            return IQ(Q.zero(), q_max(a, b))
        return self.mul(self)

    def subset_of(self, other: IQ) -> IQBoolResult:
        if self.rejected or other.rejected:
            return IQBoolResult(False, True)
        return IQBoolResult(other.lo.le(self.lo) and self.hi.le(other.hi), False)

    def strict_subset_of(self, other: IQ) -> IQBoolResult:
        if self.rejected or other.rejected:
            return IQBoolResult(False, True)
        return IQBoolResult(other.lo.lt(self.lo) and self.hi.lt(other.hi), False)


struct ComplexIQ(Copyable):
    var re: IQ
    var im: IQ

    def __init__(out self, re: IQ, im: IQ):
        self.re = re.copy()
        self.im = im.copy()

    def accepted(self) -> Bool:
        return self.re.accepted() and self.im.accepted()

    @staticmethod
    def singleton(re: Q, im: Q) -> ComplexIQ:
        # Rank-2 singleton box from two exact rational coordinates. No ideal
        # point is introduced (larsbx/NLAP-JT:docs/no-points-invariant.md).
        return ComplexIQ(IQ.singleton(re), IQ.singleton(im))

    def add(self, other: ComplexIQ) -> ComplexIQ:
        return ComplexIQ(self.re.add(other.re), self.im.add(other.im))

    def sub(self, other: ComplexIQ) -> ComplexIQ:
        return ComplexIQ(self.re.sub(other.re), self.im.sub(other.im))

    def mul(self, other: ComplexIQ) -> ComplexIQ:
        var real_part = self.re.mul(other.re).sub(self.im.mul(other.im))
        var imag_part = self.re.mul(other.im).add(self.im.mul(other.re))
        return ComplexIQ(real_part, imag_part)

    def square(self) -> ComplexIQ:
        return self.mul(self)

    def quadrance(self) -> IQ:
        return self.re.square().add(self.im.square())

    def subset_of(self, other: ComplexIQ) -> IQBoolResult:
        var re_result = self.re.subset_of(other.re)
        var im_result = self.im.subset_of(other.im)
        if re_result.rejected or im_result.rejected:
            return IQBoolResult(False, True)
        return IQBoolResult(re_result.value and im_result.value, False)

    def strict_subset_of(self, other: ComplexIQ) -> IQBoolResult:
        var re_result = self.re.strict_subset_of(other.re)
        var im_result = self.im.strict_subset_of(other.im)
        if re_result.rejected or im_result.rejected:
            return IQBoolResult(False, True)
        return IQBoolResult(re_result.value and im_result.value, False)


def demo_interval_mul() -> Bool:
    var a = IQ(Q(1, 1), Q(2, 1))
    var b = IQ(Q(3, 1), Q(5, 1))
    var c = a.mul(b)
    return c.lo.eq(Q(3, 1)) and c.hi.eq(Q(10, 1))


def demo_complex_quadrance_point() -> Bool:
    var z = ComplexIQ.singleton(Q(3, 1), Q(4, 1))
    var q = z.quadrance()
    return q.lo.eq(Q(25, 1)) and q.hi.eq(Q(25, 1))


def bigq_interval_conformance_smoke() -> Bool:
    var reversed = IQ(Q(2, 1), Q(1, 1))
    var bad_endpoint = IQ(Q(1, 0), Q(1, 1))
    var crossing = IQ(Q(-1, 1), Q(2, 1))
    var positive = IQ(Q(2, 1), Q(4, 1))
    var negative = IQ(Q(-4, 1), Q(-2, 1))
    var reciprocal = positive.reciprocal()
    var rejected_subset = reversed.subset_of(positive)
    return (
        reversed.rejected and bad_endpoint.rejected and
        crossing.sign().code == 0 and not crossing.sign().rejected and
        positive.sign().code == 1 and negative.sign().code == -1 and
        crossing.reciprocal().rejected and reciprocal.accepted() and
        reciprocal.lo.eq(Q(1, 4)) and reciprocal.hi.eq(Q(1, 2)) and
        rejected_subset.rejected and not rejected_subset.value and
        reversed.add(positive).rejected and reversed.mul(positive).rejected
    )
