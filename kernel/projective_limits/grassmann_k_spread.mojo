# Exact guarded k-plane Gram-overlap spread for split quadratic eight-spaces.
# k in [1,4] is a bounded algorithmic choice, NOT a bound on coherence rank.
# All field arithmetic uses the authoritative ExactField and B2/2 pairing.
# Projective/Grassmann states require nondegenerate restricted Gram forms.
# No real-valued angles, singular inverses, optimization or tensor semantics.
from finite_exact.field import ExactField
from projective_limits.hyperbolic_rt import valid8
from projective_limits.gram_geometry import gram_pair8


def factorial(n: Int) -> Int:
    var result = 1
    for i in range(2, n + 1):
        result *= i
    return result


def unrank(n: Int, index: Int) -> List[Int]:
    """Finite factorial-index permutation; caller constrains n<=4."""
    var out = List[Int]()
    var used = List[Bool]()
    for _ in range(n):
        used.append(False)
    var remaining = index
    for i in range(n):
        var factor = factorial(n - i - 1)
        var ordinal = remaining // factor
        remaining %= factor
        var seen = 0
        var chosen = -1
        for label in range(n):
            if not used[label]:
                if seen == ordinal:
                    chosen = label
                    break
                seen += 1
        if chosen < 0:
            return List[Int]()
        used[chosen] = True
        out.append(chosen)
    return out^


def det_small[K: ExactField](matrix: List[List[K.Element]]) -> K.Element:
    """Exact Leibniz determinant up to 4x4 (24 terms). No division."""
    var n = len(matrix)
    if n < 1 or n > 4:
        return K.rejected()
    for i in range(n):
        if len(matrix[i]) != n:
            return K.rejected()
        for j in range(n):
            if not K.accepted(matrix[i][j]):
                return K.rejected()
    var total = K.zero()
    for index in range(factorial(n)):
        var permutation = unrank(n, index)
        var inversions = 0
        var product = K.one()
        for i in range(n):
            for j in range(i + 1, n):
                if permutation[i] > permutation[j]:
                    inversions += 1
            product = K.mul(product, matrix[i][permutation[i]])
        if inversions % 2 != 0:
            product = K.neg(product)
        total = K.add(total, product)
    return total


def gram_block8[K: ExactField](
    first: List[List[K.Element]],
    second: List[List[K.Element]]
) -> List[List[K.Element]]:
    """Cross Gram block (B2/2) with exact pairings; invalid = rejected rows."""
    var out = List[List[K.Element]]()
    if len(first) != len(second) or len(first) < 1 or len(first) > 4:
        return out^
    for i in range(len(first)):
        if not valid8[K](first[i]) or not valid8[K](second[i]):
            return List[List[K.Element]]()
    for i in range(len(first)):
        var row = List[K.Element]()
        for j in range(len(second)):
            row.append(gram_pair8[K](first[i], second[j]))
        out.append(row^)
    return out^


def k_plane_spread8[K: ExactField](
    first: List[List[K.Element]],
    second: List[List[K.Element]]
) -> K.Element:
    """1 - det(G_uv)^2 / (det(G_uu)*det(G_vv)) for nondegenerate k-planes.

    Each ordered basis has k nonzero, independent vectors (nondegeneracy
    entails independence). Invalid dimensions, null restricted forms, and
    characteristic two reject explicitly.
    """
    var k = len(first)
    if k < 1 or k > 4 or len(second) != k:
        return K.rejected()
    if K.is_zero(K.from_int(2)):
        return K.rejected()
    var own1 = gram_block8[K](first, first)
    var own2 = gram_block8[K](second, second)
    var mixed = gram_block8[K](first, second)
    if len(own1) != k or len(own2) != k or len(mixed) != k:
        return K.rejected()
    var det1 = det_small[K](own1)
    var det2 = det_small[K](own2)
    var cross = det_small[K](mixed)
    if not K.accepted(det1) or not K.accepted(det2) or not K.accepted(cross):
        return K.rejected()
    if K.is_zero(det1) or K.is_zero(det2):
        return K.rejected()
    var denominator = K.mul(det1, det2)
    if not K.accepted(denominator) or K.is_zero(denominator):
        return K.rejected()
    return K.sub(K.one(), K.div(K.mul(cross, cross), denominator))


def guarded_k_plane_spread8[K: ExactField](
    first: List[List[K.Element]],
    second: List[List[K.Element]],
    gate: List[K.Element]
) -> Bool:
    """Finite-field policy membership; no intrinsic ordered threshold."""
    var value = k_plane_spread8[K](first, second)
    if not K.accepted(value):
        return False
    for candidate in gate:
        if K.accepted(candidate) and K.eq(candidate, value):
            return True
    return False
