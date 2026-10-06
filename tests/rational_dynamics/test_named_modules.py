"""Every named object moved out of a generic module of ``rational_dynamics_py``
is importable from its named module, from the module it left, and from the
package, and all three are the same object.

The behaviour of each object is pinned by test_rational_dynamics_oracle.py,
which imports it through the package facade.
"""

from __future__ import annotations

import importlib

import pytest

import rational_dynamics_py

MOVED = {
    "arithmetic": {
        "moebius": "moebius_function",
        "dedekind_sum": "dedekind_sums",
        "ramanujan_sum": "ramanujan_sums",
    },
    "farey": {
        **dict.fromkeys(
            ["Address", "address", "as_fraction", "double_mod_one", "mod_inverse", "require_int",
             "signed_mod_inverse", "units"],
            "addresses",
        ),
        **dict.fromkeys(["continued_fraction", "convergents", "from_continued_fraction"], "continued_fractions"),
    },
    "doubling": {
        "mechanical_word": "mechanical_words",
        "rotation_cycle": "rotation_sets",
        "rotation_number": "rotation_sets",
        "wake": "wakes",
        "order_of_two": "multiplicative_order",
    },
}
CASES = [(old, name, new) for old, names in MOVED.items() for name, new in names.items()]


def module(name: str):
    return importlib.import_module(f"rational_dynamics_py.{name}")


@pytest.mark.parametrize(("old", "name", "new"), CASES)
def test_the_old_path_re_exports_the_named_module_object(old, name, new):
    assert getattr(module(old), name) is getattr(module(new), name)


@pytest.mark.parametrize(("old", "name", "new"), [c for c in CASES if c[1] != "require_int"])
def test_the_package_exports_the_named_module_object(old, name, new):
    assert name in rational_dynamics_py.__all__
    assert getattr(rational_dynamics_py, name) is getattr(module(new), name)


@pytest.mark.parametrize("new", sorted({new for _, _, new in CASES} - {"addresses"} | {"farey"}))
def test_every_named_module_cites_a_source(new):
    """``addresses`` holds the generic helpers and names no literature object."""
    doc = module(new).__doc__
    assert doc and any(str(year) in doc for year in range(1700, 2030))
