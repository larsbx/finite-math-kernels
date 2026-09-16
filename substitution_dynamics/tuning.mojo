"""Tuning patterns and the star product: constant-length substitutions on
`{0, 1}` of the form `tau(s) = prefix . (s xor twist)`.

Specification: `docs/tuning-substitutions-spec.md`, sections 1 and 2. A
pattern with the parity twist of Derrida, Gervois, and Pomeau (`dgp`) is the
kneading form of tuning by a superattracting centre of period
`len(prefix) + 1`; the package treats it as finite combinatorics only. The
star product is defined so that `star_product(a, b).substitution()` equals
`compose(a.substitution(), b.substitution())` for every pair of patterns,
whatever their twists, and the DGP parity is closed under it.

Reference oracle: `tools/tuning_reference.py`.
"""

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
        """The pattern with the parity twist: an odd number of `1` in the prefix."""
        return TuningPattern.checked(prefix, dgp_twist(prefix))

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
