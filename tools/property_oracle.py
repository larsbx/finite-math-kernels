#!/usr/bin/env python3
"""Independent oracle for the BigZ / Q / IQ property probe.

Specification: docs/rational-interval-arithmetic-spec.md (section 7, law tests).
Public boundary: docs/exact-arithmetic-public-boundary.md.

The Mojo probe ``tests/property_probe.mojo`` prints a transcript of canonical
byte encodings. This script regenerates the same operands from the same
xorshift64* stream, recomputes every result with Python ``int`` and
``fractions.Fraction``, encodes the expectation with the canonical
``Z(sign, byte_len, big_endian_magnitude)`` layout of
``docs/canonical-encoding.md``, and compares token by token. Nothing printed
by Mojo is parsed into a number: agreement is on bytes and codes.

The transcript grammar has three layers. ``finite_exact`` ships the Z and Q
layers and its probe prints zero interval cases (``--layers zq``);
``larsbx/interval_q`` vendors this file unchanged and runs its own probe,
which appends the I layer (``--layers zqi``). Both probes draw from one
generator stream, so the Z and Q lines are identical in both transcripts.

Usage:
    property_oracle.py [--layers zq|zqi]              run ``mojo`` and compare
    property_oracle.py [--layers zq|zqi] TRANSCRIPT   compare a saved transcript

Exit status 0 on agreement, 1 on any mismatch, 2 when ``mojo`` is unavailable.
"""

from __future__ import annotations

import math
import shutil
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests" / "finite_exact" / "property_probe.mojo"
LAYERS = {"zq": 0, "zqi": None}  # interval case count override per layer set

BASE = 10**9
MASK64 = (1 << 64) - 1
SEED = 11400714819323198485
Z_CASES, Q_CASES, I_CASES, MAX_LIMBS = 300, 200, 120, 6


def header(i_cases: int = I_CASES) -> str:
    return f"HEADER exact-arithmetic-property-probe 1 {SEED} {Z_CASES} {Q_CASES} {i_cases}"


HEADER = header()


# --- generator (must match the Mojo probe call for call) -------------------


class Xorshift64Star:
    def __init__(self, seed: int) -> None:
        self.state = seed & MASK64

    def next(self) -> int:
        x = self.state
        x ^= x >> 12
        x ^= (x << 25) & MASK64
        x ^= x >> 27
        self.state = x
        return (x * 2685821657736338717) & MASK64


def random_int(rng: Xorshift64Star, max_limbs: int = MAX_LIMBS) -> int:
    if rng.next() % 4 == 0:
        return rng.next() % 2001 - 1000
    count = rng.next() % max_limbs + 1
    limbs = []
    for _ in range(count):
        pick = rng.next()
        limbs.append(BASE - 1 if pick % 5 == 0 else pick % BASE)
    value = sum(limb * BASE**i for i, limb in enumerate(limbs))
    if value != 0 and rng.next() % 2 == 1:
        value = -value
    return value


def random_nonzero_int(rng: Xorshift64Star) -> int:
    return random_int(rng) or 1


def random_fraction(rng: Xorshift64Star) -> Fraction:
    numerator = random_int(rng)
    return Fraction(numerator, random_nonzero_int(rng))


def random_interval(rng: Xorshift64Star) -> tuple[Fraction, Fraction]:
    a, b = random_fraction(rng), random_fraction(rng)
    return (min(a, b), max(a, b))


# --- canonical encodings -----------------------------------------------------


def encode_z(value: int) -> str:
    sign = 0 if value == 0 else (1 if value > 0 else 2)
    magnitude = abs(value).to_bytes((abs(value).bit_length() + 7) // 8, "big")
    return ".".join(str(b) for b in bytes([sign]) + len(magnitude).to_bytes(8, "big") + magnitude)


def encode_q(value: Fraction) -> str:
    return encode_z(value.numerator) + "." + encode_z(value.denominator)


def code(flag: bool) -> str:
    return "1" if flag else "0"


def trunc_divmod(a: int, b: int) -> tuple[int, int]:
    """Truncating quotient with remainder carrying the dividend's sign."""
    q = abs(a) // abs(b)
    if (a < 0) != (b < 0):
        q = -q
    return q, a - q * b


def interval_tokens(lo: Fraction, hi: Fraction) -> list[str]:
    return [encode_q(lo), encode_q(hi)]


def interval_mul(x: tuple[Fraction, Fraction], y: tuple[Fraction, Fraction]) -> tuple[Fraction, Fraction]:
    products = [x[0] * y[0], x[0] * y[1], x[1] * y[0], x[1] * y[1]]
    return (min(products), max(products))


# --- expected transcript -----------------------------------------------------


def expected_lines(i_cases: int = I_CASES) -> list[str]:
    rng = Xorshift64Star(SEED)
    lines = [header(i_cases)]
    for index in range(Z_CASES):
        a, b = random_int(rng), random_int(rng)
        gcd = math.gcd(a, b)
        if b == 0:
            quotient = ["rejected", "rejected"]
        else:
            q, r = trunc_divmod(a, b)
            quotient = [encode_z(q), encode_z(r)]
        lines.append(" ".join([
            "Z", str(index), encode_z(a), encode_z(b), encode_z(a + b), encode_z(a - b), encode_z(a * b),
            code(a < b), code(a == b), encode_z(gcd), *quotient, "1",
        ]))
    for index in range(Q_CASES):
        a, b = random_fraction(rng), random_fraction(rng)
        lines.append(" ".join([
            "Q", str(index), encode_q(a), encode_q(b), encode_q(a + b), encode_q(a - b), encode_q(a * b),
            "rejected" if b == 0 else encode_q(a / b), code(a < b), code(a <= b), code(a == b), "1",
        ]))
    for index in range(i_cases):
        x, y = random_interval(rng), random_interval(rng)
        total = (x[0] + y[0], x[1] + y[1])
        difference = (x[0] - y[1], x[1] - y[0])
        product = interval_mul(x, y)
        sign = 1 if x[0] > 0 else (-1 if x[1] < 0 else 0)
        reciprocal = ["rejected", "rejected"] if sign == 0 else interval_tokens(1 / x[1], 1 / x[0])
        lines.append(" ".join([
            "I", str(index), *interval_tokens(*x), *interval_tokens(*y), *interval_tokens(*total),
            *interval_tokens(*difference), *interval_tokens(*product), str(sign), *reciprocal, "1",
        ]))
    lines.append("END")
    return lines


def compare(actual: list[str], i_cases: int = I_CASES) -> list[str]:
    expected = expected_lines(i_cases)
    errors: list[str] = []
    if len(actual) != len(expected):
        errors.append(f"transcript has {len(actual)} lines, expected {len(expected)}")
    for lineno, (want, got) in enumerate(zip(expected, actual), start=1):
        if want == got:
            continue
        want_tokens, got_tokens = want.split(" "), got.split(" ")
        first = next((i for i, (w, g) in enumerate(zip(want_tokens, got_tokens)) if w != g), min(len(want_tokens), len(got_tokens)))
        errors.append(f"line {lineno} token {first}: expected {want_tokens[first] if first < len(want_tokens) else '<none>'!r}, got {got_tokens[first] if first < len(got_tokens) else '<none>'!r}")
        if len(errors) >= 20:
            errors.append("... further mismatches suppressed")
            break
    return errors


def run_probe() -> list[str] | None:
    mojo = shutil.which("mojo")
    if mojo is None:
        return None
    result = subprocess.run([mojo, "run", "-I", str(ROOT), str(PROBE)], cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"mojo probe failed with status {result.returncode}:\n{result.stderr}")
    return [line for line in result.stdout.splitlines() if line.strip()]


def parse_args(argv: list[str]) -> tuple[int, str | None]:
    """Return ``(interval_case_count, transcript_path)``."""
    args = list(argv[1:])
    layers = "zqi"
    if args[:1] == ["--layers"]:
        layers = args[1] if len(args) > 1 else ""
        args = args[2:]
    if layers not in LAYERS or len(args) > 1:
        raise SystemExit(__doc__)
    i_cases = I_CASES if LAYERS[layers] is None else LAYERS[layers]
    return i_cases, (args[0] if args else None)


def main(argv: list[str]) -> int:
    i_cases, transcript = parse_args(argv)
    if transcript is not None:
        actual = [line for line in Path(transcript).read_text(encoding="utf-8").splitlines() if line.strip()]
    else:
        actual = run_probe()
        if actual is None:
            print("mojo is not on PATH; run inside `pixi run` or pass a saved transcript.")
            return 2
    errors = compare(actual, i_cases)
    if errors:
        print("Exact-arithmetic property probe disagrees with the Python oracle:\n")
        print("\n".join(errors))
        return 1
    print(f"OK: property probe agrees with the oracle on {Z_CASES} integer, {Q_CASES} rational, and {i_cases} interval cases.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
