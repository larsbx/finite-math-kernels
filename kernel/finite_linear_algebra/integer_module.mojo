"""Canonical embedded integer-module normal form.

Rows are generators of an embedded subgroup L <= Z^d. row_hnf returns the
unique nonzero row Hermite normal form under the convention:

- pivot columns increase strictly from top to bottom;
- every pivot is positive;
- entries below each pivot are zero;
- entries above a pivot lie in [0, pivot).

This identifies the embedded subgroup in the declared coordinate basis.
It is stronger than rational rank/span and stronger than Smith invariant
factors alone.

All integer arithmetic uses unbounded BigZ. The normal form itself, `row_hnf`
and `row_hnf_equal`, lives in `hermite_normal_form.mojo` (Hermite 1851), which
cites it; both are re-exported here unchanged.
"""

from finite_exact.bigint_z import (
    BigZ,
    bigz_abs,
    bigz_add,
    bigz_divmod,
    bigz_eq,
    bigz_from_i64,
    bigz_is_canonical,
    bigz_mul,
    bigz_neg,
    bigz_sub,
    bigz_zero,
)
from finite_linear_algebra.hermite_normal_form import row_hnf, row_hnf_equal


struct BezoutResult(Copyable):
    var gcd: BigZ
    var x: BigZ
    var y: BigZ

    def __init__(out self):
        self.gcd = BigZ()
        self.x = BigZ()
        self.y = BigZ()


def _bezout(a: BigZ, b: BigZ) raises -> BezoutResult:
    """g = x*a + y*b, with g >= 0."""
    if a.is_zero() and b.is_zero():
        raise Error("Bezout coefficients are undefined for two zero inputs")

    var aa = bigz_abs(a)
    var bb = bigz_abs(b)
    var old_r = aa.copy()
    var r = bb.copy()
    var old_s = bigz_from_i64(1)
    var s = bigz_zero()
    var old_t = bigz_zero()
    var t = bigz_from_i64(1)

    while not r.is_zero():
        var division = bigz_divmod(old_r, r)
        if division.rejected:
            raise Error("BigZ division rejected inside Bezout computation")
        var q = division.quotient.copy()

        var next_r = bigz_sub(old_r, bigz_mul(q, r))
        old_r = r.copy()
        r = next_r^

        var next_s = bigz_sub(old_s, bigz_mul(q, s))
        old_s = s.copy()
        s = next_s^

        var next_t = bigz_sub(old_t, bigz_mul(q, t))
        old_t = t.copy()
        t = next_t^

    var out = BezoutResult()
    out.gcd = old_r.copy()
    if a.sign >= 0:
        out.x = old_s.copy()
    else:
        out.x = bigz_neg(old_s)
    if b.sign >= 0:
        out.y = old_t.copy()
    else:
        out.y = bigz_neg(old_t)

    var check = bigz_add(bigz_mul(out.x, a), bigz_mul(out.y, b))
    if not bigz_eq(check, out.gcd):
        raise Error("Bezout identity replay failed")
    return out^


def _row_copy(row: List[BigZ]) -> List[BigZ]:
    var out = List[BigZ]()
    for i in range(len(row)):
        out.append(row[i].copy())
    return out^


def _row_linear(
    left_scale: BigZ,
    left: List[BigZ],
    right_scale: BigZ,
    right: List[BigZ],
) raises -> List[BigZ]:
    if len(left) != len(right):
        raise Error("integer-module row dimensions disagree")
    var out = List[BigZ]()
    for j in range(len(left)):
        out.append(
            bigz_add(
                bigz_mul(left_scale, left[j]),
                bigz_mul(right_scale, right[j]),
            )
        )
    return out^


def _row_neg(row: List[BigZ]) -> List[BigZ]:
    var out = List[BigZ]()
    for j in range(len(row)):
        out.append(bigz_neg(row[j]))
    return out^


def _row_is_zero(row: List[BigZ]) -> Bool:
    for j in range(len(row)):
        if not row[j].is_zero():
            return False
    return True


def _floor_div_positive(dividend: BigZ, positive_divisor: BigZ) raises -> BigZ:
    """floor(dividend / positive_divisor), divisor required > 0."""
    if positive_divisor.sign <= 0:
        raise Error("floor division requires a positive divisor")
    var division = bigz_divmod(dividend, positive_divisor)
    if division.rejected:
        raise Error("BigZ division rejected in HNF reduction")
    var q = division.quotient.copy()
    if division.remainder.sign < 0:
        q = bigz_sub(q, bigz_from_i64(1))
    return q^


def _validate_rows(rows: List[List[BigZ]], dimension: Int) raises:
    if dimension < 0:
        raise Error("integer-module dimension cannot be negative")
    for i in range(len(rows)):
        if len(rows[i]) != dimension:
            raise Error("integer-module generator dimension mismatch")
        for j in range(dimension):
            if not bigz_is_canonical(rows[i][j]):
                raise Error("integer-module generator contains malformed BigZ")


def i64_row(values: List[Int64]) -> List[BigZ]:
    var out = List[BigZ]()
    for value in values:
        out.append(bigz_from_i64(value))
    return out^
