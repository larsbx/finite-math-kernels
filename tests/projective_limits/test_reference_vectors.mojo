"""Replay the projective-limits-v1 golden vectors through the Mojo kernel.

The vectors are written by tools/make_projective_limits_vectors.py from the
independent Python reference (cancellation and evaluation, polynomial
division), so agreement cross-checks the landing kernel against a different
method. Run with `pixi run test-projective-limits`.
"""

from finite_exact.rat_q import Q
from projective_limits.line import (
    P1,
    chordal_distance_squared,
    mobius,
    mobius_apply,
    p1_affine,
    p1_equal,
    p1_infinity,
    p1_rejected,
)
from projective_limits.limits import (
    Monomial,
    Poly,
    Poly2,
    RationalMap,
    asymptote,
    curve_limit,
    directional_limit,
    path_dependence_witness,
    rational_limit,
    tangent_slope,
)

comptime FIXTURE = "fixtures/projective_limits_v1.txt"


def fields(text: String, sep: String) -> List[String]:
    var out = List[String]()
    for part in text.split(sep):
        out.append(String(part))
    return out^


def rational(text: String) raises -> Q:
    var parts = fields(text, "/")
    var den = Int64(Int(parts[1])) if len(parts) == 2 else Int64(1)
    return Q(Int64(Int(parts[0])), den)


def point(text: String) raises -> P1:
    if text == "inf":
        return p1_infinity()
    if text == "rejected":
        return p1_rejected()
    return p1_affine(rational(text))


def poly(text: String) raises -> Poly:
    var out = Poly()
    for c in fields(text, " "):
        out.coeffs.append(rational(c))
    return out^


def poly2(text: String) raises -> Poly2:
    var out = Poly2()
    for term in fields(text, ";"):
        var ijc = fields(term, ",")
        out.terms.append(Monomial(Int(ijc[0]), Int(ijc[1]), rational(ijc[2])))
    return out^


def expect(label: String, got: P1, want: String) raises:
    var agrees = not got.accepted() if want == "rejected" else p1_equal(got, point(want))
    if not agrees:
        raise Error(label + ": want " + want)


def replay(cols: List[String]) raises:
    var kind = cols[0]
    var label = String("\t").join(cols)
    if kind == "limit":
        expect(label, rational_limit(RationalMap(poly(cols[1]), poly(cols[2])), point(cols[3])), cols[4])
    elif kind == "tangent":
        expect(label, tangent_slope(poly(cols[1]), poly(cols[2]), rational(cols[3])), cols[4])
    elif kind == "asymptote":
        var a = asymptote(RationalMap(poly(cols[1]), poly(cols[2])))
        expect(label, a.slope, cols[3])
        expect(label, a.intercept, cols[4])
    elif kind == "directional":
        expect(label, directional_limit(poly2(cols[1]), poly2(cols[2]), point(cols[3])), cols[4])
    elif kind == "curve":
        expect(label, curve_limit(poly2(cols[1]), poly2(cols[2]), poly(cols[3]), poly(cols[4])), cols[5])
    elif kind == "witness":
        var w = path_dependence_witness(poly2(cols[1]), poly2(cols[2]), Int(cols[3]))
        if w.found != (cols[4] != "none"):
            raise Error(label + ": found disagrees")
        if w.found:
            expect(label, w.first, cols[4])
            expect(label, w.first_limit, cols[5])
            expect(label, w.second, cols[6])
            expect(label, w.second_limit, cols[7])
    elif kind == "mobius":
        var m = fields(cols[1], " ")
        var f = mobius(rational(m[0]), rational(m[1]), rational(m[2]), rational(m[3]))
        expect(label, mobius_apply(f, point(cols[2])), cols[3])
    elif kind == "chordal":
        if not chordal_distance_squared(point(cols[1]), point(cols[2])).eq(rational(cols[3])):
            raise Error(label + ": want " + cols[3])
    else:
        raise Error("unknown vector kind " + kind)


def main() raises:
    var checked = 0
    for raw in open(FIXTURE, "r").read().split("\n"):
        var line = String(raw)
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        replay(fields(line, "\t"))
        checked += 1
    if checked < 400:
        raise Error("too few vectors replayed: " + String(checked))
    print(String(checked) + " projective-limits-v1 vectors agree with the Python reference.")
