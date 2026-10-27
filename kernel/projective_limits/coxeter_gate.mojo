# Exact Coxeter square/hexagon *geometric gate* checks for finite RT routes.
#
# This is not a verifier of tensor-operator equivalence. Actual state-dependent
# effect equality at the genuine prefix belongs to rt_route.certified_swap8
# or a consumer-provided replay proof. Permutation equality is tautological.
# All division is delegated to guarded_spread8, which rejects null directions.
from finite_exact.field import ExactField
from projective_limits.rt_route import guarded_spread8
from projective_limits.hyperbolic_rt import valid8


def valid_ordering(ordering: List[Int], count: Int) -> Bool:
    """True exactly when ordering is a permutation of 0..count-1."""
    if count < 2 or len(ordering) != count:
        return False
    for i in range(count):
        if ordering[i] < 0 or ordering[i] >= count:
            return False
        for j in range(i):
            if ordering[j] == ordering[i]:
                return False
    return True


def adjacent_swap(ordering: List[Int], r: Int) -> List[Int]:
    """Copy and swap positions r and r+1 (0-based); empty on invalid index."""
    var out = List[Int]()
    if r < 0 or r + 1 >= len(ordering):
        return out^
    for i in range(len(ordering)):
        if i == r:
            out.append(ordering[r + 1])
        elif i == r + 1:
            out.append(ordering[r])
        else:
            out.append(ordering[i])
    return out^


def same_ordering(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def swap_gate_at_source8[K: ExactField](
    directions: List[List[K.Element]],
    ordering: List[Int],
    r: Int,
    gate: List[K.Element]
) -> Bool:
    """Evaluate spread on the pair occurring at THIS permutation source."""
    if not valid_ordering(ordering, len(directions)):
        return False
    if r < 0 or r + 1 >= len(ordering):
        return False
    var a = ordering[r]
    var b = ordering[r + 1]
    if not valid8[K](directions[a]) or not valid8[K](directions[b]):
        return False
    return guarded_spread8[K](directions[a], directions[b], gate)


def gated_swap_path8[K: ExactField](
    directions: List[List[K.Element]],
    start: List[Int],
    steps: List[Int],
    gate: List[K.Element]
) -> List[Int]:
    """Walk a declared sequence; empty list is a rejected path."""
    var rejected = List[Int]()
    if not valid_ordering(start, len(directions)):
        return rejected^
    var current = List[Int]()
    for i in range(len(start)):
        current.append(start[i])
    for j in range(len(steps)):
        var step = steps[j]
        if not swap_gate_at_source8[K](directions, current, step, gate):
            return rejected^
        current = adjacent_swap(current, step)
    return current^


def coxeter_square_gate8[K: ExactField](
    directions: List[List[K.Element]],
    start: List[Int],
    r: Int,
    s: Int,
    gate: List[K.Element]
) -> Bool:
    """Far-commutativity square: every boundary edge must be admitted."""
    if r < 0 or s < 0 or r >= s - 1 or s + 1 >= len(start):
        return False
    var rs = List[Int]()
    rs.append(r)
    rs.append(s)
    var sr = List[Int]()
    sr.append(s)
    sr.append(r)
    var left = gated_swap_path8[K](directions, start, rs, gate)
    var right = gated_swap_path8[K](directions, start, sr, gate)
    return len(left) == len(start) and same_ordering(left, right)


def coxeter_hexagon_gate8[K: ExactField](
    directions: List[List[K.Element]],
    start: List[Int],
    r: Int,
    gate: List[K.Element]
) -> Bool:
    """Braid hexagon: six source-state-specific swap gates; same endpoint."""
    if r < 0 or r + 2 >= len(start):
        return False
    var left_steps = List[Int]()
    left_steps.append(r)
    left_steps.append(r + 1)
    left_steps.append(r)
    var right_steps = List[Int]()
    right_steps.append(r + 1)
    right_steps.append(r)
    right_steps.append(r + 1)
    var left = gated_swap_path8[K](directions, start, left_steps, gate)
    var right = gated_swap_path8[K](directions, start, right_steps, gate)
    return len(left) == len(start) and same_ordering(left, right)
