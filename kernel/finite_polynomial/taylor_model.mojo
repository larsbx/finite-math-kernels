# taylor_model.mojo
#
# Taylor models: K. Makino and M. Berz, "Taylor models and other validated
# functional inclusion methods", Int. J. Pure Appl. Math. 4(4) (2003) 379-456;
# introduced in M. Berz and K. Makino, "Verified integration of ODEs and flows
# using differential algebraic methods on high-order Taylor models", Reliable
# Computing 4(4) (1998) 361-369.
#
# Here, over rational complex boxes: a truncated jet over
# coefficient_ring.ComplexBoxRing in the local variable, plus a remainder box,
# over a domain box, with the guarantee
#
#     for every z = centre + e with e in domain,   g(z) in p(e) + remainder.
#
# A plain enclosure treats every occurrence of a variable as independent, so
# widths inflate through an iterated map. A model carries the correlation in
# the jet and encloses only what the truncation drops. Every operation keeps
# the guarantee: the remainder is an enclosure, never an equality, and nothing
# is dropped. A model is accepted only when its domain, remainder and jet are;
# an operation on a refused model, or on two models of different centre,
# domain or order, is refused.
#
# The model is over ComplexIQ, not over a generic enclosure ring: a struct
# whose fields have a trait's associated type trips the pinned compiler's
# "use of uninitialized value" bug (docs/mojo-exact-fields-report.md, 5.1), and
# boxes are the only enclosure ring with a consumer.
#
# Python oracle: reference/taylor_model_reference.py.
#
# Specification: docs/rational-interval-arithmetic-spec.md (coefficients are closed_q boxes).

from finite_exact.closed_q import ComplexIQ
from finite_polynomial.coefficient_ring import ComplexBoxRing
from finite_polynomial.truncated_jet import (
    TruncatedJet,
    jet_add,
    jet_convolve,
    jet_seed,
)

comptime BoxJet = TruncatedJet[ComplexBoxRing]


def enclosure_power(box: ComplexIQ, exponent: Int) -> ComplexIQ:
    """`box^exponent` by repeated squaring, with the sharp square.

    Not `box * box`: a product treats its two arguments as independent, so it
    is wider than the square whenever the box straddles an axis.
    """
    var ring = ComplexBoxRing()
    if exponent < 0 or not box.accepted():
        return ring.rejected()
    var result = ring.one()
    var base = box.copy()
    var remaining = exponent
    while remaining > 0:
        if remaining % 2 == 1:
            result = result.mul(base)
        remaining = remaining // 2
        if remaining > 0:
            base = base.square()
    return result^


def enclosure_evaluate(coefficients: List[ComplexIQ], domain: ComplexIQ) -> ComplexIQ:
    """Enclose `{p(e) : e in domain}` term by term, with sharp powers.

    **Not** Horner. Horner is tighter where the variable occurs once; here it
    occurs in every term, and its nesting multiplies the same box by itself
    repeatedly. Term by term is tighter on a box centred at the origin, which
    is the only kind of domain a model has.
    """
    var ring = ComplexBoxRing()
    if not domain.accepted() or len(coefficients) == 0:
        return ring.rejected()
    var total = coefficients[0].copy()
    for degree in range(1, len(coefficients)):
        if not ring.is_zero(coefficients[degree]):
            total = total.add(coefficients[degree].mul(enclosure_power(domain, degree)))
    return total^


struct TaylorModel(Copyable, Movable):
    """`p` in the local variable, plus a remainder, over a domain."""

    var centre: ComplexIQ
    var domain: ComplexIQ
    var polynomial: BoxJet
    var remainder: ComplexIQ

    def __init__(out self, centre: ComplexIQ, domain: ComplexIQ, polynomial: BoxJet, remainder: ComplexIQ):
        self.centre = centre.copy()
        self.domain = domain.copy()
        self.polynomial = polynomial.copy()
        self.remainder = remainder.copy()

    def order(self) -> Int:
        return self.polynomial.order()

    def accepted(self) -> Bool:
        return self.domain.accepted() and self.remainder.accepted() and self.polynomial.accepted()

    def enclosure(self) -> ComplexIQ:
        """`Enc(p) + remainder`: the correlation was kept until this moment."""
        if not self.accepted():
            return ComplexBoxRing().rejected()
        return enclosure_evaluate(self.polynomial.coeffs, self.domain).add(self.remainder)


def taylor_refused(model: TaylorModel) -> TaylorModel:
    var ring = ComplexBoxRing()
    return TaylorModel(model.centre, ring.rejected(), model.polynomial, ring.rejected())


def taylor_variable(centre: ComplexIQ, domain: ComplexIQ, order: Int) -> TaylorModel:
    """The identity `z = centre + e` over the domain: its own first-order jet,
    so the remainder is exactly zero."""
    var ring = ComplexBoxRing()
    return TaylorModel(centre, domain, jet_seed(ring, centre, order), ring.zero())


def _compatible(left: TaylorModel, right: TaylorModel) -> Bool:
    var ring = ComplexBoxRing()
    return (
        left.accepted() and right.accepted() and left.order() == right.order()
        and ring.identical(left.centre, right.centre) and ring.identical(left.domain, right.domain)
    )


def taylor_add_constant(model: TaylorModel, value: ComplexIQ) -> TaylorModel:
    """`model + value`: only the constant coefficient moves."""
    if not (model.accepted() and value.accepted()):
        return taylor_refused(model)
    var coeffs = model.polynomial.coeffs.copy()
    coeffs[0] = coeffs[0].add(value)
    return TaylorModel(model.centre, model.domain, BoxJet(ComplexBoxRing(), coeffs^), model.remainder)


def taylor_add(left: TaylorModel, right: TaylorModel) -> TaylorModel:
    """Componentwise, which is why the guarantee survives untouched."""
    if not _compatible(left, right):
        return taylor_refused(left)
    return TaylorModel(
        left.centre, left.domain,
        jet_add(left.polynomial, right.polynomial),
        left.remainder.add(right.remainder),
    )


def _truncate(model: TaylorModel, full: BoxJet, cross: ComplexIQ) -> TaylorModel:
    """The low part of a full product as the jet; its high part, which starts
    at degree order+1 so that power factors out, enclosed and added to `cross`
    as the remainder."""
    var order = model.order()
    var low = List[ComplexIQ]()
    for index in range(order + 1):
        low.append(full.coeffs[index].copy())
    var high = List[ComplexIQ]()
    for index in range(order + 1, len(full.coeffs)):
        high.append(full.coeffs[index].copy())
    var tail = ComplexBoxRing().zero()
    if len(high) > 0:
        tail = enclosure_evaluate(high, model.domain).mul(enclosure_power(model.domain, order + 1))
    return TaylorModel(model.centre, model.domain, BoxJet(ComplexBoxRing(), low^), tail.add(cross))


def taylor_mul(left: TaylorModel, right: TaylorModel) -> TaylorModel:
    """`(p + I)(q + J) = pq_low + [pq_high + p J + I q + I J]`.

    Every term of the bracket is enclosed rather than dropped: the tail the
    truncation discards is added back as a box.
    """
    if not _compatible(left, right):
        return taylor_refused(left)
    var cross = (
        enclosure_evaluate(left.polynomial.coeffs, left.domain).mul(right.remainder)
        .add(left.remainder.mul(enclosure_evaluate(right.polynomial.coeffs, right.domain)))
        .add(left.remainder.mul(right.remainder))
    )
    return _truncate(left, jet_convolve(left.polynomial, right.polynomial), cross)


def taylor_square(model: TaylorModel) -> TaylorModel:
    """`(p + I)^2 = pp_low + [pp_high + 2 p I + I^2]`.

    `taylor_mul(model, model)` with the cross terms `p I` and `I p` taken as
    one enclosure, doubled: the same box, one evaluation fewer.
    """
    if not model.accepted():
        return taylor_refused(model)
    var cross = enclosure_evaluate(model.polynomial.coeffs, model.domain).mul(model.remainder)
    cross = cross.add(cross).add(model.remainder.mul(model.remainder))
    return _truncate(model, jet_convolve(model.polynomial, model.polynomial), cross)
