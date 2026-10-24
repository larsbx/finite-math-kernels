"""MAX exact shell census: compare parallel and sequential folds.

This is an execution and formula check, not a proof of the closed-form count.
"""
from std.testing import assert_equal, assert_true
from projective_limits.hyperbolic_rt_max import (
    norm_one_count_max,
    norm_one_count_formula,
)


def test_parallel_exact_shells() raises:
    for workers in (1, 2, 4):
        assert_equal(norm_one_count_max[3](workers), 2160)
        assert_equal(norm_one_count_max[3](workers), norm_one_count_formula[3]())
    assert_equal(norm_one_count_max[5](1), 78000)
    assert_equal(norm_one_count_max[5](4), 78000)
    assert_equal(norm_one_count_formula[5](), 78000)


def test_budget_and_workers_reject() raises:
    var rejected_workers = False
    try:
        _ = norm_one_count_max[3](0)
    except:
        rejected_workers = True
    assert_true(rejected_workers)
    var rejected_budget = False
    try:
        _ = norm_one_count_max[7](4)  # 7^8 > 1,000,000
    except:
        rejected_budget = True
    assert_true(rejected_budget)


def main() raises:
    test_parallel_exact_shells()
    print("[PASS] MAX parallel/serial exact F3/F5 shells")
    test_budget_and_workers_reject()
    print("[PASS] deterministic budget and worker refusal")
