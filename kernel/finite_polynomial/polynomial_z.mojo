# polynomial_z.mojo
#
# Dynamic exact univariate polynomials over finite_exact.BigZ.
# Coefficients are stored low degree first and normalized to remove trailing
# zeros.  No fixed degree bound and no machine-integer coefficient bound.
#
# This is the shared foundation for exact cyclotomic arithmetic.  It does not
# interpret a polynomial root, certify a domain theorem, or perform numerical
# approximation.

from finite_exact.bigint_z import (
    BigZ,
    bigz_add,
    bigz_eq,
    bigz_from_i64,
    bigz_is_canonical,
    bigz_mul,
    bigz_sub,
    bigz_zero,
)


struct PolyZ(Copyable, Movable):
    var coeffs: List[BigZ]
    var rejected: Bool

    def __init__(out self):
        self.coeffs = List[BigZ]()
        self.coeffs.append(bigz_zero())
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected

    def degree(self) -> Int:
        if self.rejected:
            return -1
        return len(self.coeffs) - 1


struct PolyDivResult(Copyable, Movable):
    var quotient: PolyZ
    var rejected: Bool

    def __init__(out self):
        self.quotient = PolyZ()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_poly() -> PolyZ:
    var out = PolyZ()
    out.rejected = True
    return out^


def rejected_division() -> PolyDivResult:
    var out = PolyDivResult()
    out.rejected = True
    return out^


def _normalize(mut value: PolyZ):
    if value.rejected:
        return
    while len(value.coeffs) > 1 and value.coeffs[len(value.coeffs) - 1].is_zero():
        _ = value.coeffs.pop()


def poly_from_coeffs(coefficients: List[BigZ]) -> PolyZ:
    if len(coefficients) == 0:
        return PolyZ()
    var out = PolyZ()
    out.coeffs = List[BigZ]()
    for coefficient in coefficients:
        if not bigz_is_canonical(coefficient):
            return rejected_poly()
        out.coeffs.append(coefficient.copy())
    _normalize(out)
    return out^


def poly_from_i64(coefficients: List[Int64]) -> PolyZ:
    var values = List[BigZ]()
    for coefficient in coefficients:
        values.append(bigz_from_i64(coefficient))
    return poly_from_coeffs(values)


def poly_zero() -> PolyZ:
    return PolyZ()


def poly_one() -> PolyZ:
    var values = List[BigZ]()
    values.append(bigz_from_i64(1))
    return poly_from_coeffs(values)


def poly_coefficient(value: PolyZ, index: Int) -> BigZ:
    if value.rejected or index < 0 or index >= len(value.coeffs):
        return bigz_zero()
    return value.coeffs[index].copy()


def poly_equal(left: PolyZ, right: PolyZ) -> Bool:
    if left.rejected or right.rejected or len(left.coeffs) != len(right.coeffs):
        return False
    for index in range(len(left.coeffs)):
        if not bigz_eq(left.coeffs[index], right.coeffs[index]):
            return False
    return True


def poly_add(left: PolyZ, right: PolyZ) -> PolyZ:
    if left.rejected or right.rejected:
        return rejected_poly()
    var width = len(left.coeffs)
    if len(right.coeffs) > width:
        width = len(right.coeffs)
    var values = List[BigZ]()
    for index in range(width):
        values.append(bigz_add(poly_coefficient(left, index), poly_coefficient(right, index)))
    return poly_from_coeffs(values)


def poly_sub(left: PolyZ, right: PolyZ) -> PolyZ:
    if left.rejected or right.rejected:
        return rejected_poly()
    var width = len(left.coeffs)
    if len(right.coeffs) > width:
        width = len(right.coeffs)
    var values = List[BigZ]()
    for index in range(width):
        values.append(bigz_sub(poly_coefficient(left, index), poly_coefficient(right, index)))
    return poly_from_coeffs(values)


def poly_mul(left: PolyZ, right: PolyZ) -> PolyZ:
    if left.rejected or right.rejected:
        return rejected_poly()
    if (
        len(left.coeffs) == 1 and left.coeffs[0].is_zero()
    ) or (
        len(right.coeffs) == 1 and right.coeffs[0].is_zero()
    ):
        return PolyZ()

    var values = List[BigZ]()
    for _ in range(len(left.coeffs) + len(right.coeffs) - 1):
        values.append(bigz_zero())
    for i in range(len(left.coeffs)):
        for j in range(len(right.coeffs)):
            values[i + j] = bigz_add(
                values[i + j],
                bigz_mul(left.coeffs[i], right.coeffs[j]),
            )
    return poly_from_coeffs(values)


def poly_xn_minus_one(exponent: Int) -> PolyZ:
    if exponent < 1:
        return rejected_poly()
    var values = List[BigZ]()
    for _ in range(exponent + 1):
        values.append(bigz_zero())
    values[0] = bigz_from_i64(-1)
    values[exponent] = bigz_from_i64(1)
    return poly_from_coeffs(values)


def poly_is_monic(value: PolyZ) -> Bool:
    return (
        not value.rejected and
        bigz_eq(value.coeffs[len(value.coeffs) - 1], bigz_from_i64(1))
    )


def poly_div_exact_monic(dividend: PolyZ, divisor: PolyZ) -> PolyDivResult:
    """Exact division by a monic BigZ polynomial; reject on any remainder."""
    if dividend.rejected or divisor.rejected or not poly_is_monic(divisor):
        return rejected_division()
    if len(divisor.coeffs) == 1:
        if bigz_eq(divisor.coeffs[0], bigz_from_i64(1)):
            var identity = PolyDivResult()
            identity.quotient = dividend.copy()
            return identity^
        return rejected_division()

    var dividend_degree = dividend.degree()
    var divisor_degree = divisor.degree()
    if dividend_degree < divisor_degree:
        if len(dividend.coeffs) == 1 and dividend.coeffs[0].is_zero():
            return PolyDivResult()
        return rejected_division()

    var work = List[BigZ]()
    for coefficient in dividend.coeffs:
        work.append(coefficient.copy())

    var quotient_coeffs = List[BigZ]()
    for _ in range(dividend_degree - divisor_degree + 1):
        quotient_coeffs.append(bigz_zero())

    var k = dividend_degree
    while k >= divisor_degree:
        var lead = work[k].copy()
        var shift = k - divisor_degree
        quotient_coeffs[shift] = lead.copy()
        if not lead.is_zero():
            for j in range(divisor_degree + 1):
                work[shift + j] = bigz_sub(
                    work[shift + j],
                    bigz_mul(lead, divisor.coeffs[j]),
                )
        k -= 1

    for index in range(divisor_degree):
        if not work[index].is_zero():
            return rejected_division()

    var out = PolyDivResult()
    out.quotient = poly_from_coeffs(quotient_coeffs)
    if out.quotient.rejected:
        out.rejected = True
    return out^


def cyclotomic_polynomial(conductor: Int) -> PolyZ:
    """Phi_n by x^n-1 = product_(d|n) Phi_d, built bottom-up exactly."""
    if conductor < 1:
        return rejected_poly()

    var table = List[PolyZ]()
    for n in range(1, conductor + 1):
        var current = poly_xn_minus_one(n)
        for divisor in range(1, n):
            if n % divisor == 0:
                var division = poly_div_exact_monic(current, table[divisor - 1])
                if division.rejected:
                    return rejected_poly()
                current = division.quotient.copy()
        if not poly_is_monic(current):
            return rejected_poly()
        table.append(current.copy())
    return table[conductor - 1].copy()


def cyclotomic_degree(conductor: Int) -> Int:
    var value = cyclotomic_polynomial(conductor)
    return value.degree()


def cyclotomic_product_identity(conductor: Int) -> Bool:
    """Check product_(d|n) Phi_d = x^n - 1 exactly."""
    if conductor < 1:
        return False
    var product = poly_one()
    for divisor in range(1, conductor + 1):
        if conductor % divisor == 0:
            product = poly_mul(product, cyclotomic_polynomial(divisor))
            if product.rejected:
                return False
    return poly_equal(product, poly_xn_minus_one(conductor))
