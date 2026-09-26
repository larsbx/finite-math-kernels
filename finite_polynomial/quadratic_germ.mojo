# quadratic_germ.mojo
#
# Exact finite jets for
#
#     g_lambda(w) = lambda*w + w^2
#
# over an exact cyclotomic coefficient ring.  For lambda^q = 1, this module
# computes the formal coefficient
#
#     [w^q] 1/P(w),  where
#     w - g_lambda^q(w) = w^(q+1) P(w).
#
# This is a finite algebraic coefficient.  Consumers may attach dynamical
# meaning under their own definitions/theorems; this kernel does not infer
# bulb geometry, landing, connectivity, or any analytic statement.

from finite_polynomial.cyclotomic_q import (
    CyclotomicQ,
    cyclotomic_add,
    cyclotomic_equal,
    cyclotomic_inverse,
    cyclotomic_is_zero,
    cyclotomic_mul,
    cyclotomic_neg,
    cyclotomic_one,
    cyclotomic_pow,
    cyclotomic_sub,
    cyclotomic_zero,
    rejected_cyclotomic,
    zeta,
)


struct CyclotomicJet(Copyable, Movable):
    var conductor: Int
    var coeffs: List[CyclotomicQ]
    var rejected: Bool

    def __init__(out self):
        self.conductor = 0
        self.coeffs = List[CyclotomicQ]()
        self.rejected = True

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_jet() -> CyclotomicJet:
    return CyclotomicJet()


def jet_seed(conductor: Int, order: Int) -> CyclotomicJet:
    if conductor < 1 or order < 1:
        return rejected_jet()
    var out = CyclotomicJet()
    out.conductor = conductor
    out.coeffs = List[CyclotomicQ]()
    for index in range(order + 1):
        if index == 1:
            out.coeffs.append(cyclotomic_one(conductor))
        else:
            out.coeffs.append(cyclotomic_zero(conductor))
    out.rejected = False
    return out^


def jet_sub(left: CyclotomicJet, right: CyclotomicJet) -> CyclotomicJet:
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return rejected_jet()
    var out = CyclotomicJet()
    out.conductor = left.conductor
    out.coeffs = List[CyclotomicQ]()
    for index in range(len(left.coeffs)):
        var coefficient = cyclotomic_sub(left.coeffs[index], right.coeffs[index])
        if coefficient.rejected:
            return rejected_jet()
        out.coeffs.append(coefficient.copy())
    out.rejected = False
    return out^


def jet_convolve(
    left: CyclotomicJet,
    right: CyclotomicJet,
) -> CyclotomicJet:
    """Truncated convolution at the common jet order."""
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return rejected_jet()

    var order = len(left.coeffs) - 1
    var out = CyclotomicJet()
    out.conductor = left.conductor
    out.coeffs = List[CyclotomicQ]()
    for _ in range(order + 1):
        out.coeffs.append(cyclotomic_zero(left.conductor))

    for i in range(order + 1):
        for j in range(order + 1 - i):
            var product = cyclotomic_mul(left.coeffs[i], right.coeffs[j])
            if product.rejected:
                return rejected_jet()
            out.coeffs[i + j] = cyclotomic_add(out.coeffs[i + j], product)
            if out.coeffs[i + j].rejected:
                return rejected_jet()
    out.rejected = False
    return out^


def quadratic_germ_step(
    state: CyclotomicJet,
    multiplier: CyclotomicQ,
) -> CyclotomicJet:
    if (
        state.rejected or multiplier.rejected or
        state.conductor != multiplier.conductor
    ):
        return rejected_jet()

    var squared = jet_convolve(state, state)
    if squared.rejected:
        return rejected_jet()

    var out = CyclotomicJet()
    out.conductor = state.conductor
    out.coeffs = List[CyclotomicQ]()
    for index in range(len(state.coeffs)):
        var linear = cyclotomic_mul(multiplier, state.coeffs[index])
        var coefficient = cyclotomic_add(linear, squared.coeffs[index])
        if coefficient.rejected:
            return rejected_jet()
        out.coeffs.append(coefficient.copy())
    out.rejected = False
    return out^


def quadratic_germ_iterate(
    multiplier: CyclotomicQ,
    steps: Int,
    order: Int,
) -> CyclotomicJet:
    if multiplier.rejected or steps < 0 or order < 1:
        return rejected_jet()
    var state = jet_seed(multiplier.conductor, order)
    for _ in range(steps):
        state = quadratic_germ_step(state, multiplier)
        if state.rejected:
            return state^
    return state^


def _int_gcd(left: Int, right: Int) -> Int:
    var a = left
    var b = right
    if a < 0:
        a = -a
    if b < 0:
        b = -b
    while b != 0:
        var r = a % b
        a = b
        b = r
    return a


def quadratic_germ_index_coefficient(p: Int, q: Int) -> CyclotomicQ:
    """Exact [w^q] 1/P for lambda=zeta_q^p.

    Requires q >= 1, p >= 1, gcd(p,q)=1.  The q=1 case uses zeta_1=1.
    """
    if q < 1 or p < 1 or _int_gcd(p, q) != 1:
        return rejected_cyclotomic()

    var generator = zeta(q)
    if generator.rejected:
        return generator^
    var multiplier = cyclotomic_pow(generator, p % q)
    if multiplier.rejected:
        return multiplier^

    var order = 2 * q + 1
    var iterate = quadratic_germ_iterate(multiplier, q, order)
    var identity = jet_seed(q, order)
    var difference = jet_sub(identity, iterate)
    if difference.rejected:
        return rejected_cyclotomic()

    # Exact parabolic multiplicity check.  If any lower coefficient survives,
    # the requested factorization is not present and the computation refuses.
    for index in range(q + 1):
        if not cyclotomic_is_zero(difference.coeffs[index]):
            return rejected_cyclotomic()

    var p_coeffs = List[CyclotomicQ]()
    for index in range(q + 1):
        p_coeffs.append(difference.coeffs[q + 1 + index].copy())

    var inv0 = cyclotomic_inverse(p_coeffs[0])
    if inv0.rejected:
        return inv0^

    var reciprocal = List[CyclotomicQ]()
    reciprocal.append(inv0.copy())
    for n in range(1, q + 1):
        var total = cyclotomic_zero(q)
        for k in range(1, n + 1):
            var term = cyclotomic_mul(p_coeffs[k], reciprocal[n - k])
            total = cyclotomic_add(total, term)
            if total.rejected:
                return rejected_cyclotomic()
        var coefficient = cyclotomic_neg(cyclotomic_mul(inv0, total))
        if coefficient.rejected:
            return coefficient^
        reciprocal.append(coefficient.copy())

    return reciprocal[q].copy()
