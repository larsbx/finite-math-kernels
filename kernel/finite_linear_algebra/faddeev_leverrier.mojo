"""The characteristic polynomial in any dimension, by Faddeev-LeVerrier.

The recurrence `M_k = m M_(k-1) + c_(k-1) m`, `c_k = -trace(M_k) / k` (with
`M_0 = 0`, `c_0 = 1`) yields the coefficients of `det(x I - m)` from traces
alone. References: U. J. J. Le Verrier, "Sur les variations seculaires des
elements des orbites pour les sept planetes principales", J. Math. Pures
Appl. 5 (1840) 220-254; D. K. Faddeev and I. S. Sominsky, *Problems in Higher
Algebra* (1949); D. K. Faddeev and V. N. Faddeeva, *Computational Methods of
Linear Algebra* (Freeman, 1963), section 24; specification:
docs/exact-polynomial-root-isolation-spec.md, section 7.

`charpoly` was previously in `finite_linear_algebra/qpoly.mojo`, which still
re-exports it.
"""

from finite_exact.rat_q import Q


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
