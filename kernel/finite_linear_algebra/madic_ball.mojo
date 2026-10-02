"""`M`-adic balls: cosets of `M^k Z^n`, as a conservative filter over Z^n.

An `M`-adic ball of level `k` is a coset `v + M^k Z^n`. Its radius is the
lattice `M^k Z^n`, not a number, and that is the whole point: `Z^n / M^k Z^n`
need not be cyclic, so a scalar `p`-adic precision cannot express it. For the
canonical determinant-two substitution `Z^3 / M^2 Z^3` is `Z/2 x Z/2` while a
scalar `Z_2` ball at precision two is `Z/4` -- the same order and a different
group. `quotient_invariants` is the function that reports which.

**The contract is the closed interval's, transposed.** Two points in the same
coset at level `k` are *unknown*: membership of their difference in `M^k Z^n`
does not make them equal, and refining the level can still separate them. Two
points in different cosets are certainly distinct, and that separation is the
only certificate this carrier issues. `same_coset_means_equal` pins the
non-claim, exactly as the interval layer refuses to promote an unknown sign.

Inputs are machine integers, matching the `Mat3` and `Diff3` convention of the
consumers, and every coordinate is lifted into `Q` *before* any arithmetic
touches it. Nothing overflows: `M^k` grows like the spectral radius to the `k`,
and a 64-bit ceiling in a carrier whose purpose is exactness would be a defect
rather than a bound. The lift has to come first, not merely happen somewhere --
a difference formed in `Int` and lifted afterwards can wrap, and a wrapped
difference changes the membership answer.

The specification is `docs/madic-ball-arithmetic-spec.md`.
"""

from std.os import abort

from finite_exact.bigint_z import BigZ, bigz_divmod, bigz_from_i64, bigz_gcd, bigz_neg
from finite_exact.rat_q import Q
from finite_linear_algebra.scalar import q_int, q_is_zero

# Minor enumeration is `C(n, s)^2` per size, so the dimension is bounded and a
# larger one is refused rather than silently made slow.
comptime MAX_DIMENSION = 6


def q_is_integer(x: Q) -> Bool:
    """Whether an accepted rational is an integer; a rejected value aborts."""
    if x.rejected:
        abort("integrality test of a rejected exact rational")
    return x.den.limb_count() == 1 and x.den.limb(0) == 1


def lift_square(entries: List[Int], n: Int) -> List[List[Q]]:
    """Row-major integer entries, `entries[n*i + j]`, lifted into `Q`."""
    if n < 1 or n > MAX_DIMENSION:
        abort("M-adic dimension outside the supported range")
    if len(entries) != n * n:
        abort("M-adic matrix entry count does not match the dimension")
    var out = List[List[Q]]()
    for i in range(n):
        var row = List[Q]()
        for j in range(n):
            row.append(q_int(entries[n * i + j]))
        out.append(row^)
    return out^


def qmat_identity(n: Int) -> List[List[Q]]:
    var out = List[List[Q]]()
    for i in range(n):
        var row = List[Q]()
        for j in range(n):
            if i == j:
                row.append(Q.one())
            else:
                row.append(Q.zero())
        out.append(row^)
    return out^


def qmat_copy(a: List[List[Q]]) -> List[List[Q]]:
    """Deep copy: elimination mutates rows, so aliasing them would be a defect."""
    var out = List[List[Q]]()
    for i in range(len(a)):
        var row = List[Q]()
        for j in range(len(a[i])):
            row.append(a[i][j].copy())
        out.append(row^)
    return out^


def qmat_mul(a: List[List[Q]], b: List[List[Q]]) -> List[List[Q]]:
    var n = len(a)
    var out = List[List[Q]]()
    for i in range(n):
        var row = List[Q]()
        for j in range(n):
            var acc = Q.zero()
            for t in range(n):
                acc = acc.add(a[i][t].mul(b[t][j]))
            row.append(acc^)
        out.append(row^)
    return out^


def qmat_pow(a: List[List[Q]], level: Int) -> List[List[Q]]:
    """`a^level` for `level >= 0`, by repeated squaring."""
    if level < 0:
        abort("M-adic levels are non-negative")
    var result = qmat_identity(len(a))
    var base = qmat_copy(a)
    var k = level
    while k > 0:
        if k % 2 == 1:
            result = qmat_mul(result, base)
        base = qmat_mul(base, base)
        k = k // 2
    return result^


def qmat_det(a: List[List[Q]]) -> Q:
    """Exact determinant by elimination over `Q`."""
    var n = len(a)
    var rows = qmat_copy(a)
    var negated = False
    var det = Q.one()
    for c in range(n):
        var pivot = -1
        for r in range(c, n):
            if not q_is_zero(rows[r][c]):
                pivot = r
                break
        if pivot < 0:
            return Q.zero()
        if pivot != c:
            var swap = rows[c].copy()
            rows[c] = rows[pivot].copy()
            rows[pivot] = swap^
            negated = not negated
        det = det.mul(rows[c][c])
        for r in range(c + 1, n):
            if q_is_zero(rows[r][c]):
                continue
            var factor = rows[r][c].div(rows[c][c])
            for j in range(c, n):
                rows[r][j] = rows[r][j].sub(factor.mul(rows[c][j]))
    if negated:
        return det.neg()
    return det^


def index_subsets(n: Int, size: Int) -> List[List[Int]]:
    """Every `size`-element subset of `0 .. n-1`, by bitmask, ascending."""
    var out = List[List[Int]]()
    var limit = 1 << n
    for mask in range(limit):
        var chosen = List[Int]()
        for i in range(n):
            if (mask >> i) % 2 == 1:
                chosen.append(i)
        if len(chosen) == size:
            out.append(chosen^)
    return out^


def submatrix(a: List[List[Q]], rows: List[Int], cols: List[Int]) -> List[List[Q]]:
    var out = List[List[Q]]()
    for i in range(len(rows)):
        var row = List[Q]()
        for j in range(len(cols)):
            row.append(a[rows[i]][cols[j]].copy())
        out.append(row^)
    return out^


def q_integer_numerator(x: Q) -> BigZ:
    """Numerator of a value already known to be an integer."""
    if not q_is_integer(x):
        abort("integer numerator of a non-integer rational")
    return x.num.copy()


def minor_gcds(a: List[List[Q]]) -> List[BigZ]:
    """`D_s`, the gcd of every `s x s` minor, for `s = 0 .. n`, with `D_0 = 1`."""
    var n = len(a)
    if n < 1 or n > MAX_DIMENSION:
        abort("M-adic dimension outside the supported range")
    var out = List[BigZ]()
    out.append(bigz_from_i64(1))
    for size in range(1, n + 1):
        var acc = bigz_from_i64(0)
        var row_sets = index_subsets(n, size)
        var col_sets = index_subsets(n, size)
        for r in range(len(row_sets)):
            for c in range(len(col_sets)):
                var block = submatrix(a, row_sets[r], col_sets[c])
                acc = bigz_gcd(acc, q_integer_numerator(qmat_det(block)))
        out.append(acc^)
    return out^


def smith_invariants(a: List[List[Q]]) -> List[BigZ]:
    """Invariant factors `d_1 | d_2 | ... | d_n` of an integer matrix over `Q`.

    `Z^n / A Z^n` is the direct sum of the `Z / d_i`, so this reports the group
    *structure* of the quotient and not only its order.

    Computed from the determinantal divisors, `d_i = D_i / D_{i-1}`. That
    characterisation is classical and terminates by construction; a hand-rolled
    elimination sweep does not, and the first draft of the Python oracle used
    one and failed to terminate on `M^4` for the canonical substitution.
    """
    var divisors = minor_gcds(a)
    var out = List[BigZ]()
    for i in range(1, len(divisors)):
        if divisors[i].is_zero():
            out.append(bigz_from_i64(0))      # the lattice degenerates here
            continue
        var division = bigz_divmod(divisors[i], divisors[i - 1])
        if division.rejected or not division.remainder.is_zero():
            abort("determinantal divisors must form a divisibility chain")
        out.append(division.quotient.copy())
    return out^


def quotient_invariants(entries: List[Int], n: Int, level: Int) -> List[BigZ]:
    """Invariant factors of `Z^n / M^k Z^n`, trivial factors included."""
    return smith_invariants(qmat_pow(lift_square(entries, n), level))


def quotient_order(entries: List[Int], n: Int, level: Int) -> BigZ:
    """`|det M^k|`, the order of the quotient; zero when the lattice degenerates."""
    var det = qmat_det(qmat_pow(lift_square(entries, n), level))
    var value = q_integer_numerator(det)
    if value.sign < 0:
        return bigz_neg(value)
    return value^


def contains_exact(entries: List[Int], n: Int, level: Int, delta: List[Q]) -> Bool:
    """Whether the exact vector `delta` lies in the lattice `M^k Z^n`.

    Solves `M^k x = delta` over `Q` and asks whether `x` is integral.

    The determinant of the *original* `M` is checked before exponentiation, not
    after. At `level = 0` the power is the identity whatever `M` was, so a
    singular matrix would otherwise go undetected and every correctly sized
    delta would read as a member -- the opposite of the documented refusal.
    """
    if len(delta) != n:
        abort("M-adic difference vector has the wrong dimension")
    var m = lift_square(entries, n)
    if q_is_zero(qmat_det(m)):
        abort("singular M-adic lattice: det M must be non-zero")
    var lattice = qmat_pow(m, level)
    var rows = List[List[Q]]()
    for i in range(n):
        var row = List[Q]()
        for j in range(n):
            row.append(lattice[i][j].copy())
        row.append(delta[i].copy())
        rows.append(row^)
    for c in range(n):
        var pivot = -1
        for r in range(c, n):
            if not q_is_zero(rows[r][c]):
                pivot = r
                break
        if pivot < 0:
            abort("M-adic elimination found no pivot in a non-singular lattice")
        if pivot != c:
            var swap = rows[c].copy()
            rows[c] = rows[pivot].copy()
            rows[pivot] = swap^
        var lead = rows[c][c].copy()
        for j in range(c, n + 1):
            rows[c][j] = rows[c][j].div(lead)
        for r in range(n):
            if r == c or q_is_zero(rows[r][c]):
                continue
            var factor = rows[r][c].copy()
            for j in range(c, n + 1):
                rows[r][j] = rows[r][j].sub(factor.mul(rows[c][j]))
    for i in range(n):
        if not q_is_integer(rows[i][n]):
            return False
    return True


def contains(entries: List[Int], n: Int, level: Int, delta: List[Int]) -> Bool:
    """Whether the integer vector `delta` lies in the lattice `M^k Z^n`."""
    var lifted = List[Q]()
    for i in range(len(delta)):
        lifted.append(q_int(delta[i]))
    return contains_exact(entries, n, level, lifted)


def same_coset(entries: List[Int], n: Int, level: Int, a: List[Int], b: List[Int]) -> Bool:
    """Whether `a` and `b` agree modulo `M^k Z^n`. This is **not** equality.

    Each coordinate is lifted into `Q` *before* the subtraction. Forming
    `a[i] - b[i]` in `Int` first would wrap for coordinates far apart, and a
    wrapped difference can change the membership answer: with `M = [3]`,
    `a = 2^63 - 1` and `b = -2` the true difference is divisible by three while
    the wrapped one is not, so the carrier would have issued a false separation
    certificate -- the one thing it claims to be able to certify.
    """
    if len(a) != len(b):
        abort("M-adic points have different dimensions")
    var delta = List[Q]()
    for i in range(len(a)):
        delta.append(q_int(a[i]).sub(q_int(b[i])))
    return contains_exact(entries, n, level, delta)


def separated(entries: List[Int], n: Int, level: Int, a: List[Int], b: List[Int]) -> Bool:
    """Different cosets at this level, which certifies `a != b`."""
    return not same_coset(entries, n, level, a, b)


# --- non-claims -----------------------------------------------------------------


def same_coset_means_equal() -> Bool:
    """Agreeing modulo `M^k Z^n` is the unknown answer, never equality.
    Refining the level can still separate the pair, and for an expanding `M` the
    intersection over every level is trivial, so only the limit decides."""
    return False


def carrier_is_scalar_padic() -> Bool:
    """It is not, and the difference is not cosmetic: `Z^n / M^k Z^n` need not be
    cyclic, while a scalar `Z_p` ball at precision `k` always is."""
    return False
