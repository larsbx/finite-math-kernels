# collision.mojo
#
# Which index pairs an orbit type intends to collide, and which it forbids.
#
# A claimed preperiod `ell` and period `period` partition the pairs
# `(i, j)` with `0 <= i < j <= horizon` into the pairs the type says are the
# same orbit point and the pairs it says are different. The partition is
# finite combinatorics on indices; it knows nothing about any parameter and
# proves nothing about any orbit.


def intended_pair(ell: Int, period: Int, i: Int, j: Int) -> Bool:
    """Does the type `(ell, period)` intend terms `i` and `j` to coincide?

    Total by construction: an invalid type intends nothing, so a caller that
    forgot to validate its configuration gets an empty intended set rather
    than a silently wrong partition.
    """
    if ell < 1 or period < 1 or i < 0 or j < 0:
        return False
    return i >= ell and ((j - i) % period == 0)


def intended_count(ell: Int, period: Int, horizon: Int) -> Int:
    var total = 0
    for i in range(horizon + 1):
        for j in range(i + 1, horizon + 1):
            if intended_pair(ell, period, i, j):
                total += 1
    return total


def forbidden_count(ell: Int, period: Int, horizon: Int) -> Int:
    var total = 0
    for i in range(horizon + 1):
        for j in range(i + 1, horizon + 1):
            if not intended_pair(ell, period, i, j):
                total += 1
    return total


def pair_count(horizon: Int) -> Int:
    """Every ordered pair below the horizon: `horizon (horizon + 1) / 2`."""
    if horizon < 1:
        return 0
    return horizon * (horizon + 1) // 2
