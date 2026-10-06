"""Differential check: oracles/root_isolation_py against the Mojo root_isolation kernel.

krawczyk_transcript.mojo (beside this file) prints the Krawczyk image and the
three tests of docs/root-isolation-spec.md on a fixed corpus; this test
recomputes every line with the Python package, as a one-variable box, and
compares strings. The Mojo kernel is canonical for one variable.
"""

from __future__ import annotations

import shutil
import subprocess
from fractions import Fraction
from pathlib import Path

from closed_interval import IQ, ComplexIQ
from root_isolation_py import centre, disjoint, exact_inverse, excludes_zero, krawczyk_image, strictly_inside

ROOT = Path(__file__).resolve().parents[2]
PROGRAM = Path(__file__).with_name("krawczyk_transcript.mojo")

BOXES = [
    (17, 12, 0, 1, 16), (-17, 12, 0, 1, 16), (0, 1, 0, 1, 8), (1, 2, 1, 2, 2),
    (-1, 2, 433, 500, 64), (0, 1, 1, 1, 32), (3, 1, -1, 1, 1), (-2, 1, 0, 1, 256),
]
PARAMETERS = [(-2, 1, 0, 1), (1, 1, 0, 1), (0, 1, 0, 1), (1, 4, -3, 4)]
TWO = ComplexIQ.singleton(2)


def box(i: int) -> ComplexIQ:
    a, b, c, d, r = BOXES[i]
    re, im, radius = Fraction(a, b), Fraction(c, d), Fraction(1, r)
    return ComplexIQ.of(re - radius, re + radius, im - radius, im + radius)


def parameter(j: int) -> ComplexIQ:
    a, b, c, d = PARAMETERS[j]
    return ComplexIQ.singleton(Fraction(a, b), Fraction(c, d))


def q(x: Fraction) -> str:
    return f"{x.numerator}/{x.denominator}"


def iq(x: IQ) -> str:
    return "rejected" if x.rejected else f"{q(x.lo)},{q(x.hi)}"


def boxed(z: ComplexIQ) -> str:
    return f"{iq(z.re)};{iq(z.im)}" if z.accepted() else "rejected"


def flag(value: bool, *operands: ComplexIQ) -> str:
    """Mojo's (value, rejected) pair; the Python twin answers False when rejected."""
    if any(not z.accepted() for z in operands):
        assert value is False
        return "R"
    return "1" if value else "0"


def expected() -> list[str]:
    lines = ["HEADER krawczyk-twin 1"]
    for i in range(len(BOXES)):
        x = box(i)
        (m,) = centre((x,))
        ((y,),) = exact_inverse(((TWO.mul(m),),))
        for j in range(len(PARAMETERS)):
            a = parameter(j)
            (image,) = krawczyk_image((x,), (m,), ((y,),), (m.mul(m).add(a),), ((TWO.mul(x),),))
            fx = x.mul(x).add(a)
            other = box((i + 1) % len(BOXES))
            lines.append(" ".join([
                "K", boxed(x), boxed(a), boxed(m), boxed(y), boxed(image),
                flag(strictly_inside((image,), (x,)), image, x),
                flag(excludes_zero((fx,)), fx),
                flag(disjoint((x,), (other,)), x, other),
            ]))
    lines.append("END")
    return lines


def test_the_python_package_reproduces_the_mojo_transcript():
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
    assert not mismatches, mismatches[:3]


def test_the_transcript_is_not_vacuous():
    """The corpus reaches isolation, its failure, refusal, exclusion and disjointness."""
    lines = [line.split() for line in expected() if line.startswith("K")]
    assert {line[6] for line in lines} == {"0", "1", "R"}
    assert {line[7] for line in lines} == {"0", "1"}
    assert {line[8] for line in lines} == {"0", "1"}
