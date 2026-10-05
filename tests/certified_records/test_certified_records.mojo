"""Laws of the certified_records codec, on the vectors the Python half reads too.

Run with `pixi run test-certified-records`
(`mojo run -I kernel tests/certified_records/test_certified_records.mojo`).
"""

from certified_records.codec import Schema, decode, encode, first_mismatch, parse_canonical, vector_cases


def toy() -> Schema:
    return Schema("toy-v1", ["a", "b"], [32, 64])


def expect(label: String, got: String, want: String) raises:
    if got != want:
        raise Error(label + ": got '" + got + "', want '" + want + "'")


def check_vectors() raises -> Int:
    var text = open("conformance/certified_records_v1.txt", "r").read()
    var schema = toy()
    var checked = 0
    for row in vector_cases(text, "decode-ok"):
        var d = decode(schema, row[0])
        expect("decode " + row[0], d.reason, "")
        expect("round trip", encode(schema, d.values), row[0])
        checked += 1
    for row in vector_cases(text, "decode-malformed"):
        expect("decode '" + row[1] + "'", decode(schema, row[1]).reason, "malformed:" + row[0])
        checked += 1
    for row in vector_cases(text, "mismatch"):
        var claimed = decode(schema, row[1]).values.copy()
        var actual = decode(schema, row[2]).values.copy()
        expect("mismatch " + row[1], first_mismatch(schema, claimed, actual), row[0])
        checked += 1
    return checked


def test_widths() raises:
    if parse_canonical("4294967295", 32).value() != UInt64(4294967295) or parse_canonical("4294967296", 32):
        raise Error("32-bit bound")
    if parse_canonical("18446744073709551615", 64).value() != UInt64.MAX or parse_canonical("18446744073709551616", 64):
        raise Error("64-bit bound")
    for token in ["", "00", "007", "+1", "-0", " 1", "1 "]:
        if parse_canonical(token, 64):
            raise Error("accepted non-canonical '" + token + "'")


def test_prefix_skip() raises:
    var schema = toy()
    var a = decode(schema, "toy-v1 1 2").values.copy()
    var b = decode(schema, "toy-v1 9 3").values.copy()
    expect("from 0", first_mismatch(schema, a, b), "mismatch:a")
    expect("from 1", first_mismatch(schema, a, b, start=1), "mismatch:b")


def main() raises:
    var checked = check_vectors()
    if checked < 20:
        raise Error("only " + String(checked) + " vectors checked")
    test_widths()
    test_prefix_skip()
    print("certified_records laws passed on", checked, "vectors.")
