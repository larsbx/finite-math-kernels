"""The internal address of a periodic 0/1 kneading sequence.

Lau and Schleicher, *Internal addresses in the Mandelbrot set and
irreducibility of polynomials*, Stony Brook IMS Preprint 1994/19 (1994);
Bruin and Schleicher, *Symbolic dynamics of quadratic polynomials*, Institut
Mittag-Leffler Report 7 (2001/02), section 4. For a sequence `nu` indexed
from 1, `rho(m) = min {k > m : nu_k != nu_(k-m)}`, and the internal address
is `1 -> rho(1) -> rho(rho(1)) -> ...`.

Specification: `docs/tuning-substitutions-spec.md`, section 1.3, where the
continuation twist of `tuning.mojo` is read off this address. This module
ships the entries that do not exceed the period `n = len(nu)` of the
`n`-periodic sequence `nu nu nu ...`; an entry `k <= n` compares only letters
inside `nu`, so no periodic extension is read. Finite combinatorics only:
nothing here locates a parameter or knows a Mandelbrot set.

Reference oracle: `reference/internal_address_reference.py`.
"""


def internal_address(nu: List[Int]) raises -> List[Int]:
    """`1 -> rho(1) -> rho(rho(1)) -> ...` up to `n = len(nu)`, with
    `rho(m) = min {k in (m, n] : nu_k != nu_(k-m)}` (1-indexed). Boundary: a
    non-empty word over `{0, 1}`."""
    if len(nu) == 0:
        raise Error("a kneading word must be non-empty")
    for i in range(len(nu)):
        if nu[i] != 0 and nu[i] != 1:
            raise Error("kneading letters must lie in {0, 1}")
    var address: List[Int] = [1]
    while True:
        var m = address[len(address) - 1]
        var r = 0
        for k in range(m + 1, len(nu) + 1):
            if nu[k - 1] != nu[k - m - 1]:
                r = k
                break
        if r == 0:
            return address^
        address.append(r)
