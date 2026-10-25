"""Exact bounded power-residue membership over runtime Z/mZ.

This module owns finite arithmetic, not a Diophantine theorem or a search
certificate. A prefix filter stores every unordered positive pair (a,b),
1 <= a <= b <= max_base. Rejecting a missing residue is sound for an
application only when its admissible pair domain is a subset of that prefix.

All residues are canonical through Modulus; no floating-point computation,
probabilistic independence, or CRT distribution assumption is involved.
"""
from finite_polynomial.polynomial_fp import Modulus


def decimal_digit_sum(x: Int) raises -> Int:
    """Nonnegative base-ten digit sum; no decimal-to-float conversion."""
    if x < 0:
        raise Error("decimal digit sum requires nonnegative input")
    var n = x
    var total = 0
    while n > 0:
        total += n % 10
        n //= 10
    return total


def decimal_alternating_sum(x: Int) raises -> Int:
    """Units-first d0-d1+d2...; congruent to x modulo 11."""
    if x < 0:
        raise Error("decimal alternating sum requires nonnegative input")
    var n = x
    var total = 0
    var sign = 1
    while n > 0:
        total += sign * (n % 10)
        sign = -sign
        n //= 10
    return total


struct PairPowerResiduePrefix:
    """Complete pair-sum residue image for 1 <= a <= b <= max_base.

    Memory O(modulus+max_base); advancing from c-1 to c costs O(c)
    modular additions, and includes (c,c). Callers must not advance
    past their own finite work budget. The ring constructor enforces
    2 <= modulus < 2^31; an additional cap protects dense allocation.
    """

    var ring: Modulus
    var exponent: Int
    var powers: List[Int]
    var seen: List[Bool]

    def __init__(out self, modulus: Int, exponent: Int) raises:
        if modulus < 2 or modulus > 100000 or exponent < 1 or exponent > 64:
            raise Error("pair residue profile outside bounded domain")
        self.ring = Modulus(modulus)
        self.exponent = exponent
        self.powers = List[Int]()
        self.powers.append(0)
        self.seen = List[Bool](length=modulus, fill=False)

    def max_base(self) -> Int:
        return len(self.powers) - 1

    def advance(mut self) raises -> Int:
        """Extend by one base, retaining every earlier admissible pair."""
        var b = len(self.powers)
        var bpow = self.ring.pow(b, self.exponent)
        self.powers.append(bpow)
        var added = 0
        for a in range(1, b + 1):
            var residue = self.ring.add(self.powers[a], bpow)
            if not self.seen[residue]:
                self.seen[residue] = True
                added += 1
        return added

    def contains(self, value: Int) -> Bool:
        """Exact residue-membership test, including signed values."""
        return self.seen[self.ring.reduce(value)]

    def residue_power(self, value: Int) raises -> Int:
        return self.ring.pow(value, self.exponent)

    def cardinality(self) -> Int:
        var count = 0
        for item in self.seen:
            if item:
                count += 1
        return count
