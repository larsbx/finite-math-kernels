"""Differential check: oracles/rational_dynamics_py against the Mojo
``rational_dynamics.doubling``, ``.multiplicative_order``, ``.carmichael`` and
``.moebius`` modules.

The Mojo side prints a transcript of every function the twin shares on a fixed
corpus (doubling_transcript.mojo, beside this file); this test recomputes each
line in Python and compares strings. The Mojo layer is canonical, so a
disagreement is a defect in the twin until shown otherwise.
"""

from __future__ import annotations

import shutil
import subprocess
from fractions import Fraction
from pathlib import Path

import rational_dynamics_py as rd

ROOT = Path(__file__).resolve().parents[2]
PROGRAM = Path(__file__).with_name("doubling_transcript.mojo")

MERSENNE_127 = 2**127 - 1
EXTRA_FRACTIONS = [(9, 7), (5, 128 * 10007), (1, 58), (1, 50), (3, MERSENNE_127), (7, 4 * 3**9)]
EXTRA_MODULI = [4097, 8191, 10007, 24573, 59049, 65535, 1048575, MERSENNE_127, 3**50]


def refused(f, *args) -> str:
    """``R`` where the Python plane raises ``ValueError``, else the value."""
    try:
        return str(f(*args))
    except ValueError:
        return "R"


def type_line(num: int, den: int) -> str:
    t = Fraction(num, den)
    l, k = rd.exact_type(t)
    return " ".join(["T", str(t.numerator), str(t.denominator), str(l), str(k),
                     rd.binary_block(t), rd.binary_digits(t, 12)])


def expected() -> list[str]:
    lines = ["HEADER rational-dynamics-doubling-twin 1"]
    lines += [type_line(num, den) for den in range(1, 65) for num in range(den)]
    lines += [type_line(num, den) for num, den in EXTRA_FRACTIONS]
    # Trial division cannot factor the Mersenne prime 2^127 - 1 in time, so the
    # Carmichael lines stop before the two largest moduli.
    moduli = [*range(-3, 200), *EXTRA_MODULI]
    for i, m in enumerate(moduli):
        lines.append(f"O {m} {refused(rd.order_of_two, m)}")
        if i < len(moduli) - 2:
            lines.append(f"L {m} {refused(rd.carmichael_lambda, m)}")
    lines += [f"C {l} {k} {refused(rd.exact_type_count, l, k)}" for l in range(-1, 6) for k in range(0, 13)]
    lines.append(f"C 0 64 {rd.exact_type_count(0, 64)}")
    lines += [f"M {n} {refused(rd.moebius, n)}" for n in range(0, 121)]
    lines.append("END")
    return lines


def test_the_python_twin_reproduces_the_mojo_transcript():
    mojo = shutil.which("mojo")
    assert mojo is not None, "mojo must be available in the pixi test environment"
    result = subprocess.run(
        [mojo, "run", "-I", str(ROOT / "kernel"), str(PROGRAM)],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    actual = [line for line in result.stdout.splitlines() if line.strip()]
    want = expected()
    assert len(actual) == len(want)
    mismatches = [(w, a) for w, a in zip(want, actual) if w != a]
    assert not mismatches, mismatches[:5]


def test_the_transcript_is_not_vacuous():
    """The corpus reaches the refusals, the Carmichael route and values past Int64."""
    lines = expected()
    orders = {line.split()[1]: line.split()[2] for line in lines if line.startswith("O")}
    assert {orders[m] for m in ("-3", "0", "2", "12")} == {"R"}
    assert int(orders["59049"]) > 4096 and int(orders[str(3**50)]) > 2**63
    assert any(line.startswith("T") and int(line.split()[4]) > 64 for line in lines)
    assert any(line.startswith("C") and line.split()[3] == "R" for line in lines)
    assert any(line.startswith("M") and line.split()[2] == "R" for line in lines)
