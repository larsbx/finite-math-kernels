# Exact rational trigonometry on split hyperbolic eight-spaces.
#
# Uses finite_exact.field.ExactField (QField, FpField[p], ...).
# V = K^8, N(x) = 2 sum_{i=0}^3 x_i x_{i+4}; B2 is the doubled
# polarization. Inputs of incorrect dimension or rejected field operands
# produce rejected output; division is performed only on checked non-null
# normals/rays. No field order, square root or transcendental is assumed.
#
# This is a classical quadratic contract, not a Cayley multiplication or
# a new theorem. The noncoplanar triple spread counterexample is deliberate.

from finite_exact.field import ExactField


def rejected8[K: ExactField]() -> List[K.Element]:
    """A length-eight vector of explicitly rejected coordinates."""
    var out = List[K.Element]()
    for _ in range(8):
        out.append(K.rejected())
    return out^


def valid8[K: ExactField](x: List[K.Element]) -> Bool:
    if len(x) != 8:
        return False
    for i in range(8):
        if not K.accepted(x[i]):
            return False
    return True


def add8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> List[K.Element]:
    if not valid8[K](x) or not valid8[K](y):
        return rejected8[K]()
    var out = List[K.Element]()
    for i in range(8):
        out.append(K.add(x[i], y[i]))
    return out^


def sub8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> List[K.Element]:
    if not valid8[K](x) or not valid8[K](y):
        return rejected8[K]()
    var out = List[K.Element]()
    for i in range(8):
        out.append(K.sub(x[i], y[i]))
    return out^


def scale8[K: ExactField](a: K.Element, x: List[K.Element]) -> List[K.Element]:
    if not K.accepted(a) or not valid8[K](x):
        return rejected8[K]()
    var out = List[K.Element]()
    for i in range(8):
        out.append(K.mul(a, x[i]))
    return out^


def norm8[K: ExactField](x: List[K.Element]) -> K.Element:
    """Hyperbolic norm: B2(e_i, f_j) = 2 delta_ij."""
    if not valid8[K](x):
        return K.rejected()
    var n = K.zero()
    for i in range(4):
        n = K.add(n, K.mul(x[i], x[i + 4]))
    return K.mul(K.from_int(2), n)


def polar8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> K.Element:
    """B2(x,y), using direct field contractions (no divisions)."""
    if not valid8[K](x) or not valid8[K](y):
        return K.rejected()
    var b = K.zero()
    for i in range(4):
        b = K.add(b, K.add(K.mul(x[i], y[i + 4]), K.mul(x[i + 4], y[i])))
    return K.mul(K.from_int(2), b)


def quadrance8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> K.Element:
    return norm8[K](sub8[K](y, x))


def spread8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> K.Element:
    """Guarded 1 - B2(x,y)^2/(4N(x)N(y)); rejected if any null ray."""
    var nx = norm8[K](x)
    var ny = norm8[K](y)
    if not K.accepted(nx) or not K.accepted(ny):
        return K.rejected()
    if K.is_zero(nx) or K.is_zero(ny):
        return K.rejected()
    var b = polar8[K](x, y)
    var den = K.mul(K.from_int(4), K.mul(nx, ny))
    if K.is_zero(den):
        return K.rejected()  # characteristic 2, or inappropriate field contract
    return K.sub(K.one(), K.div(K.mul(b, b), den))


def reflection8[K: ExactField](x: List[K.Element], a: List[K.Element]) -> List[K.Element]:
    """Orthogonal reflection in a non-null normal; refuses null normals."""
    var n = norm8[K](a)
    if not K.accepted(n) or K.is_zero(n) or not valid8[K](x):
        return rejected8[K]()
    var t = K.div(polar8[K](x, a), n)
    if not K.accepted(t):
        return rejected8[K]()
    return sub8[K](x, scale8[K](t, a))


def equal8[K: ExactField](x: List[K.Element], y: List[K.Element]) -> Bool:
    if not valid8[K](x) or not valid8[K](y):
        return False
    for i in range(8):
        if not K.eq(x[i], y[i]):
            return False
    return True


def norm_shell_transport8[K: ExactField](
    x: List[K.Element], target: List[K.Element]
) -> List[K.Element]:
    """<=2 non-null reflections; no intermediate search or inverse of zero.

    Exact formula: if N(x-target) != 0 reflect there; otherwise reflect in
    x+target to obtain -target, then in target to obtain target.
    Rejected input or incompatible/zero norms give rejected8.
    """
    var nx = norm8[K](x)
    var nt = norm8[K](target)
    if not K.accepted(nx) or not K.accepted(nt):
        return rejected8[K]()
    if K.is_zero(nx) or not K.eq(nx, nt):
        return rejected8[K]()
    var delta = sub8[K](x, target)
    var nd = norm8[K](delta)
    if not K.is_zero(nd):
        return reflection8[K](x, delta)
    var midpoint_normal = add8[K](x, target)
    var first = reflection8[K](x, midpoint_normal)
    return reflection8[K](first, target)


def triple_spread_defect[K: ExactField](
    a: K.Element, b: K.Element, c: K.Element
) -> K.Element:
    """Zero for guarded planar triples, NOT for independent 8D triples."""
    var total = K.add(K.add(a, b), c)
    var squares = K.add(K.add(K.mul(a, a), K.mul(b, b)), K.mul(c, c))
    return K.sub(
        K.sub(K.mul(total, total), K.mul(K.from_int(2), squares)),
        K.mul(K.from_int(4), K.mul(K.mul(a, b), c))
    )
