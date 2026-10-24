# Batched exact spread by Montgomery's trick (one inverse, O(n) products).
#
# This is a field-generic algebraic optimization: for n accepted nonzero
# denominators compute all inverses using one field inversion, plus prefix
# and backward products. Undefined rays return a rejected value in place,
# without inserting a zero denominator into the inversion product.
# Never converts values into floats / MAX Tensor numeric approximations.

from finite_exact.field import ExactField
from projective_limits.hyperbolic_rt import norm8, polar8


def invert_batch_nonzero[K: ExactField](
    values: List[K.Element]
) -> List[K.Element]:
    """Invert all nonzero accepted field elements; reject entire invalid batch."""
    var prefixes = List[K.Element]()
    prefixes.append(K.one())
    for value in values:
        if not K.accepted(value) or K.is_zero(value):
            var bad = List[K.Element]()
            for _ in range(len(values)):
                bad.append(K.rejected())
            return bad^
        prefixes.append(K.mul(prefixes[len(prefixes) - 1], value))

    # For zero elements, return an empty list without performing any inverse.
    if len(values) == 0:
        return List[K.Element]()

    var inverse = K.div(K.one(), prefixes[len(values)])
    if not K.accepted(inverse):
        var bad = List[K.Element]()
        for _ in range(len(values)):
            bad.append(K.rejected())
        return bad^
    var result = List[K.Element](length=len(values), fill=K.zero())
    for k in range(len(values)):
        var i = len(values) - 1 - k
        result[i] = K.mul(prefixes[i], inverse)
        inverse = K.mul(inverse, values[i])
    return result^


def spreads_batched[K: ExactField](
    xs: List[List[K.Element]], ys: List[List[K.Element]]
) -> List[K.Element]:
    """Exact projective spread for aligned pairs, with one shared inverse.

    The bulk inverse uses neutral unit denominators for rejected pairs.
    If lengths differ, each output slot rejects (length=max sizes).
    """
    var count = len(xs)
    if len(ys) != count:
        count = max(count, len(ys))
        var mismatched = List[K.Element]()
        for _ in range(count):
            mismatched.append(K.rejected())
        return mismatched^

    var denominators = List[K.Element]()
    var numerators = List[K.Element]()
    var accepted = List[Bool]()
    for i in range(count):
        var nx = norm8[K](xs[i])
        var ny = norm8[K](ys[i])
        var good = K.accepted(nx) and K.accepted(ny) and not K.is_zero(nx) and not K.is_zero(ny)
        if good:
            var d = K.mul(K.from_int(4), K.mul(nx, ny))
            good = K.accepted(d) and not K.is_zero(d)
            if good:
                denominators.append(d^)
                var b = polar8[K](xs[i], ys[i])
                numerators.append(K.mul(b, b))
        if not good:
            denominators.append(K.one())
            numerators.append(K.zero())
        accepted.append(good)
    var inverses = invert_batch_nonzero[K](denominators)
    var spreads = List[K.Element]()
    for i in range(count):
        if accepted[i]:
            spreads.append(K.sub(K.one(), K.mul(numerators[i], inverses[i])))
        else:
            spreads.append(K.rejected())
    return spreads^
