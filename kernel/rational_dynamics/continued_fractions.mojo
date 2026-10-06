"""Regular continued fractions and convergents of a reduced fraction, exactly.

The simple continued fraction `[a0; a1, ..., an]` of a nonnegative rational
is read off the Euclidean algorithm, and its convergents `h_k / k_k` follow
the recurrences `h_k = a_k h_(k-1) + h_(k-2)`, `k_k = a_k k_(k-1) + k_(k-2)`.
References: A. Ya. Khinchin, *Continued Fractions* (1935; English
translation, University of Chicago Press, 1964), sections 1-2; G. H. Hardy
and E. M. Wright, *An Introduction to the Theory of Numbers* (1938; 6th ed.,
Oxford, 2008), chapter X. The independent Python reference is the
`continued_fractions` module of `oracles/rational_dynamics_py`.

Previously in `rational_dynamics/rational.mojo`, which still re-exports every
name here. What is claimed: the terms and convergents are the exact BigZ
values of the definition. What is not: any approximation or dynamical
statement a consumer reads into them.
"""

from finite_exact.bigint_z import BigZ, bigz_add, bigz_divmod, bigz_from_i64, bigz_mul, bigz_zero
from rational_dynamics.rational import ReducedFraction


struct ContinuedFractionResult(Copyable, Movable):
    var terms: List[BigZ]
    var rejected: Bool

    def __init__(out self):
        self.terms = List[BigZ]()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


struct ConvergentsResult(Copyable, Movable):
    var numerators: List[BigZ]
    var denominators: List[BigZ]
    var rejected: Bool

    def __init__(out self):
        self.numerators = List[BigZ]()
        self.denominators = List[BigZ]()
        self.rejected = False

    def accepted(self) -> Bool:
        return not self.rejected


def rejected_cf() -> ContinuedFractionResult:
    var out = ContinuedFractionResult()
    out.rejected = True
    return out^


def rejected_convergents() -> ConvergentsResult:
    var out = ConvergentsResult()
    out.rejected = True
    return out^


def continued_fraction(value: ReducedFraction) -> ContinuedFractionResult:
    """Canonical simple continued fraction of a nonnegative reduced rational."""
    if value.rejected:
        return rejected_cf()

    var out = ContinuedFractionResult()
    var a = value.num.copy()
    var b = value.den.copy()
    while not b.is_zero():
        var division = bigz_divmod(a, b)
        if division.rejected or division.remainder.sign < 0:
            return rejected_cf()
        out.terms.append(division.quotient.copy())
        a = b.copy()
        b = division.remainder.copy()
    return out^


def convergents(value: ReducedFraction) -> ConvergentsResult:
    """All convergents of the canonical simple continued fraction."""
    var expansion = continued_fraction(value)
    if expansion.rejected:
        return rejected_convergents()

    var out = ConvergentsResult()
    var h_minus_two = bigz_zero()
    var h_minus_one = bigz_from_i64(1)
    var k_minus_two = bigz_from_i64(1)
    var k_minus_one = bigz_zero()

    for index in range(len(expansion.terms)):
        var coefficient = expansion.terms[index].copy()
        var h = bigz_add(bigz_mul(coefficient, h_minus_one), h_minus_two)
        var k = bigz_add(bigz_mul(coefficient, k_minus_one), k_minus_two)
        out.numerators.append(h.copy())
        out.denominators.append(k.copy())
        h_minus_two = h_minus_one.copy()
        h_minus_one = h.copy()
        k_minus_two = k_minus_one.copy()
        k_minus_one = k.copy()
    return out^
