"""Fixed-dimension integer vector arithmetic: the canonical kernel.

The Python references of `larsbx/pisot-substitution-conjecture-research` (its prefix-difference,
prefix-ancestry, orientation-spectrum and degree-two factorization modules)
each carry a private `_matvec`, and two of them a private `_add` and `_sub`, over short integer
vectors -- the prefix-difference lift, the ancestry step, the orientation gauge
and the mid-area residual all reduce to `M x`, `x + y` and `x - y` on dimension
two or three. That is one kernel with four Python copies, and this module is
the one canonical implementation of it (Mojo is canonical, Python is an
oracle). Performance work on it belongs here, not in the oracle.

Two contracts, both inherited from the oracle and both fail-closed:

* A dimension that does not agree raises, where the Python raises
  `ValueError`. It never returns a truncated or zero-padded answer.
* Arbitrary precision is the one thing the oracle has and this does not.
  Python's `int` cannot overflow; `Int` is 64-bit, so every product and sum
  here is checked and a run that would leave the range raises instead of
  wrapping. Exact, or absent.

`_general` variants stay exported because they are the definition: the
dimension-specialised paths are an optimisation, and `test_integer_vector.mojo`
pins them against the general form over a grid rather than trusting that two
spellings of the same sum agree.
"""

from finite_exact.checked_int import checked_add, checked_mul, checked_sub


def _require_same_length(a: List[Int], b: List[Int]) raises:
    if len(a) != len(b):
        raise Error("integer vector dimensions differ")


def _require_matrix_fits(m: List[List[Int]], v: List[Int]) raises:
    if len(m) == 0:
        raise Error("integer matrix has no rows")
    for i in range(len(m)):
        if len(m[i]) != len(v):
            raise Error("integer matrix and vector dimensions do not agree")


def add_general(a: List[Int], b: List[Int]) raises -> List[Int]:
    _require_same_length(a, b)
    var out = List[Int]()
    for i in range(len(a)):
        out.append(checked_add(a[i], b[i]))
    return out^


def sub_general(a: List[Int], b: List[Int]) raises -> List[Int]:
    _require_same_length(a, b)
    var out = List[Int]()
    for i in range(len(a)):
        out.append(checked_sub(a[i], b[i]))
    return out^


def matvec_general(m: List[List[Int]], v: List[Int]) raises -> List[Int]:
    _require_matrix_fits(m, v)
    var out = List[Int]()
    for i in range(len(m)):
        var acc = 0
        for j in range(len(v)):
            acc = checked_add(acc, checked_mul(m[i][j], v[j]))
        out.append(acc)
    return out^


def add(a: List[Int], b: List[Int]) raises -> List[Int]:
    """`a + b`, entrywise and checked, dimension three unrolled."""
    _require_same_length(a, b)
    if len(a) == 3:
        var out = List[Int]()
        out.append(checked_add(a[0], b[0]))
        out.append(checked_add(a[1], b[1]))
        out.append(checked_add(a[2], b[2]))
        return out^
    return add_general(a, b)


def sub(a: List[Int], b: List[Int]) raises -> List[Int]:
    """`a - b`, entrywise and checked, dimension three unrolled."""
    _require_same_length(a, b)
    if len(a) == 3:
        var out = List[Int]()
        out.append(checked_sub(a[0], b[0]))
        out.append(checked_sub(a[1], b[1]))
        out.append(checked_sub(a[2], b[2]))
        return out^
    return sub_general(a, b)


def matvec(m: List[List[Int]], v: List[Int]) raises -> List[Int]:
    """`M v`, checked.

    Dimension three is the alphabet the corpus runs on and is unrolled; every
    other dimension takes the general loop. The unroll is kept because it is
    measured (`kernel/integer_vector_bench.mojo` in its first consumer,
    `larsbx/pisot-substitution-conjecture-research`), not because unrolling is assumed to
    pay -- in Mojo it often does not, and where it does not the general form is
    the better kernel.
    """
    _require_matrix_fits(m, v)
    if len(v) == 3 and len(m) == 3:
        ref r0 = m[0]
        ref r1 = m[1]
        ref r2 = m[2]
        var v0 = v[0]
        var v1 = v[1]
        var v2 = v[2]
        var out = List[Int]()
        out.append(
            checked_add(
                checked_add(checked_mul(r0[0], v0), checked_mul(r0[1], v1)),
                checked_mul(r0[2], v2),
            )
        )
        out.append(
            checked_add(
                checked_add(checked_mul(r1[0], v0), checked_mul(r1[1], v1)),
                checked_mul(r1[2], v2),
            )
        )
        out.append(
            checked_add(
                checked_add(checked_mul(r2[0], v0), checked_mul(r2[1], v1)),
                checked_mul(r2[2], v2),
            )
        )
        return out^
    return matvec_general(m, v)
