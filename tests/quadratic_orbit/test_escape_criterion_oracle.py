"""Differential check: `quadratic_orbit.escape_criterion` and `.multiplier_classification` against Python.

The Mojo side prints a transcript on a fixed corpus (escape_criterion_transcript.mojo,
beside this file); this test recomputes every line from
`oracles/closed_interval` and its own forms of each quantity: the threshold
form as `(t - 1 - r)^2 - 4r` rather than the expanded polynomial, and the
growth form unexpanded. The Mojo package is canonical, so a disagreement is a
defect here until shown otherwise.

It also checks the one relation the two halves of the escape module owe each
other: every box the test passes carries a growth certificate, found here by
an exact bisection the Mojo side does not have.
"""

from __future__ import annotations

import shutil
import subprocess
from fractions import Fraction
from pathlib import Path

from closed_interval import ComplexIQ

ROOT = Path(__file__).resolve().parents[2]
PROGRAM = Path(__file__).with_name("escape_criterion_transcript.mojo")

BOXES = [
    (0, 0, 0, 0, 1), (1, 1, 0, 0, 4), (-2, -2, 0, 0, 1), (2, 2, 0, 0, 1), (5, 5, 0, 0, 1),
    (3, 3, 4, 4, 1), (3, 3, 4, 4, 5), (0, 0, -1, -1, 1), (3, 4, 3, 4, 1), (5, 6, 5, 6, 2),
    (-1, 1, -1, 1, 4), (3, 5, 0, 0, 4), (4, 5, 0, 0, 4), (1, 3, 0, 0, 1), (-9, 9, -9, 9, 1),
    (1, -1, 0, 0, 1),
]
RATIONALS = [
    Fraction(0), Fraction(1), Fraction(51, 50), Fraction(3, 2), Fraction(2), Fraction(4), Fraction(9, 2),
    Fraction(5), Fraction(26, 5), Fraction(9), Fraction(163, 31), Fraction(98, 19), Fraction(263, 19), None,
]
REGIME = {"rejected": -1, "attracting": 0, "indifferent": 1, "repelling": 2, "undecided": 3}


def box(spec: tuple[int, int, int, int, int]) -> ComplexIQ:
    re_lo, re_hi, im_lo, im_hi, den = spec
    return ComplexIQ.of(Fraction(re_lo, den), Fraction(re_hi, den), Fraction(im_lo, den), Fraction(im_hi, den))


def q(x: Fraction | None) -> str:
    return "rejected" if x is None else f"{x.numerator}/{x.denominator}"


def box_token(z: ComplexIQ) -> str:
    if not z.accepted():
        return "rejected"
    return ",".join(q(v) for v in (z.re.lo, z.re.hi, z.im.lo, z.im.hi))


def flag(value: bool) -> str:
    return "1" if value else "0"


def bound(c: ComplexIQ) -> Fraction | None:
    return max(Fraction(4), c.quadrance().hi) if c.accepted() else None


def escapes(z: ComplexIQ, c: ComplexIQ) -> bool:
    return z.accepted() and c.accepted() and z.quadrance().lo > bound(c)


def regime(lam: ComplexIQ) -> str:
    if not lam.accepted():
        return "rejected"
    n = lam.quadrance()
    if n.hi < 1:
        return "attracting"
    if n.lo > 1:
        return "repelling"
    return "indifferent" if n.lo == n.hi == 1 else "undecided"


def threshold(t, r):
    return None if None in (t, r) else (t - 1 - r) ** 2 - 4 * r


def growth(t, m, r):
    return None if None in (t, m, r) else (t * t + m - r * t) ** 2 - 4 * t * t * m


def holds(t, m, r) -> bool:
    if None in (t, m, r):
        return False
    return r > 1 and 0 <= m <= t and t > 1 + r and threshold(t, r) > 0


def some_ratio(t: Fraction, m: Fraction, refinements: int = 64) -> Fraction | None:
    """A certifying ratio, or None. The admissible ratios are an interval
    `(1, (sqrt(t) - 1)^2)` when `m <= t`, so halving towards one from `t`
    reaches it whenever it is nonempty and wider than `2^-refinements`."""
    high = max(t, Fraction(2))
    for _ in range(refinements):
        high = (1 + high) / 2
        if holds(t, m, high):
            return high
    return None


def expected() -> list[str]:
    lines = ["HEADER quadratic-orbit-escape 1"]
    zs = [box(spec) for spec in BOXES]
    for z in zs:
        lines.append(" ".join(["B", box_token(z), q(bound(z)), str(REGIME[regime(z)])]))
    for z in zs:
        for c in zs:
            lines.append(" ".join(["E", box_token(z), box_token(c), flag(escapes(z, c))]))
    for t in RATIONALS:
        for m in RATIONALS:
            for r in RATIONALS:
                lines.append(" ".join(["C", q(t), q(m), q(r), q(threshold(t, r)), q(growth(t, m, r)), flag(holds(t, m, r))]))
    lines.append("END")
    return lines


def test_the_mojo_transcript_matches_the_oracle():
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
    lines = expected()
    escape_flags = {line.split()[-1] for line in lines if line.startswith("E ")}
    assert escape_flags == {"0", "1"}
    assert {int(line.split()[-1]) for line in lines if line.startswith("B ")} == set(REGIME.values())
    assert {line.split()[-1] for line in lines if line.startswith("C ")} == {"0", "1"}
    assert any(line.startswith("B rejected rejected") for line in lines)


def test_every_escaping_box_carries_a_certificate():
    zs = [box(spec) for spec in BOXES]
    passed = [(z, c) for z in zs for c in zs if escapes(z, c)]
    assert passed
    for z, c in passed:
        assert some_ratio(z.quadrance().lo, c.quadrance().hi) is not None


def test_the_test_is_the_conservative_side_of_the_certificate():
    """The converse fails only at the tie `t = m > 4`: a certificate exists
    and the strict test does not fire. At `t = 4` neither does."""
    for s in (Fraction(5, 2), Fraction(3), Fraction(7)):
        point = ComplexIQ.singleton(s)
        assert some_ratio(s * s, s * s) is not None
        assert not escapes(point, point)
    assert some_ratio(Fraction(4), Fraction(0)) is None
    assert not escapes(ComplexIQ.singleton(2), ComplexIQ.singleton(0))
