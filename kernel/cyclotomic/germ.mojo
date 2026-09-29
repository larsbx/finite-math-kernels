# germ.mojo
#
# Q1 and Q2 of docs/rational-dynamics-cyclotomic-bridge.md over Q(zeta_q):
# truncated iterates of g(w) = lambda w + w^2, the parabolic factor P with
# w - g^n(w) = w^(n+1) P(w), and the reciprocal series 1/P. Each result names
# only finite algebra; what a coefficient means belongs to the consumer.

from cyclotomic.field import Cyc
from finite_exact.rat_q import Q


@fieldwise_init
struct CycSeries[q: Int](Copyable):
    """Coefficients of w^0, w^1, ... truncated to len(terms); sticky rejection."""

    var terms: List[Cyc[Self.q]]
    var rejected: Bool

    @staticmethod
    def refused() -> Self:
        return Self(List[Cyc[Self.q]](), True)

    def accepted(self) -> Bool:
        return not self.rejected

    def __mul__(self, other: Self) -> Self:
        """The truncated Cauchy product, to the length of self."""
        if self.rejected or other.rejected:
            return Self.refused()
        var out = List[Cyc[Self.q]]()
        for k in range(len(self.terms)):
            var acc = Cyc[Self.q].rational(Q.zero())
            for i in range(k + 1):
                acc = acc + self.terms[i] * other.terms[k - i]
            out.append(acc^)
        return Self(out^, False)



def _const[q: Int](n: Int) -> Cyc[q]:
    return Cyc[q].rational(Q.from_int(Int64(n)))


def truncated_iterate[q: Int](lam: Cyc[q], iterations: Int, order: Int) -> CycSeries[q]:
    """g^iterations(w) mod w^order for g(w) = lam w + w^2."""
    if iterations < 0 or order < 2 or not lam.accepted():
        return CycSeries[q].refused()
    var s = CycSeries[q]([_const[q](1 if k == 1 else 0) for k in range(order)], False)
    for _ in range(iterations):
        var square = s * s
        s = CycSeries[q]([lam * s.terms[k] + square.terms[k] for k in range(order)], False)
    return s^


def parabolic_factor[q: Int](lam: Cyc[q], period: Int) -> CycSeries[q]:
    """P with w - g^period(w) = w^(period+1) P(w) mod w^(2 period + 2).

    Refused unless the residual vanishes to order period + 1.
    """
    var order = 2 * period + 2
    var it = truncated_iterate(lam, period, order)
    if not it.accepted():
        return CycSeries[q].refused()
    var out = List[Cyc[q]]()
    for k in range(order):
        var r = _const[q](1 if k == 1 else 0) - it.terms[k]
        if k > period:
            out.append(r^)
        elif not r.is_zero():
            return CycSeries[q].refused()
    return CycSeries[q](out^, False)


def reciprocal_series[q: Int](p: CycSeries[q]) -> CycSeries[q]:
    """1/P to the length of P; refused when P(0) is zero or P is rejected."""
    if not p.accepted() or len(p.terms) == 0 or p.terms[0].is_zero() or not p.terms[0].accepted():
        return CycSeries[q].refused()
    var inv0 = p.terms[0].inverse()
    var acc: List[Cyc[q]] = [inv0.copy()]
    for k in range(1, len(p.terms)):
        var tail = _const[q](0)
        for i in range(1, k + 1):
            tail = tail + p.terms[i] * acc[k - i]
        acc.append(-(inv0 * tail))
    return CycSeries[q](acc^, False)


def reciprocal_series_coefficient[q: Int](p: CycSeries[q], k: Int) -> Cyc[q]:
    """[w^k] 1/P from the first k + 1 coefficients of P."""
    if not p.accepted() or k < 0 or k >= len(p.terms):
        return Cyc[q].refused()
    var inv = reciprocal_series(CycSeries[q]([p.terms[i].copy() for i in range(k + 1)], False))
    if not inv.accepted():
        return Cyc[q].refused()
    return inv.terms[k].copy()
