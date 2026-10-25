"""Native vectors for exact prefix pair-power residues and digit folds."""
from finite_polynomial.pair_power_residue import (
    PairPowerResiduePrefix, decimal_digit_sum, decimal_alternating_sum
)


def main() raises:
    for value in [0, 9, 10, 11, 25, 99, 110, 144, 123456789]:
        print("DIGIT", value, decimal_digit_sum(value), decimal_alternating_sum(value))
    for modulus in [9, 11, 25, 99, 2475]:
        var prefix = PairPowerResiduePrefix(modulus, 5)
        for c in range(1, 144):
            var added = prefix.advance()
            if c == 1 or c == 2 or c == 8 or c == 32 or c == 143:
                print("CARD", modulus, c, prefix.cardinality(), added)
            # Verify every enumerated pair at small prefix heights.
            if c <= 8:
                for a in range(1, c + 1):
                    for b in range(a, c + 1):
                        var r = prefix.ring.add(
                            prefix.residue_power(a), prefix.residue_power(b)
                        )
                        if not prefix.contains(r):
                            raise Error("false negative in native prefix table")
        if prefix.max_base() != 143:
            raise Error("incorrect prefix progression")
    var p25 = PairPowerResiduePrefix(25, 5)
    _ = p25.advance()
    if p25.contains(0) or not p25.contains(2) or not p25.contains(27):
        raise Error("negative/positive modular membership contract violated")
    print("NEGATIVE ACCEPT")
    for x in [-1, -999]:
        var rejected = False
        try:
            _ = decimal_digit_sum(x)
        except:
            rejected = True
        if not rejected:
            raise Error("negative digit sum accepted")
    print("NEGATIVE DIGIT REFUSED")
    var rejected_mod = False
    try:
        _ = PairPowerResiduePrefix(100001, 5)
    except:
        rejected_mod = True
    if not rejected_mod:
        raise Error("oversized dense residue filter accepted")
    print("OVERSIZE REFUSED")
