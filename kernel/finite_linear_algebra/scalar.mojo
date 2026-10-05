"""Integer lifts into `finite_exact.Q` and the fail-closed zero test.

`finite_exact` reports invalid arithmetic through a `rejected` flag and never
raises. The linear algebra here is seeded from integer data, so a rejected
scalar reaching a pivot decision is an impossible state: `q_is_zero` aborts
rather than returning a value that could be misread as a zero or a nonzero
pivot. Callers that need a recoverable failure test `rejected` before calling.
"""

from std.os import abort

from finite_exact.rat_q import Q


def q_int(n: Int) -> Q:
    return Q.from_int(Int64(n))


def q_vec(v: List[Int]) -> List[Q]:
    """Lift an integer vector into Q^n."""
    var out = List[Q]()
    for i in range(len(v)):
        out.append(q_int(v[i]))
    return out^


def q_is_zero(x: Q) -> Bool:
    """Zero test of an accepted value; a rejected operand aborts."""
    if x.rejected:
        abort("zero test of a rejected exact rational")
    return x.num.is_zero()
