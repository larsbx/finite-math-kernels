# cyclotomic_q.mojo
#
# Exact cyclotomic quotient arithmetic over
#
#     Q[X] / (Phi_n(X))
#
# with finite_exact.Q coefficients and the exact monic cyclotomic polynomial
# supplied by finite_polynomial.polynomial_z.
#
# An accepted value stores exactly phi(n) coefficients, low degree first.
# Equality is equality of conductor plus this reduced coefficient vector.
# No numerical embedding, trigonometric function, angle measurement, or
# approximate complex value appears anywhere in this module.

from finite_exact.bigint_z import (
    bigz_canonical_bytes,
    bigz_from_i64,
    bigz_gcd,
)
from finite_exact.rat_q import (
    Q,
    q_canonical_bytes,
    q_from_bigz,
)
from finite_linear_algebra.qlinalg import rref
from finite_polynomial.polynomial_z import (
    PolyZ,
    cyclotomic_polynomial,
)


struct CyclotomicQ(Copyable, Movable):
    var conductor: Int
    var coeffs: List[Q]
    var rejected: Bool

    def __init__(out self):
        self.conductor = 0
        self.coeffs = List[Q]()
        self.rejected = True

    def accepted(self) -> Bool:
        return not self.rejected

    def degree(self) -> Int:
        return len(self.coeffs)


struct CyclotomicCanonicalBytes(Copyable, Movable):
    var bytes: List[UInt8]
    var rejected: Bool

    def __init__(out self):
        self.bytes = List[UInt8]()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_cyclotomic() -> CyclotomicQ:
    return CyclotomicQ()


def rejected_cyclotomic_bytes() -> CyclotomicCanonicalBytes:
    var out = CyclotomicCanonicalBytes()
    out.rejected = True
    return out^


def _q_is_zero(value: Q) -> Bool:
    return value.accepted() and value.eq(Q.zero())


def _phi_q_coefficient(phi: PolyZ, index: Int) -> Q:
    if phi.rejected or index < 0 or index >= len(phi.coeffs):
        return Q.zero()
    return q_from_bigz(phi.coeffs[index], bigz_from_i64(1))


def _reduced_coefficients(conductor: Int, coefficients: List[Q]) -> CyclotomicQ:
    if conductor < 1:
        return rejected_cyclotomic()
    var phi = cyclotomic_polynomial(conductor)
    if phi.rejected or phi.degree() < 1:
        return rejected_cyclotomic()

    for coefficient in coefficients:
        if not coefficient.accepted():
            return rejected_cyclotomic()

    var degree = phi.degree()
    var width = len(coefficients)
    if width < degree:
        width = degree

    var work = List[Q]()
    for index in range(width):
        if index < len(coefficients):
            work.append(coefficients[index].copy())
        else:
            work.append(Q.zero())

    # Phi is monic.  Kill coefficients from highest degree downward:
    #
    #   lead * X^k
    #     -> -lead * sum_(j<degree) phi_j X^(k-degree+j).
    #
    # The leading term vanishes because phi_degree = 1.
    var k = len(work) - 1
    while k >= degree:
        var lead = work[k].copy()
        if not _q_is_zero(lead):
            var shift = k - degree
            for j in range(degree):
                var correction = lead.mul(_phi_q_coefficient(phi, j))
                work[shift + j] = work[shift + j].sub(correction)
            work[k] = Q.zero()
        k -= 1

    var out = CyclotomicQ()
    out.conductor = conductor
    out.coeffs = List[Q]()
    for index in range(degree):
        if index < len(work):
            out.coeffs.append(work[index].copy())
        else:
            out.coeffs.append(Q.zero())
    out.rejected = False
    return out^


def cyclotomic_from_coeffs(conductor: Int, coefficients: List[Q]) -> CyclotomicQ:
    """Canonical quotient representative of an arbitrary finite coefficient list."""
    return _reduced_coefficients(conductor, coefficients)


def cyclotomic_zero(conductor: Int) -> CyclotomicQ:
    var coefficients = List[Q]()
    coefficients.append(Q.zero())
    return cyclotomic_from_coeffs(conductor, coefficients)


def cyclotomic_one(conductor: Int) -> CyclotomicQ:
    var coefficients = List[Q]()
    coefficients.append(Q.one())
    return cyclotomic_from_coeffs(conductor, coefficients)


def zeta(conductor: Int) -> CyclotomicQ:
    """The residue class of X modulo Phi_conductor."""
    var coefficients = List[Q]()
    coefficients.append(Q.zero())
    coefficients.append(Q.one())
    return cyclotomic_from_coeffs(conductor, coefficients)


def cyclotomic_equal(left: CyclotomicQ, right: CyclotomicQ) -> Bool:
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return False
    for index in range(len(left.coeffs)):
        if not left.coeffs[index].eq(right.coeffs[index]):
            return False
    return True


def cyclotomic_is_zero(value: CyclotomicQ) -> Bool:
    if value.rejected:
        return False
    for coefficient in value.coeffs:
        if not _q_is_zero(coefficient):
            return False
    return True


def cyclotomic_neg(value: CyclotomicQ) -> CyclotomicQ:
    if value.rejected:
        return rejected_cyclotomic()
    var coefficients = List[Q]()
    for coefficient in value.coeffs:
        coefficients.append(coefficient.neg())
    return cyclotomic_from_coeffs(value.conductor, coefficients)


def cyclotomic_add(left: CyclotomicQ, right: CyclotomicQ) -> CyclotomicQ:
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return rejected_cyclotomic()
    var coefficients = List[Q]()
    for index in range(len(left.coeffs)):
        coefficients.append(left.coeffs[index].add(right.coeffs[index]))
    return cyclotomic_from_coeffs(left.conductor, coefficients)


def cyclotomic_sub(left: CyclotomicQ, right: CyclotomicQ) -> CyclotomicQ:
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return rejected_cyclotomic()
    var coefficients = List[Q]()
    for index in range(len(left.coeffs)):
        coefficients.append(left.coeffs[index].sub(right.coeffs[index]))
    return cyclotomic_from_coeffs(left.conductor, coefficients)


def cyclotomic_mul(left: CyclotomicQ, right: CyclotomicQ) -> CyclotomicQ:
    if (
        left.rejected or right.rejected or
        left.conductor != right.conductor or
        len(left.coeffs) != len(right.coeffs)
    ):
        return rejected_cyclotomic()

    var coefficients = List[Q]()
    for _ in range(len(left.coeffs) + len(right.coeffs) - 1):
        coefficients.append(Q.zero())

    for i in range(len(left.coeffs)):
        for j in range(len(right.coeffs)):
            coefficients[i + j] = coefficients[i + j].add(
                left.coeffs[i].mul(right.coeffs[j])
            )
    return cyclotomic_from_coeffs(left.conductor, coefficients)


def cyclotomic_inverse(value: CyclotomicQ) -> CyclotomicQ:
    """Exact multiplicative inverse by a rational multiplication matrix."""
    if value.rejected or cyclotomic_is_zero(value):
        return rejected_cyclotomic()

    var degree = len(value.coeffs)
    var matrix = List[List[Q]]()
    for _ in range(degree):
        var row = List[Q]()
        for _ in range(degree + 1):
            row.append(Q.zero())
        matrix.append(row^)

    var generator = zeta(value.conductor)
    var basis_power = cyclotomic_one(value.conductor)
    for column in range(degree):
        var product = cyclotomic_mul(value, basis_power)
        if product.rejected:
            return rejected_cyclotomic()
        for row in range(degree):
            matrix[row][column] = product.coeffs[row].copy()
        basis_power = cyclotomic_mul(basis_power, generator)
        if basis_power.rejected:
            return rejected_cyclotomic()

    matrix[0][degree] = Q.one()
    var reduced_result = rref(matrix)
    ref reduced = reduced_result[0]
    ref pivots = reduced_result[1]

    if len(pivots) != degree:
        return rejected_cyclotomic()
    for index in range(degree):
        if pivots[index] != index:
            return rejected_cyclotomic()

    var coefficients = List[Q]()
    for index in range(degree):
        coefficients.append(reduced[index][degree].copy())
    var candidate = cyclotomic_from_coeffs(value.conductor, coefficients)
    if candidate.rejected:
        return candidate^
    if not cyclotomic_equal(
        cyclotomic_mul(value, candidate),
        cyclotomic_one(value.conductor),
    ):
        return rejected_cyclotomic()
    return candidate^


def cyclotomic_div(left: CyclotomicQ, right: CyclotomicQ) -> CyclotomicQ:
    if left.rejected or right.rejected or left.conductor != right.conductor:
        return rejected_cyclotomic()
    var inverse = cyclotomic_inverse(right)
    if inverse.rejected:
        return inverse^
    return cyclotomic_mul(left, inverse)


def cyclotomic_pow(value: CyclotomicQ, exponent: Int) -> CyclotomicQ:
    if value.rejected or exponent < 0:
        return rejected_cyclotomic()
    var out = cyclotomic_one(value.conductor)
    var base = value.copy()
    var e = exponent
    while e > 0:
        if e % 2 == 1:
            out = cyclotomic_mul(out, base)
            if out.rejected:
                return out^
        e = e // 2
        if e > 0:
            base = cyclotomic_mul(base, base)
            if base.rejected:
                return base^
    return out^


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


def cyclotomic_automorphism(value: CyclotomicQ, exponent: Int) -> CyclotomicQ:
    """Apply zeta -> zeta^exponent when exponent is a unit modulo conductor."""
    if value.rejected or exponent < 0 or _int_gcd(exponent, value.conductor) != 1:
        return rejected_cyclotomic()

    var generator = zeta(value.conductor)
    if generator.rejected:
        return generator^

    var image = cyclotomic_pow(generator, exponent % value.conductor)
    if image.rejected:
        return image^

    var out = cyclotomic_zero(value.conductor)
    var power = cyclotomic_one(value.conductor)
    for index in range(len(value.coeffs)):
        if not _q_is_zero(value.coeffs[index]):
            var scaled_coeffs = List[Q]()
            for coefficient in power.coeffs:
                scaled_coeffs.append(coefficient.mul(value.coeffs[index]))
            out = cyclotomic_add(
                out,
                cyclotomic_from_coeffs(value.conductor, scaled_coeffs),
            )
        power = cyclotomic_mul(power, image)
        if power.rejected:
            return power^
    return out^


def _append_u64(mut bytes: List[UInt8], value: UInt64):
    var shift = 56
    while shift >= 0:
        bytes.append(UInt8((value >> UInt64(shift)) & 255))
        shift -= 8


def cyclotomic_canonical_bytes(value: CyclotomicQ) -> CyclotomicCanonicalBytes:
    """Canonical conductor + full reduced coefficient vector encoding."""
    if value.rejected or value.conductor < 1:
        return rejected_cyclotomic_bytes()

    var conductor = bigz_canonical_bytes(bigz_from_i64(Int64(value.conductor)))
    if conductor.rejected:
        return rejected_cyclotomic_bytes()

    var out = CyclotomicCanonicalBytes()
    _append_u64(out.bytes, UInt64(len(conductor.bytes)))
    for byte in conductor.bytes:
        out.bytes.append(byte)

    _append_u64(out.bytes, UInt64(len(value.coeffs)))
    for coefficient in value.coeffs:
        var encoded = q_canonical_bytes(coefficient)
        if encoded.rejected:
            return rejected_cyclotomic_bytes()
        _append_u64(out.bytes, UInt64(len(encoded.bytes)))
        for byte in encoded.bytes:
            out.bytes.append(byte)
    return out^


def cyclotomic_bytes_equal(
    left: CyclotomicCanonicalBytes,
    right: CyclotomicCanonicalBytes,
) -> Bool:
    if left.rejected or right.rejected or len(left.bytes) != len(right.bytes):
        return False
    for index in range(len(left.bytes)):
        if left.bytes[index] != right.bytes[index]:
            return False
    return True
