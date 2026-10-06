"""Differential check: oracles/closed_interval against the Mojo closed_q layer.

The Mojo side prints a transcript of every operation the twin shares on a
fixed corpus (closed_q_transcript.mojo, beside this file); this test
recomputes each line in Python and compares strings. The Mojo layer is
canonical, so a disagreement is a defect in the twin until shown otherwise.
"""

from __future__ import annotations

import shutil
import subprocess
from fractions import Fraction
from pathlib import Path

from closed_interval import IQ, ComplexIQ

ROOT = Path(__file__).resolve().parents[2]
PROGRAM = Path(__file__).with_name("closed_q_transcript.mojo")

CORPUS = [
    (-3, 1, -1, 2), (-1, 1, 1, 1), (0, 1, 0, 1), (1, 4, 1, 2), (-1, 4, 1, 4), (2, 1, 5, 1),
    (1, 3, 7, 3), (-5, 2, 0, 1), (0, 1, 3, 4), (-7, 3, 5, 6), (2, 1, 1, 1),
]


def interval(i: int) -> IQ:
    a, b, c, d = CORPUS[i]
    return IQ.of(Fraction(a, b), Fraction(c, d))


def q(x: Fraction) -> str:
    return f"{x.numerator}/{x.denominator}"


def iq(x: IQ) -> str:
    return "rejected" if x.rejected else f"{q(x.lo)},{q(x.hi)}"


def pred(value: bool, *operands) -> str:
    """Mojo's (value, rejected) pair; the Python twin must answer False when rejected."""
    if any(not o.accepted() for o in operands):
        assert value is False
        return "R"
    return "1" if value else "0"


def flag(value: bool) -> str:
    """A point predicate is plain: false on a refusal, so no `R` token."""
    return "1" if value else "0"


def expected() -> list[str]:
    n = len(CORPUS)
    lines = ["HEADER closed-q-twin 1"]
    for i in range(n):
        x = interval(i)
        sign = x.sign()
        lines.append(" ".join([
            "I1", iq(x), iq(x.square()), iq(x.neg()), iq(x.reciprocal()),
            "R" if sign is None else str(sign), pred(x.contains_zero(), x), pred(x.excludes_zero(), x),
        ]))
    for i in range(n):
        for j in range(n):
            x, y = interval(i), interval(j)
            lines.append(" ".join([
                "I2", iq(x), iq(y), iq(x.add(y)), iq(x.sub(y)), iq(x.mul(y)),
                pred(x.subset_of(y), x, y), pred(x.strict_subset_of(y), x, y),
            ]))
    for i in range(n):
        for j in range(n):
            z = ComplexIQ(interval(i), interval(j))
            sq = z.square()
            lines.append(" ".join(["C1", iq(z.re), iq(z.im), iq(sq.re), iq(sq.im), iq(z.quadrance())]))
    for i in range(0, n, 3):
        for j in range(1, n, 3):
            for k in range(2, n, 3):
                z = ComplexIQ(interval(i), interval(j))
                w = ComplexIQ(interval(k), interval(i))
                product, total = z.mul(w), z.add(w)
                lines.append(" ".join([
                    "C2", iq(z.re), iq(z.im), iq(w.re), iq(w.im),
                    iq(product.re), iq(product.im), iq(total.re), iq(total.im),
                    pred(z.subset_of(w), z, w), pred(z.strict_subset_of(w), z, w),
                ]))
    for i in range(n):
        for j in range(n):
            z = ComplexIQ(interval(i), interval(j))
            w = ComplexIQ(interval(j), interval(i))
            lines.append(" ".join([
                "S1", iq(z.re), iq(z.im), flag(z.is_singleton()), flag(z.singleton_eq(z)), flag(z.singleton_eq(w)),
            ]))
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
    """The corpus reaches every branch the comparison is meant to cover."""
    lines = expected()
    assert any(line.startswith("I1 rejected") for line in lines)
    assert any(line.startswith("I1") and line.split()[4] == "rejected" and line.split()[1] != "rejected" for line in lines)
    assert {line.split()[5] for line in lines if line.startswith("I1")} == {"-1", "0", "1", "R"}
    assert any(line.startswith("I2") and line.split()[-1] == "1" for line in lines)
    assert any(line.startswith("S1") and line.split()[-1] == "1" for line in lines)
    assert any(line.startswith("S1 rejected") for line in lines)
