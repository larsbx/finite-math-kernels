"""Exact polynomials over Q: arithmetic, division, gcd, squarefree part.

Specification: docs/exact-polynomial-root-isolation-spec.md. The executable
reference written before this kernel is `reference/qpoly_reference.py`.

A polynomial is `List[Q]` in ascending degree, normalized so that its last
coefficient is nonzero; the empty list is zero. The named results built on
this arithmetic live in modules named after them, each citing its source:
`cauchy_bound` (the Cauchy root bound), `sturm_sequence` (the Sturm chain,
sign variations and the isolating bracket of the largest real root) and
`faddeev_leverrier` (the characteristic polynomial in any dimension). Their
names are re-exported below unchanged, so `from finite_linear_algebra.qpoly
import ...` keeps working.
"""

from std.os import abort

from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_int, q_is_zero
from finite_linear_algebra.cauchy_bound import root_bound
from finite_linear_algebra.faddeev_leverrier import charpoly
from finite_linear_algebra.sturm_sequence import (
    RootBracket,
    largest_root_bracket,
    refused_bracket,
    sign_variations,
    sturm_chain,
    variation_difference,
)


def normalize(p: List[Q]) -> List[Q]:
    """Drop trailing zero coefficients."""
    var width = len(p)
    while width > 0 and q_is_zero(p[width - 1]):
        width -= 1
    var out = List[Q]()
    for i in range(width):
        out.append(p[i].copy())
    return out^


def degree(p: List[Q]) -> Int:
    """`-1` for the zero polynomial."""
    return len(normalize(p)) - 1


def evaluate(p: List[Q], x: Q) -> Q:
    """Horner from the top. One occurrence of `x` per step."""
    var total = Q.zero()
    for index in range(len(p)):
        total = total.mul(x).add(p[len(p) - 1 - index])
    return total^


def derivative(p: List[Q]) -> List[Q]:
    var out = List[Q]()
    for k in range(1, len(p)):
        out.append(q_int(k).mul(p[k]))
    return normalize(out)


def neg(p: List[Q]) -> List[Q]:
    var out = List[Q]()
    for i in range(len(p)):
        out.append(p[i].neg())
    return normalize(out)


def scale(p: List[Q], factor: Q) -> List[Q]:
    var out = List[Q]()
    for i in range(len(p)):
        out.append(factor.mul(p[i]))
    return normalize(out)


def coefficient(p: List[Q], k: Int) -> Q:
    if k < len(p):
        return p[k].copy()
    return Q.zero()


def add(a: List[Q], b: List[Q]) -> List[Q]:
    var width = len(a) if len(a) > len(b) else len(b)
    var out = List[Q]()
    for k in range(width):
        out.append(coefficient(a, k).add(coefficient(b, k)))
    return normalize(out)


def sub(a: List[Q], b: List[Q]) -> List[Q]:
    return add(a, neg(b))


def mul(a: List[Q], b: List[Q]) -> List[Q]:
    var left = normalize(a)
    var right = normalize(b)
    if len(left) == 0 or len(right) == 0:
        return List[Q]()
    var out = List[Q]()
    for _ in range(len(left) + len(right) - 1):
        out.append(Q.zero())
    for i in range(len(left)):
        for j in range(len(right)):
            out[i + j] = out[i + j].add(left[i].mul(right[j]))
    return normalize(out)


struct QPolyDivision(Copyable, Movable):
    """`a = quotient * b + remainder`, or a refusal to divide by zero."""

    var quotient: List[Q]
    var remainder: List[Q]
    var rejected: Bool

    def __init__(out self, var quotient: List[Q], var remainder: List[Q], rejected: Bool):
        self.quotient = quotient^
        self.remainder = remainder^
        self.rejected = rejected


def divide(a: List[Q], b: List[Q]) -> QPolyDivision:
    """Euclidean division over a field: exact at every step, no content."""
    var divisor = normalize(b)
    var rest = normalize(a)
    if len(divisor) == 0:
        return QPolyDivision(List[Q](), List[Q](), True)
    var span = len(rest) - len(divisor) + 1
    var quotient = List[Q]()
    for _ in range(span if span > 0 else 0):
        quotient.append(Q.zero())
    while len(rest) >= len(divisor):
        var shift = len(rest) - len(divisor)
        var factor = rest[len(rest) - 1].div(divisor[len(divisor) - 1])
        quotient[shift] = factor.copy()
        for k in range(len(divisor)):
            rest[shift + k] = rest[shift + k].sub(factor.mul(divisor[k]))
        rest = normalize(rest)
    return QPolyDivision(normalize(quotient), rest^, False)


def remainder(a: List[Q], b: List[Q]) -> List[Q]:
    """The remainder alone. A zero divisor is an impossible state here."""
    var result = divide(a, b)
    if result.rejected:
        abort("polynomial remainder by the zero polynomial")
    return result.remainder.copy()


def monic(p: List[Q]) -> List[Q]:
    var value = normalize(p)
    if len(value) == 0:
        return value^
    return scale(value, Q.one().div(value[len(value) - 1]))


def gcd(a: List[Q], b: List[Q]) -> List[Q]:
    """The monic associate of the last nonzero remainder."""
    var left = normalize(a)
    var right = normalize(b)
    while len(right) > 0:
        var next = remainder(left, right)
        left = right^
        right = next^
    return monic(left)


def squarefree_part(p: List[Q]) -> List[Q]:
    """`p / gcd(p, p')`: the same roots, each of them simple."""
    var value = normalize(p)
    if degree(value) < 1:
        return value^
    var result = divide(value, gcd(value, derivative(value)))
    if result.rejected or len(result.remainder) > 0:
        abort("the gcd did not divide; an impossible state")
    return result.quotient.copy()


def sign_of(value: Q) -> Int:
    if q_is_zero(value):
        return 0
    if value.lt(Q.zero()):
        return -1
    return 1
