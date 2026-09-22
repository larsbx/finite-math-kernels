"""Executable laws for the parallel_fold package.

Run with `pixi run test-parallel-fold`
(`mojo run -I . tests/parallel_fold/test_map_fold.mojo`).

The one law: for an associative `combine` with identity `e`,
`parallel_map_fold(map, combine, e, n, workers)` equals the sequential left
fold `combine(...combine(combine(e, map(0)), map(1))..., map(n - 1))` for every
`n >= 0` and every `workers >= 1`. List concatenation is the witness monoid:
it is associative and not commutative, so its result is the index sequence
itself, and any dropped, repeated, or reordered index shows up as a wrong
list rather than as a coincidentally equal number.
"""

from parallel_fold.map_fold import parallel_map_fold

comptime MAX_N = 40
comptime MAX_WORKERS = 9


def singleton(i: Int) -> List[Int]:
    return [i]


def concat(a: List[Int], b: List[Int]) -> List[Int]:
    var out = a.copy()
    out.extend(b.copy())
    return out^


def square(i: Int) -> Int:
    return i * i


def add(a: Int, b: Int) -> Int:
    return a + b


def is_range(xs: List[Int], n: Int) -> Bool:
    if len(xs) != n:
        return False
    for i in range(n):
        if xs[i] != i:
            return False
    return True


def test_concatenation_returns_every_index_once_in_order() raises -> Bool:
    """The non-commutative witness, over every small (n, workers), including
    more workers than items and uneven chunk splits."""
    for n in range(MAX_N + 1):
        for workers in range(1, MAX_WORKERS + 1):
            if not is_range(parallel_map_fold(singleton, concat, List[Int](), n, workers), n):
                print("  order or coverage broken at n =", n, "workers =", workers)
                return False
    return True


def test_a_large_uneven_split_keeps_order() raises -> Bool:
    """1000 items over 7 workers: chunk boundaries fall mid-range."""
    return is_range(parallel_map_fold(singleton, concat, List[Int](), 1000, 7), 1000)


def test_sum_of_squares_matches_the_closed_form() raises -> Bool:
    """A trivially copyable accumulator: sum_{i < n} i^2 = (n - 1) n (2n - 1) / 6."""
    for n in range(MAX_N + 1):
        for workers in range(1, MAX_WORKERS + 1):
            if parallel_map_fold(square, add, 0, n, workers) != (n - 1) * n * (2 * n - 1) // 6:
                return False
    return True


def test_an_empty_range_is_the_identity() raises -> Bool:
    for workers in range(1, MAX_WORKERS + 1):
        if parallel_map_fold(square, add, 17, 0, workers) != 17:
            return False
    return True


def rejects(workers: Int) -> Bool:
    try:
        _ = parallel_map_fold(square, add, 0, 10, workers)
    except:
        return True
    return False


def test_fewer_than_one_worker_is_rejected() -> Bool:
    """Fail closed: no worker count is guessed on the caller's behalf."""
    return rejects(0) and rejects(-3)


def main() raises:
    var failed = List[String]()
    if not test_concatenation_returns_every_index_once_in_order():
        failed.append("concatenation order")
    if not test_a_large_uneven_split_keeps_order():
        failed.append("large uneven split")
    if not test_sum_of_squares_matches_the_closed_form():
        failed.append("sum of squares")
    if not test_an_empty_range_is_the_identity():
        failed.append("empty range")
    if not test_fewer_than_one_worker_is_rejected():
        failed.append("worker count rejection")
    if len(failed) > 0:
        var names = String("")
        for name in failed:
            names += " [" + name + "]"
        raise Error("parallel_fold laws failed:" + names)
    print("5 parallel_fold laws passed.")
