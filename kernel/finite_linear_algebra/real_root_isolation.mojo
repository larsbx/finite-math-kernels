"""Every real root of a polynomial over Q, as ascending disjoint brackets.

The Sturm chain of `finite_linear_algebra/sturm_sequence.mojo` separates the
roots; once an interval holds one sign-variation unit, bisection on the sign
of the squarefree part alone narrows it. References: C. Sturm, "Memoire sur
la resolution des equations numeriques", Bulletin des Sciences de Ferussac 11
(1829) 419-422; S. Basu, R. Pollack and M.-F. Roy, *Algorithms in Real
Algebraic Geometry* (2nd ed., Springer, 2006), section 10.2 (real root
isolation by Sturm sequences); specification:
docs/exact-polynomial-root-isolation-spec.md, section 6a. The executable
reference written before this kernel is `reference/qpoly_reference.py`.

Nothing here names a root: a root is a bracket, and a bracket is two
rationals. Every bracket carries a sign change of the squarefree part, which
the intermediate value theorem reads as a root. That the brackets are all of
the real roots, one in each, is Sturm's theorem, which this package does not
prove; a consumer that reads the list as complete is importing it.
"""

from std.os import abort

from finite_exact.rat_q import Q
from finite_linear_algebra.cauchy_bound import root_bound
from finite_linear_algebra.qpoly import degree, evaluate, normalize, sign_of, squarefree_part
from finite_linear_algebra.scalar import q_int, q_is_zero
from finite_linear_algebra.sturm_sequence import RootBracket, sturm_chain, variation_difference


struct RootBrackets(Copyable, Movable):
    """Ascending brackets, or a refusal. Never a list of roots."""

    var rejected: Bool
    var brackets: List[RootBracket]

    def __init__(out self, rejected: Bool, var brackets: List[RootBracket]):
        self.rejected = rejected
        self.brackets = brackets^


def refused_brackets() -> RootBrackets:
    return RootBrackets(True, List[RootBracket]())


struct PendingInterval(Copyable, Movable):
    var lo: Q
    var hi: Q
    var count: Int

    def __init__(out self, lo: Q, hi: Q, count: Int):
        self.lo = lo.copy()
        self.hi = hi.copy()
        self.count = count


def split_point(s: List[Q], lo: Q, hi: Q) -> Q:
    """The first of `lo + (hi - lo)/j`, `j = 2, 3, ...`, at which `s` is nonzero."""
    var span = hi.sub(lo)
    for j in range(2, degree(s) + 3):
        var point = lo.add(span.div(q_int(j)))
        if not q_is_zero(evaluate(s, point)):
            return point^
    abort("more roots than the degree; an impossible state")


def halve_bracket(s: List[Q], lo: Q, hi: Q) -> RootBracket:
    """The side of the split point that keeps the sign change of `s`."""
    var point = split_point(s, lo, hi)
    if sign_of(evaluate(s, lo)) * sign_of(evaluate(s, point)) < 0:
        return RootBracket(True, False, lo, point)
    return RootBracket(True, False, point, hi)


def real_root_brackets(p: List[Q], width: Q, max_steps: Int) -> RootBrackets:
    """Ascending brackets, one per sign-variation unit, or a refusal.

    Every bracket has `lo < hi`, width at most `width`, and opposite nonzero
    signs of the squarefree part at its ends; consecutive brackets satisfy
    `hi <= lo`. The zero polynomial and an exhausted `max_steps` are refused.
    """
    var value = normalize(p)
    if len(value) == 0:
        return refused_brackets()
    var out = List[RootBracket]()
    if degree(value) < 1:
        return RootBrackets(False, out^)
    var square_free = squarefree_part(value)
    var chain = sturm_chain(value)
    var bound = root_bound(value)
    var low = bound.neg()
    var steps = 0
    var pending = List[PendingInterval]()
    pending.append(PendingInterval(low, bound, variation_difference(chain, low, bound)))
    while len(pending) > 0:
        var item = pending.pop()
        if item.count == 0:
            continue
        if steps >= max_steps:
            return refused_brackets()
        steps += 1
        if item.count == 1:
            if item.hi.sub(item.lo).le(width):
                out.append(RootBracket(True, False, item.lo, item.hi))
            else:
                var half = halve_bracket(square_free, item.lo, item.hi)
                pending.append(PendingInterval(half.lo, half.hi, 1))
            continue
        var point = split_point(square_free, item.lo, item.hi)
        var left = variation_difference(chain, item.lo, point)
        pending.append(PendingInterval(point, item.hi, item.count - left))
        pending.append(PendingInterval(item.lo, point, left))
    return RootBrackets(False, out^)
