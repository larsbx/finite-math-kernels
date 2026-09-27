# map_fold.mojo
#
# Deterministic parallel map-fold over an index range.
#
# Law. For `combine` associative with two-sided identity `identity`, and every
# `n >= 0`, `workers >= 1`:
#
#   parallel_map_fold(map, combine, identity, n, workers)
#     = combine(...combine(combine(identity, map(0)), map(1))..., map(n - 1))
#
# The range is cut into `min(workers, n)` contiguous chunks; each worker folds
# its chunk left to right into its own slot, and the slots are then folded in
# chunk order. Only associativity is used, never commutativity, so an
# order-sensitive monoid (concatenation, composition) gets the sequential
# answer, and a census record is byte-identical at any thread count. A
# non-associative `combine` (floating-point addition, for one) gets an answer
# that depends on `workers`: that is outside the law, not a bug in it.
#
# `map` and `combine` run concurrently on different threads, so they must be
# pure: no shared mutable state, no I/O whose order matters. Neither may
# raise; a fallible step should return a value that records the failure and
# let `combine` keep it sticky.
#
# `workers < 1` raises rather than being guessed, and `workers > n` uses only
# `n` of them. The thread pool is the MAX runtime's; `workers` bounds how many
# chunks exist, and so how many threads can be busy at once.

from max.algorithm import parallelize


def parallel_map_fold[
    T: Copyable & Deinitable,
    MapFn: def(Int) -> T,
    CombineFn: def(T, T) -> T,
](map: MapFn, combine: CombineFn, identity: T, n: Int, workers: Int) raises -> T:
    """The left fold of `map(0), ..., map(n - 1)` from `identity`, computed on
    up to `workers` threads. See the module header for the law."""
    if workers < 1:
        raise Error("parallel_map_fold: workers must be at least 1, got " + String(workers))
    var chunks = min(workers, n)
    if chunks <= 0:
        return identity.copy()
    var slots = List[T](length=chunks, fill=identity.copy())
    var out = slots.unsafe_ptr()

    def fold_chunk(c: Int) {var out, map, combine, identity, var n, var chunks}:
        var acc = identity.copy()
        for i in range(c * n // chunks, (c + 1) * n // chunks):
            acc = combine(acc, map(i))
        out[unsafe_offset=c] = acc^

    parallelize(fold_chunk, chunks, chunks)
    var acc = identity.copy()
    for c in range(chunks):
        acc = combine(acc, slots[c])
    return acc^
