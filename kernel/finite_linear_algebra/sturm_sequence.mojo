"""Sturm sequences over Q, sign variations, and root isolation by bisection.

The Sturm sequence of a squarefree `s` is `s, s'` followed by the negated
remainders of the Euclidean algorithm; by Sturm's theorem the number of
distinct real roots of `s` in `(a, b]` is `V(a) - V(b)`, the drop in sign
variations along the sequence. References: C. Sturm, "Memoire sur la
resolution des equations numeriques", Bulletin des Sciences de Ferussac 11
(1829) 419-422 (full memoir in Mem. Savants Etrangers 6, 1835); S. Basu,
R. Pollack and M.-F. Roy, *Algorithms in Real Algebraic Geometry* (2nd ed.,
Springer, 2006), section 2.2.2 and chapter 10; specification:
docs/exact-polynomial-root-isolation-spec.md. The executable reference
written before this kernel is `reference/qpoly_reference.py`.

Nothing here names a root: a root is a bracket, and a bracket is two
rationals. What a difference of sign-variation counts counts is Sturm's
theorem, which this package does not prove and does not restate; section 5 of
the specification says so, and a consumer that reads a root count is
importing it.

Previously in `finite_linear_algebra/qpoly.mojo`, which still re-exports
every name here.
"""

from finite_exact.rat_q import Q
from finite_linear_algebra.cauchy_bound import root_bound
from finite_linear_algebra.qpoly import degree, derivative, evaluate, neg, normalize, remainder, sign_of, squarefree_part
from finite_linear_algebra.scalar import q_is_zero


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
