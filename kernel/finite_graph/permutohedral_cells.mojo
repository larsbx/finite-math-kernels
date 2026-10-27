"""Exact finite permutohedral face-poset and signed CW boundary kernels.

Represent a face of P_n by n canonical block labels, e.g.
[0,0,1,1,2,3] denotes ((0,1),(2,3),(4),(5)) in P6.
A facet splits exactly one block into two nonempty ordered parts.
Orientation uses the exact integer outward (doubled barycenter) vector,
followed by canonical blockwise tangent bases; no floating geometry.
For this bounded Mojo kernel n in [2,6], with explicit fail-closed guards.
"""

def valid_face(face: List[Int], n: Int) -> Bool:
    if n < 2 or n > 6 or len(face) != n:
        return False
    var seen = List[Bool]()
    for _ in range(n):
        seen.append(False)
    var biggest = -1
    for i in range(n):
        var block = face[i]
        if block < 0 or block >= n:
            return False
        seen[block] = True
        if block > biggest:
            biggest = block
    for k in range(biggest + 1):
        if not seen[k]:
            return False
    return True


def block_count(face: List[Int]) -> Int:
    var count = 0
    for block in face:
        if block + 1 > count:
            count = block + 1
    return count


def face_dimension(face: List[Int], n: Int) -> Int:
    if not valid_face(face, n):
        return -1
    return n - block_count(face)


def same_face(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def facets(face: List[Int], n: Int) -> List[List[Int]]:
    """Generate only immediate ordered refinements of one requested face."""
    var result = List[List[Int]]()
    if not valid_face(face, n):
        return result^
    for target in range(block_count(face)):
        var labels = List[Int]()
        for i in range(n):
            if face[i] == target:
                labels.append(i)
        var size = len(labels)
        if size < 2:
            continue
        var variants = 1 << size
        for mask in range(1, variants - 1):
            var child = List[Int]()
            for i in range(n):
                var old = face[i]
                if old < target:
                    child.append(old)
                elif old > target:
                    child.append(old + 1)
                else:
                    var position = 0
                    for j in range(size):
                        if labels[j] == i:
                            position = j
                            break
                    if (mask & (1 << position)) != 0:
                        child.append(target)
                    else:
                        child.append(target + 1)
            result.append(child^)
    return result^


def doubled_center(face: List[Int], n: Int) -> List[Int]:
    """Twice the coordinate value at the center of each ordered block."""
    var out = List[Int]()
    for _ in range(n):
        out.append(0)
    if not valid_face(face, n):
        return out^
    var low = 1
    for block in range(block_count(face)):
        var size = 0
        for i in range(n):
            if face[i] == block:
                size += 1
        var high = low + size - 1
        for i in range(n):
            if face[i] == block:
                out[i] = low + high
        low = high + 1
    return out^


def tangent_rows(face: List[Int], n: Int) -> List[Int]:
    """Non-root coordinates form a coordinate chart of the face tangent."""
    var rows = List[Int]()
    if not valid_face(face, n):
        return rows^
    for block in range(block_count(face)):
        var root = -1
        for i in range(n):
            if face[i] == block:
                if root < 0:
                    root = i
                else:
                    rows.append(i)
    return rows^


def tangent_roots(face: List[Int], n: Int) -> List[Int]:
    """Return block root corresponding to each tangent nonroot coordinate."""
    var roots = List[Int]()
    if not valid_face(face, n):
        return roots^
    for block in range(block_count(face)):
        var root = -1
        for i in range(n):
            if face[i] == block:
                if root < 0:
                    root = i
                else:
                    roots.append(root)
    return roots^


def factorial(n: Int) -> Int:
    var result = 1
    for k in range(2, n + 1):
        result *= k
    return result


def permutation(n: Int, index: Int) -> List[Int]:
    """Factoradic unranking, on the bounded integer dimension n<=5."""
    var used = List[Bool]()
    var out = List[Int]()
    for _ in range(n):
        used.append(False)
    var remaining = index
    for position in range(n):
        var width = factorial(n - position - 1)
        var ordinal = remaining // width
        remaining %= width
        var rank = 0
        var selected = -1
        for label in range(n):
            if not used[label]:
                if ordinal == rank:
                    selected = label
                    break
                rank += 1
        if selected < 0:
            return List[Int]()
        used[selected] = True
        out.append(selected)
    return out^


def determinant(matrix: List[List[Int]]) -> Int:
    """Exact Leibniz determinant, bounded at 5x5 (<=120 terms)."""
    var n = len(matrix)
    if n < 1 or n > 5:
        return 0
    for i in range(n):
        if len(matrix[i]) != n:
            return 0
    var total = 0
    for index in range(factorial(n)):
        var p = permutation(n, index)
        var inversions = 0
        for i in range(n):
            for j in range(i + 1, n):
                if p[i] > p[j]:
                    inversions += 1
        var term = -1 if inversions % 2 != 0 else 1
        for i in range(n):
            term *= matrix[i][p[i]]
        total += term
    return total


def signed_incidence(parent: List[Int], child: List[Int], n: Int) -> Int:
    """Return ±1 for an oriented immediate facet; 0 rejects invalid facets."""
    if not valid_face(parent, n) or not valid_face(child, n):
        return 0
    var d = face_dimension(parent, n)
    if d <= 0 or face_dimension(child, n) != d - 1:
        return 0
    var is_facet = False
    var children = facets(parent, n)
    for c in children:
        if same_face(c, child):
            is_facet = True
            break
    if not is_facet:
        return 0
    var cx = doubled_center(parent, n)
    var cy = doubled_center(child, n)
    var rows = tangent_rows(parent, n)
    var child_rows = tangent_rows(child, n)
    var child_roots = tangent_roots(child, n)
    var matrix = List[List[Int]]()
    for r in range(d):
        var line = List[Int]()
        var coordinate = rows[r]
        line.append(cy[coordinate] - cx[coordinate])
        for j in range(d - 1):
            line.append(
                Int(coordinate == child_rows[j]) -
                Int(coordinate == child_roots[j])
            )
        matrix.append(line^)
    var result = determinant(matrix)
    if result > 0:
        return 1
    if result < 0:
        return -1
    return 0


def boundary_squared_zero(face: List[Int], n: Int) -> Bool:
    """Exact chain condition for one cell, with witness on any bad incidence."""
    var d = face_dimension(face, n)
    if d < 0:
        return False
    if d < 2:
        return True
    var lower_faces = List[List[Int]]()
    var coefficients = List[Int]()
    var children = facets(face, n)
    for child in children:
        var outer = signed_incidence(face, child, n)
        if outer == 0:
            return False
        var grand = facets(child, n)
        for lower in grand:
            var inner = signed_incidence(child, lower, n)
            if inner == 0:
                return False
            var found = False
            for i in range(len(lower_faces)):
                if same_face(lower_faces[i], lower):
                    coefficients[i] += outer * inner
                    found = True
                    break
            if not found:
                lower_faces.append(lower.copy())
                coefficients.append(outer * inner)
    for coefficient in coefficients:
        if coefficient != 0:
            return False
    return True


def face_vector(n: Int) -> List[Int]:
    """Ordered set partition count: (n-d)! S(n,n-d)."""
    var result = List[Int]()
    if n < 2 or n > 6:
        return result^
    var previous = List[Int]()
    for j in range(n + 1):
        previous.append(1 if j == 0 else 0)
    for i in range(1, n + 1):
        var current = List[Int]()
        for j in range(n + 1):
            current.append(0)
        for j in range(1, i + 1):
            current[j] = j * previous[j] + previous[j - 1]
        previous = current.copy()
    for d in range(n):
        var blocks = n - d
        result.append(factorial(blocks) * previous[blocks])
    return result^
