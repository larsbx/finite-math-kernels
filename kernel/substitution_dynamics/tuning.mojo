"""Tuning patterns and the star product: constant-length substitutions on
`{0, 1}` of the form `tau(s) = prefix . (s xor twist)`.

Specification: `docs/tuning-substitutions-spec.md`, sections 1 and 2. Two
twist rules are shipped: the parity twist of Derrida, Gervois, and Pomeau
(`dgp`), the real-line kneading convention, and the continuation twist
(`continuation`), the general rule under which the image of `1` is the
periodic continuation of the prefix whose internal address contains the
period, read off `internal_address` (its own module). They differ already on the prefix
`11`. The package treats both as finite combinatorics only. The star product
is defined so that `star_product(a, b).substitution()` equals
`compose(a.substitution(), b.substitution())` for every pair of patterns,
whatever their twists, and both twist rules are closed under it.

Reference oracle: `reference/tuning_reference.py`.

References: B. Derrida, A. Gervois and Y. Pomeau, "Iteration of endomorphisms
on the real axis and representation of numbers", Ann. Inst. H. Poincare A 29
(1978) 305-356 (the parity twist and the star product); A. Douady and J. H.
Hubbard, "On the dynamics of polynomial-like mappings", Ann. Sci. Ecole Norm.
Sup. (4) 18 (1985) 287-343 (tuning); J. Milnor and W. Thurston, "On iterated
maps of the interval", Lecture Notes in Math. 1342 (1988) 465-563 (kneading).
"""

from substitution_dynamics.internal_address import internal_address
from substitution_dynamics.substitution import Substitution


struct TuningPattern(Copyable, Movable):
    """`(prefix, twist)`: a non-empty word over `{0, 1}` and a parity bit."""

    var prefix: List[Int]
    var twist: Bool

    def __init__(out self, prefix: List[Int], twist: Bool):
        # Trusted constructor: no validation. Prefer `TuningPattern.checked`.
        self.prefix = prefix.copy()
        self.twist = twist

    @staticmethod
    def checked(prefix: List[Int], twist: Bool) raises -> TuningPattern:
        """Boundary: a non-empty prefix over `{0, 1}`."""
        if len(prefix) == 0:
            raise Error("tuning prefix must be non-empty (period at least 2)")
        for i in range(len(prefix)):
            if prefix[i] != 0 and prefix[i] != 1:
                raise Error("tuning prefix letters must lie in {0, 1}")
        return TuningPattern(prefix, twist)

    @staticmethod
    def dgp(prefix: List[Int]) raises -> TuningPattern:
        """The pattern with the parity twist: an odd number of `1` in the prefix.
        This is the real-line convention (spec 1.3); use `continuation` otherwise."""
        return TuningPattern.checked(prefix, dgp_twist(prefix))

    @staticmethod
    def continuation(prefix: List[Int]) raises -> TuningPattern:
        """The pattern whose image of `1` is the continuation of the prefix with
        the period in its internal address (spec 1.3)."""
        return TuningPattern.checked(prefix, continuation_twist(prefix))

    def period(self) -> Int:
        return len(self.prefix) + 1

    def substitution(self) -> Substitution:
        """`tau(s) = prefix . (s xor twist)`; constant length `period()`."""
        var images = List[List[Int]]()
        for s in range(2):
            var img = self.prefix.copy()
            var last = s
            if self.twist:
                last = 1 - s
            img.append(last)
            images.append(img^)
        # Images are non-erasing and over {0, 1} by construction.
        return Substitution(images^, 2)


def dgp_twist(prefix: List[Int]) -> Bool:
    var ones = 0
    for i in range(len(prefix)):
        if prefix[i] == 1:
            ones += 1
    return ones % 2 == 1


def continuation_twist(prefix: List[Int]) raises -> Bool:
    """`A'_(n - S)` for `n = len(prefix) + 1` and `S` the last entry of
    `internal_address(prefix)`, that is the last defined term of
    `1, rho(1), rho(rho(1)), ...` with `rho(m) = min {k in (m, n-1] : A'_k != A'_(k-m)}`.
    Spec 1.3: exactly one periodic continuation of `A' *` has `n` in its
    internal address, namely the one whose last letter is `1 - A'_(n-S)`."""
    var address = internal_address(prefix)
    return prefix[len(prefix) - address[len(address) - 1]] == 1


def star_product(a: TuningPattern, b: TuningPattern) -> TuningPattern:
    """`A * B`: prefix `tau_A(B') . A'`, twist `eps_A xor eps_B`."""
    var prefix = a.substitution().apply(b.prefix)
    for i in range(len(a.prefix)):
        prefix.append(a.prefix[i])
    return TuningPattern(prefix, a.twist != b.twist)


def kneading_prefix(patterns: List[TuningPattern]) raises -> List[Int]:
    """Prefix of the iterated star product `A_1 * ... * A_n`: the first
    `p_1 ... p_n - 1` letters of every tuning of these patterns."""
    if len(patterns) == 0:
        raise Error("directive sequence must be non-empty")
    var acc = patterns[0].copy()
    for i in range(1, len(patterns)):
        acc = star_product(acc, patterns[i])
    return acc.prefix.copy()
