"""Replay the cyclotomic-field-v1 golden vectors through the Mojo kernel.

The vectors are written by tools/make_cyclotomic_field_vectors.py from the
independent Python reference (Phi_q by recursive division, inverses by
extended Euclid). The kernel, finite_polynomial, computes Phi_q by the divisor
product identity and inverses by exact RREF, so agreement cross-checks two
methods. Each line is replayed through the typed view Cyc[q]; its runtime
conductor is dispatched to the compile-time field by an unrolled loop.
Run with `pixi run test-cyclotomic-field`.
"""

from finite_exact.bigint_z import BigZ, bigz_abs_mul_small, bigz_add, bigz_from_i64, bigz_neg
from finite_exact.exact_decimal import bigz_decimal
from finite_polynomial.cyclotomic_field import Cyc
from finite_polynomial.polynomial_z import cyclotomic_polynomial, poly_coefficient
from finite_polynomial.quadratic_germ import (
    jet_seed,
    jet_sub,
    quadratic_germ_index_coefficient,
    quadratic_germ_iterate,
)
from finite_exact.rat_q import Q, q_from_bigz

comptime FIXTURE = "conformance/cyclotomic_field_v1.txt"
comptime CONDUCTORS = 12


def fields(text: String, sep: String) -> List[String]:
    return [String(part) for part in text.split(sep)]


def integer(text: String) raises -> BigZ:
    """A decimal integer of any size."""
    var negative = text.startswith("-")
    var acc = bigz_from_i64(0)
    for i in range(1 if negative else 0, text.byte_length()):
        acc = bigz_add(bigz_abs_mul_small(acc, 10), bigz_from_i64(Int64(Int(text[byte=i]))))
    return bigz_neg(acc) if negative else acc^


def rational(text: String) raises -> Q:
    var parts = fields(text, "/")
    return q_from_bigz(integer(parts[0]), integer(parts[1]) if len(parts) == 2 else bigz_from_i64(1))


def element[q: Int](text: String) raises -> Cyc[q]:
    return Cyc[q].from_poly([rational(c) for c in fields(text, " ")])


def hex(bytes: List[UInt8]) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for b in bytes:
        out += digits[byte = Int(b >> 4)] + digits[byte = Int(b & 15)]
    return out^


def expect[q: Int](label: String, got: Cyc[q], want: String) raises:
    var agrees = not got.accepted() if want == "rejected" else got == element[q](want)
    if not agrees:
        raise Error(label + "\n  want " + want + "\n  got  " + String(got))


def replay[q: Int](cols: List[String]) raises:
    var kind = cols[0]
    var label = String("\t").join(cols)
    if kind == "phi":
        var want = fields(cols[2], " ")
        var phi = cyclotomic_polynomial(q)
        if phi.degree() != len(want) - 1:
            raise Error(label + ": deg Phi_q disagrees")
        for k in range(len(want)):
            if bigz_decimal(poly_coefficient(phi, k)) != want[k]:
                raise Error(label + ": Phi_q disagrees at X^" + String(k))
    elif kind == "mul":
        expect[q](label, element[q](cols[2]) * element[q](cols[3]), cols[4])
    elif kind == "inv":
        expect[q](label, element[q](cols[2]).inverse(), cols[3])
    elif kind == "aut":
        expect[q](label, element[q](cols[3]).galois(Int(cols[2])), cols[4])
    elif kind == "bytes":
        var enc = element[q](cols[2]).canonical_bytes()
        if enc.rejected or hex(enc.bytes) != cols[3]:
            raise Error(label + ": canonical bytes disagree")
    elif kind == "germ":
        # P(0) is the coefficient of w^(q+1) in w - g^q(w), from the kernel's jets.
        var p = Int(cols[2])
        var order = 2 * q + 1
        var residual = jet_sub(jet_seed(q, order), quadratic_germ_iterate(Cyc[q].zeta(p).value, q, order))
        if not residual.accepted():
            raise Error(label + ": germ iterate refused")
        expect[q](label, Cyc[q].wrap(residual.coeffs[q + 1]), cols[3])
        var coefficient = Cyc[q].wrap(quadratic_germ_index_coefficient(p, q))
        expect[q](label, coefficient, cols[4])
        if hex(coefficient.canonical_bytes().bytes) != cols[5]:
            raise Error(label + ": coefficient bytes disagree")
    else:
        raise Error("unknown vector kind " + kind)


def dispatch(cols: List[String]) raises:
    var q = Int(cols[1])
    comptime for conductor in range(1, CONDUCTORS + 1):
        if q == conductor:
            return replay[conductor](cols)
    raise Error("conductor outside the replayed range: " + cols[1])


def main() raises:
    var checked = 0
    for raw in open(FIXTURE, "r").read().split("\n"):
        var line = String(raw)
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        dispatch(fields(line, "\t"))
        checked += 1
    if checked < 200:
        raise Error("too few vectors replayed: " + String(checked))
    print(String(checked) + " cyclotomic-field-v1 vectors agree with the Python reference.")
