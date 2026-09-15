"""The degree-3 tensor ambient space V^{(x)3} = Q^27 with lex coordinates.

Index convention: slot `9*a + 3*b + c` carries `e_a (x) e_b (x) e_c`, `a,b,c` in
`{0,1,2}` (the alphabet `{1,2,3}` shifted to zero-based). This is the lex order
`(0,0,0), (0,0,1), ..., (2,2,2)` of the certificate.
"""

from finite_linear_algebra.mat3 import Mat3
from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_int


def idx3(a: Int, b: Int, c: Int) -> Int:
    return 9 * a + 3 * b + c


def zeros27() -> List[Int]:
    var v = List[Int]()
    for _ in range(27):
        v.append(0)
    return v^


def shuffle_image(x: List[Int]) -> List[Int]:
    """The degree-3 shuffle functional `S`.

    `S(x)_{abc} = x_{abc} + x_{bac} + x_{bca}`.

    This is the *coordinate* form. It is the transpose of the basis-vector
    formula printed in PROOF_CERTIFICATE.md §3; the coordinate form is the one
    that annihilates the seed vectors (see docs/verification-architecture.md,
    "Discrepancy D1").
    """
    var out = zeros27()
    for a in range(3):
        for b in range(3):
            for c in range(3):
                out[idx3(a, b, c)] = (
                    x[idx3(a, b, c)] + x[idx3(b, a, c)] + x[idx3(b, c, a)]
                )
    return out^


def shuffle_matrix() -> List[List[Q]]:
    """`S` as a 27x27 rational matrix, derived from `shuffle_image`."""
    var rows = List[List[Q]]()
    for _ in range(27):
        rows.append(List[Q]())
    for col in range(27):
        var e = zeros27()
        e[col] = 1
        var img = shuffle_image(e)
        for row in range(27):
            rows[row].append(q_int(img[row]))
    return rows^


def tensor_cube_apply(m: Mat3, x: List[Int]) -> List[Int]:
    """`(M^{(x)3} x)_{abc} = sum_{ijk} M_{ai} M_{bj} M_{ck} x_{ijk}`."""
    var out = zeros27()
    for a in range(3):
        for b in range(3):
            for c in range(3):
                var s = 0
                for i in range(3):
                    for j in range(3):
                        for k in range(3):
                            var coeff = m.at(a, i) * m.at(b, j) * m.at(c, k)
                            if coeff != 0:
                                s += coeff * x[idx3(i, j, k)]
                out[idx3(a, b, c)] = s
    return out^


def levi_civita(i: Int, j: Int, k: Int) -> Int:
    if i == j or j == k or i == k:
        return 0
    return 1 if (j - i) * (k - j) * (k - i) > 0 else -1


def theta(x: List[Int]) -> Mat3:
    """Levi-Civita contraction `Theta(x)_{ij} = sum_{k,l} eps_{jkl} x_{ikl}`.

    Restricted to `W_3` this is the identification `W_3 ~ sl_3(Q)`.
    """
    var out = List[Int]()
    for i in range(3):
        for j in range(3):
            var s = 0
            for k in range(3):
                for l in range(3):
                    var e = levi_civita(j, k, l)
                    if e != 0:
                        s += e * x[idx3(i, k, l)]
            out.append(s)
    return Mat3(out)


def is_zero27(x: List[Int]) -> Bool:
    for i in range(27):
        if x[i] != 0:
            return False
    return True
