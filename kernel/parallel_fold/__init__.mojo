# parallel_fold: deterministic CPU parallelism for exact folds.
#
#   map_fold  parallel_map_fold: map an index range across worker threads and
#             fold the results in index order, so the answer is the
#             sequential fold's whatever the worker count or scheduling.
#
# The only package here that needs MAX: `max.algorithm.parallelize` ships in
# `max-core`, not in the Mojo standard library. It computes nothing
# mathematical and certifies nothing; it evaluates what it is handed.
