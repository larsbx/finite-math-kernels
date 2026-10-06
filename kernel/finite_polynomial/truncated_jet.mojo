# truncated_jet.mojo
#
# Truncated jets over any CoefficientRing (finite_polynomial.coefficient_ring).
# A jet of order m is the coefficient list of
#
#     g(w + e) = a_0 + a_1 e + ... + a_m e^m    (mod e^(m+1)),
#
# and the truncation is the object: coefficients above the order are not
# computed wrongly, they are not part of it. Pushing the seed jet
# (w, 1, 0, ..., 0) through a polynomial map gives every derivative of its
# iterates at w at once, without forming a polynomial in the variable.
#
# Over an exact ring (Q, F_p, Q(zeta_n)) every operation is exact. Over an
# EnclosureRing the result encloses the exact jet of every choice of points
# in the input boxes. A jet is rejected, sticky, when it has no coefficient or
# any coefficient is not an accepted element of its ring; every operation
# refuses a rejected operand and operands of different orders.
#
# Python oracle: oracles/truncated_jet (the same algorithms over Fraction,
# Q(zeta_n) and Gaussian rationals).

from finite_polynomial.coefficient_ring import CoefficientField, CoefficientRing


struct TruncatedJet[R: CoefficientRing](Copyable, Movable):
    var ring: Self.R
    var coeffs: List[Self.R.Element]
    var rejected: Bool

    def __init__(out self, ring: Self.R, var coeffs: List[Self.R.Element]):
        var rejected = len(coeffs) == 0
        for coefficient in coeffs:
            if not ring.accepted(coefficient):
                rejected = True
        self.ring = ring.copy()
        self.coeffs = coeffs^
        self.rejected = rejected

    def accepted(self) -> Bool:
        return not self.rejected

    def order(self) -> Int:
        return len(self.coeffs) - 1


def rejected_jet[R: CoefficientRing](ring: R) -> TruncatedJet[R]:
    return TruncatedJet[R](ring, List[R.Element]())


def jet_constant[R: CoefficientRing](ring: R, value: R.Element, order: Int) -> TruncatedJet[R]:
    """`(value, 0, ..., 0)`: a jet that does not vary."""
    if order < 0:
        return rejected_jet(ring)
    var out = List[R.Element]()
    out.append(value.copy())
    for _ in range(order):
        out.append(ring.zero())
    return TruncatedJet[R](ring, out^)


def jet_seed[R: CoefficientRing](ring: R, point: R.Element, order: Int) -> TruncatedJet[R]:
    """`(point, 1, 0, ..., 0)`: the variable itself, expanded at `point`."""
    if order < 0:
        return rejected_jet(ring)
    var out = List[R.Element]()
    out.append(point.copy())
    for index in range(1, order + 1):
        out.append(ring.one() if index == 1 else ring.zero())
    return TruncatedJet[R](ring, out^)


def _comparable[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R]) -> Bool:
    return left.accepted() and right.accepted() and len(left.coeffs) == len(right.coeffs)


def jet_add[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R]) -> TruncatedJet[R]:
    if not _comparable(left, right):
        return rejected_jet(left.ring)
    var out = List[R.Element]()
    for index in range(len(left.coeffs)):
        out.append(left.ring.add(left.coeffs[index], right.coeffs[index]))
    return TruncatedJet[R](left.ring, out^)


def jet_sub[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R]) -> TruncatedJet[R]:
    if not _comparable(left, right):
        return rejected_jet(left.ring)
    var out = List[R.Element]()
    for index in range(len(left.coeffs)):
        out.append(left.ring.sub(left.coeffs[index], right.coeffs[index]))
    return TruncatedJet[R](left.ring, out^)


def jet_scale[R: CoefficientRing](state: TruncatedJet[R], factor: R.Element) -> TruncatedJet[R]:
    """`factor * state`, coefficientwise."""
    if state.rejected or not state.ring.accepted(factor):
        return rejected_jet(state.ring)
    var out = List[R.Element]()
    for coefficient in state.coeffs:
        out.append(state.ring.mul(factor, coefficient))
    return TruncatedJet[R](state.ring, out^)


def _product[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R], length: Int) -> TruncatedJet[R]:
    var out = List[R.Element]()
    for n in range(length):
        var total = left.ring.zero()
        for i in range(max(0, n - len(right.coeffs) + 1), min(n, len(left.coeffs) - 1) + 1):
            total = left.ring.add(total, left.ring.mul(left.coeffs[i], right.coeffs[n - i]))
        out.append(total^)
    return TruncatedJet[R](left.ring, out^)


def jet_convolve[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R]) -> TruncatedJet[R]:
    """The full product, of order `left.order() + right.order()`. Nothing is
    dropped: a Taylor model encloses the part above its order instead."""
    if left.rejected or right.rejected:
        return rejected_jet(left.ring)
    return _product(left, right, len(left.coeffs) + len(right.coeffs) - 1)


def jet_mul[R: CoefficientRing](left: TruncatedJet[R], right: TruncatedJet[R]) -> TruncatedJet[R]:
    """Truncated product: `(fg)_n = sum_(i+j=n) f_i g_j` for `n <= order`."""
    if not _comparable(left, right):
        return rejected_jet(left.ring)
    return _product(left, right, len(left.coeffs))


def jet_reciprocal[R: CoefficientField](state: TruncatedJet[R]) -> TruncatedJet[R]:
    """`1/state` to the same order; refused unless the constant term is a unit.

    `r_0 = 1/a_0` and `r_n = -r_0 * sum_(k=1..n) a_k r_(n-k)`.
    """
    if state.rejected:
        return rejected_jet(state.ring)
    var inv0 = state.ring.inverse(state.coeffs[0])
    if not state.ring.accepted(inv0):
        return rejected_jet(state.ring)
    var out = List[R.Element]()
    out.append(inv0.copy())
    for n in range(1, len(state.coeffs)):
        var total = state.ring.zero()
        for k in range(1, n + 1):
            total = state.ring.add(total, state.ring.mul(state.coeffs[k], out[n - k]))
        out.append(state.ring.sub(state.ring.zero(), state.ring.mul(inv0, total)))
    return TruncatedJet[R](state.ring, out^)


def jet_vanishing_order[R: CoefficientRing](state: TruncatedJet[R]) -> Int:
    """The least index whose coefficient is not certainly zero, or `-1`.

    `-1` states no multiplicity: either the jet is flat to the order computed
    (the order is *above* it, nothing more) or the jet is rejected, which
    `accepted()` tells apart. Over an enclosure ring the index is a lower
    bound for every point the boxes contain.
    """
    if state.rejected:
        return -1
    for index in range(len(state.coeffs)):
        if not state.ring.is_zero(state.coeffs[index]):
            return index
    return -1
