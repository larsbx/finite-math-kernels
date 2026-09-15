"""The shuffle-kernel sector W_3 = ker(S) subset V^{(x)3}.

`w3_basis()` is *derived* from the shuffle functional by exact nullspace
elimination; `in_w3` decides membership directly by the defining relations;
`spans_same_space` compares an integer family with a rational one. A
consumer that carries a printed basis reproduces it separately and compares
the two with these functions.
"""

from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_vec
from finite_linear_algebra.qlinalg import nullspace, in_span, rank
from finite_linear_algebra.tensor3 import shuffle_matrix, shuffle_image, is_zero27


def w3_basis() -> List[List[Q]]:
    """A Q-basis of `ker(S)`, computed by exact nullspace elimination."""
    return nullspace(shuffle_matrix(), 27)


def in_w3(x: List[Int]) -> Bool:
    """Membership in `W_3`, decided directly by the defining relations."""
    return is_zero27(shuffle_image(x))


def spans_same_space(intbasis: List[List[Int]], qbasis: List[List[Q]]) -> Bool:
    """Whether an integer family and a rational family span the same subspace."""
    var lifted = List[List[Q]]()
    for i in range(len(intbasis)):
        lifted.append(q_vec(intbasis[i]))
    if rank(lifted) != len(qbasis):
        return False
    for i in range(len(qbasis)):
        if not in_span(lifted, qbasis[i]):
            return False
    return True
