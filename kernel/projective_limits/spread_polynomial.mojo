# spread_polynomial.mojo
#
# The spread polynomials S_n of rational trigonometry, over an exact field K.
#
# S_n is the polynomial with s(n theta) = S_n(s(theta)) for the spread
# s = sin^2: S_0 = 0, S_1 = s, S_{k+1} = 2 (1 - 2 s) S_k - S_{k-1} + 2 s, and
# S_{-n} = S_n. They are defined over any field and need no angle. References:
# N. J. Wildberger, *Divine Proportions: Rational Trigonometry to Universal
# Geometry* (Wild Egg, 2005), chapter 7; S. Goh and N. J. Wildberger, "Spread
# polynomials, rotations and the butterfly effect", arXiv:0911.1025 (2009).
#
# `spread_polynomial` was previously in rotor.mojo, which reads the spread of a
# rotor with it and still re-exports it.

from finite_exact.field import ExactField, QField


def spread_polynomial[K: ExactField = QField](n: Int, s: K.Element) -> K.Element:
    """S_n(s): S_0 = 0, S_1 = s, S_{k+1} = 2 (1 - 2 s) S_k - S_{k-1} + 2 s; S_{-n} = S_n."""
    var m = n if n >= 0 else -n
    if m == 0:
        return K.zero()
    var two = K.from_int(2)
    var step = K.mul(two, K.sub(K.one(), K.mul(two, s)))
    var lift = K.mul(two, s)
    var prev = K.zero()
    var cur = s.copy()
    for _ in range(1, m):
        var next = K.add(K.sub(K.mul(step, cur), prev), lift)
        prev = cur^
        cur = next^
    return cur^
