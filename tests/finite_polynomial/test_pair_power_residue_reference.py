"""Independent exact-Python reference for Mojo pair-power residue prefix.

Runs the real native Mojo program; no simulated/native-optional fallback.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def oracle() -> list[str]:
    rows = []
    for n in (0, 9, 10, 11, 25, 99, 110, 144, 123456789):
        digits = [int(d) for d in str(n)]
        alternating = sum((-1) ** i * d for i, d in enumerate(reversed(digits)))
        assert (n - sum(digits)) % 9 == 0
        assert (n - alternating) % 11 == 0
        rows.append(f"DIGIT {n} {sum(digits)} {alternating}")
    for modulus in (9, 11, 25, 99, 2475):
        present = set()
        powers = [pow(x, 5, modulus) for x in range(144)]
        for c in range(1, 144):
            before = len(present)
            present.update(
                (powers[a] + powers[c]) % modulus for a in range(1, c + 1)
            )
            if c in (1, 2, 8, 32, 143):
                rows.append(f"CARD {modulus} {c} {len(present)} {len(present) - before}")
            if c <= 8:
                brute = {
                    (powers[a] + powers[b]) % modulus
                    for a in range(1, c + 1) for b in range(a, c + 1)
                }
                assert present == brute
    rows += ["NEGATIVE ACCEPT", "NEGATIVE DIGIT REFUSED", "OVERSIZE REFUSED"]
    return rows


def test_native() -> None:
    proc = subprocess.run(
        ["mojo", "run", "-I", "kernel", "tests/finite_polynomial/test_pair_power_residue.mojo"],
        cwd=ROOT, text=True, capture_output=True, check=True,
    )
    actual = proc.stdout.splitlines()
    expected = oracle()
    assert actual == expected, (actual, expected)


if __name__ == "__main__":
    test_native()
    print("Exact pair-power Mojo values match full independent Python oracle.")
