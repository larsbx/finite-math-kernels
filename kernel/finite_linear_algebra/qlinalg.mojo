"""Exact linear algebra over Q: RREF, rank, nullspace, span membership.

Used to *derive* — never to transcribe — the shuffle-kernel sector W_3 and to
decide the membership statements of the Spectral module certificate.
Scalars are the unbounded rationals of the vendored `finite_exact` package;
`q_is_zero` aborts on a rejected scalar (an impossible state, not a pivot).
"""

from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_is_zero


def rref(m: List[List[Q]]) -> Tuple[List[List[Q]], List[Int]]:
    """Reduced row echelon form. Returns `(R, pivot_columns)`."""
    var r = List[List[Q]]()
    for i in range(len(m)):
        r.append(m[i].copy())
    var pivots = List[Int]()
    if len(r) == 0:
        return (r^, pivots^)
    var ncols = len(r[0])
    var row = 0
    for c in range(ncols):
        if row == len(r):
            break
        var p = -1
        for i in range(row, len(r)):
            if not q_is_zero(r[i][c]):
                p = i
                break
        if p < 0:
            continue
        r.swap_elements(row, p)
        var inv = r[row][c].copy()
        for j in range(ncols):
            r[row][j] = r[row][j].div(inv)
        for i in range(len(r)):
            if i != row and not q_is_zero(r[i][c]):
                var f = r[i][c].copy()
                for j in range(ncols):
                    r[i][j] = r[i][j].sub(f.mul(r[row][j]))
        pivots.append(c)
        row += 1
    return (r^, pivots^)


def rank(m: List[List[Q]]) -> Int:
    var res = rref(m)
    return len(res[1])


def nullspace(m: List[List[Q]], ncols: Int) -> List[List[Q]]:
    """Basis of `{x in Q^ncols : m . x = 0}`, one vector per free column."""
    var res = rref(m)
    ref r = res[0]
    ref pivots = res[1]
    var is_pivot = List[Bool]()
    for _ in range(ncols):
        is_pivot.append(False)
    for i in range(len(pivots)):
        is_pivot[pivots[i]] = True

    var basis = List[List[Q]]()
    for f in range(ncols):
        if is_pivot[f]:
            continue
        var v = List[Q]()
        for _ in range(ncols):
            v.append(Q.zero())
        v[f] = Q.one()
        for i in range(len(pivots)):
            v[pivots[i]] = r[i][f].neg()
        basis.append(v^)
    return basis^


def in_span(basis: List[List[Q]], v: List[Q]) -> Bool:
    """Whether `v` lies in the Q-span of `basis` (row vectors of equal length)."""
    var withv = List[List[Q]]()
    for i in range(len(basis)):
        withv.append(basis[i].copy())
    var base_rank = rank(withv)
    withv.append(v.copy())
    return rank(withv) == base_rank


def matvec(m: List[List[Q]], v: List[Q]) -> List[Q]:
    var out = List[Q]()
    for i in range(len(m)):
        var s = Q.zero()
        for j in range(len(v)):
            s = s.add(m[i][j].mul(v[j]))
        out.append(s^)
    return out^


def is_zero_vec(v: List[Q]) -> Bool:
    for i in range(len(v)):
        if not q_is_zero(v[i]):
            return False
    return True
