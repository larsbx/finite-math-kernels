"""Exact polynomials over Q: division, gcd, the Sturm chain, and isolation.

Specification: docs/exact-polynomial-root-isolation-spec.md. The executable
reference written before this kernel is `tools/qpoly_reference.py`.

A polynomial is `List[Q]` in ascending degree, normalized so that its last
coefficient is nonzero; the empty list is zero. Nothing here names a root: a
root is a bracket, and a bracket is two rationals. What a difference of
sign-variation counts counts is Sturm's theorem, which this package does not
prove and does not restate; section 5 of the specification says so, and a
consumer that reads a root count is importing it.
"""

from std.os import abort

from finite_exact.rat_q import Q, q_abs, q_max
from finite_linear_algebra.scalar import q_int, q_is_zero


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


def root_bound(p: List[Q]) -> Q:
    """`1 + max |p[k]| / |lead|`, above every real root in magnitude."""
    var value = normalize(p)
    if degree(value) < 1:
        abort("a root bound needs degree at least one")
    var lead = q_abs(value[len(value) - 1])
    var largest = Q.zero()
    for k in range(len(value) - 1):
        largest = q_max(largest, q_abs(value[k]))
    return Q.one().add(largest.div(lead))


def sturm_chain(p: List[Q]) -> List[List[Q]]:
    """`s, s'`, then negated remainders, for `s` the squarefree part."""
    var start = squarefree_part(p)
    var chain = List[List[Q]]()
    if degree(start) < 1:
        if len(start) > 0:
            chain.append(start^)
        return chain^
    chain.append(start.copy())
    chain.append(derivative(start))
    while len(chain[len(chain) - 1]) > 0:
        chain.append(neg(remainder(chain[len(chain) - 2], chain[len(chain) - 1])))
    _ = chain.pop()
    return chain^


def sign_of(value: Q) -> Int:
    if q_is_zero(value):
        return 0
    if value.lt(Q.zero()):
        return -1
    return 1


def sign_variations(chain: List[List[Q]], x: Q) -> Int:
    """Sign changes among the nonzero values of the chain at `x`."""
    var previous = 0
    var count = 0
    for i in range(len(chain)):
        var current = sign_of(evaluate(chain[i], x))
        if current == 0:
            continue
        if previous != 0 and current != previous:
            count += 1
        previous = current
    return count


def variation_difference(chain: List[List[Q]], a: Q, b: Q) -> Int:
    """`V(a) - V(b)`. A finite fact; Sturm's theorem is what counts with it."""
    return sign_variations(chain, a) - sign_variations(chain, b)


struct RootBracket(Copyable, Movable):
    """Two rationals, or a refusal. Never a root."""

    var found: Bool
    var exact: Bool
    var lo: Q
    var hi: Q

    def __init__(out self, found: Bool, exact: Bool, lo: Q, hi: Q):
        self.found = found
        self.exact = exact
        self.lo = lo.copy()
        self.hi = hi.copy()


def refused_bracket() -> RootBracket:
    return RootBracket(False, False, Q.zero(), Q.zero())


def largest_root_bracket(p: List[Q], width: Q, max_steps: Int) -> RootBracket:
    """An isolating bracket of the largest real root, or a refusal.

    The invariant is that the squarefree part vanishes at neither endpoint and
    the largest real root lies strictly between them, so the bracket carries a
    sign change of that part whatever a reader thinks of Sturm.
    """
    var value = normalize(p)
    if degree(value) < 1:
        return refused_bracket()
    var square_free = squarefree_part(value)
    var chain = sturm_chain(value)
    var bound = root_bound(value)
    var lo = bound.neg()
    var hi = bound.copy()
    if variation_difference(chain, lo, hi) == 0:
        return refused_bracket()
    var half = Q(1, 2)
    for _ in range(max_steps):
        var middle = lo.add(hi).mul(half)
        if q_is_zero(evaluate(square_free, middle)):
            if variation_difference(chain, middle, hi) == 0:
                return RootBracket(True, True, middle, middle)
            lo = middle.copy()
        elif variation_difference(chain, middle, hi) >= 1:
            lo = middle.copy()
        else:
            hi = middle.copy()
        if hi.sub(lo).le(width) and variation_difference(chain, lo, hi) == 1:
            return RootBracket(True, False, lo, hi)
    return refused_bracket()


def charpoly(m: List[List[Q]]) -> List[Q]:
    """`det(x I - m)` as ascending coefficients, by Faddeev-LeVerrier.

    Monic by construction and defined in every dimension, which is what
    `finite_linear_algebra/mat3.mojo` supplies only for `3x3`. Specification:
    docs/exact-polynomial-root-isolation-spec.md, section 7. The recurrence is
    `M_k = m M_(k-1) + c_(k-1) m` with `c_k = -trace(M_k) / k`; the division by
    `k` is why it is stated over Q for an integer matrix.

    It lives here rather than in `qlinalg` because `qlinalg` is an imported
    copy and this is authored work; section 7 of the specification says so.
    """
    var out = List[Q]()
    var size = len(m)
    if size == 0:
        out.append(Q.one())
        return out^
    var current = List[List[Q]]()
    for _ in range(size):
        var row = List[Q]()
        for _ in range(size):
            row.append(Q.zero())
        current.append(row^)
    var coefficients = List[Q]()
    coefficients.append(Q.one())
    for step in range(1, size + 1):
        var tail = coefficients[len(coefficients) - 1].copy()
        var updated = List[List[Q]]()
        for i in range(size):
            var row = List[Q]()
            for j in range(size):
                var total = Q.zero()
                for k in range(size):
                    total = total.add(m[i][k].mul(current[k][j]))
                row.append(total.add(tail.mul(m[i][j])))
            updated.append(row^)
        current = updated^
        var trace = Q.zero()
        for i in range(size):
            trace = trace.add(current[i][i])
        coefficients.append(trace.neg().div(Q.from_int(Int64(step))))
    for i in range(len(coefficients)):
        out.append(coefficients[len(coefficients) - 1 - i].copy())
    return out^
