"""Executable laws for the finite_field_orbit package.

Run with `pixi run test-orbit-census`
(`mojo run -I . tests/finite_field_orbit/test_orbit_census.mojo`).

The kernel is checked against every golden vector in
`fixtures/orbit_census_v1.txt` (written by `tools/make_orbit_vectors.py` from
the reference semantics), and the witness replay, which shares no code with
the census, is checked on its own.
"""

from finite_field_orbit.census import (
    Agg,
    Block,
    census,
    decode,
    encode,
    merge,
    replay,
    request_verdict,
    witness_verdict,
)


def expect(label: String, got: String, want: String) raises:
    if got != want:
        raise Error(label + ": got '" + got + "', want '" + want + "'")


def check_vectors() raises -> Int:
    var checked = 0
    for raw in open("fixtures/orbit_census_v1.txt", "r").read().split("\n"):
        var line = String(raw)
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        var cols = List[String]()
        for part in line.split("\t"):
            cols.append(String(part))
        if cols[0] == "census":
            var d = decode(cols[1])
            expect("decode " + cols[1], d.reason, "")
            expect("request " + cols[1], request_verdict(d.block), "")
            expect("census", encode(d.block, census(d.block)), cols[1])
            expect("replay " + cols[1], replay(cols[1]), "accepted")
        elif cols[0] == "tampered":
            expect("tampered " + cols[2], replay(cols[2]), cols[1])
        elif cols[0] == "request-malformed":
            var v = List[Int]()
            for part in cols[2].split(" "):
                v.append(Int(String(part)))
            expect("request " + cols[2], request_verdict(Block(v[0], v[1], v[2], v[3], v[4])), "malformed:" + cols[1])
        elif cols[0] == "decode-malformed":
            expect("decode '" + cols[2] + "'", decode(cols[2]).reason, "malformed:" + cols[1])
            expect("replay '" + cols[2] + "'", replay(cols[2]), "malformed:" + cols[1])
        else:
            raise Error("unknown vector kind " + cols[0])
        checked += 1
    return checked


def test_declared_domain_is_refused_as_unsupported() raises:
    """Well-formed but outside the kernel's table: unsupported, never malformed."""
    expect("p = 2^24 + 43", request_verdict(Block(16777259, 0, 5, 0, 5)), "unsupported:p")
    expect("replay above 2^24", replay("orbit-census-v1 4294967291 0 1 0 0 0 0 0 0 0 0 0 0 0"), "unsupported:p")
    expect("largest supported prime", request_verdict(Block(16777213, 0, 5, 0, 5)), "")


def test_witness_replay_is_independent() raises:
    """With p = 7, c = 3: 1 -> 4 -> 5 -> 0 -> 3 -> 5, so seed 1 has (mu, lambda) = (2, 3)."""
    var b = Block(7, 3, 7, 0, 7)
    expect("true witness", witness_verdict(b, Agg(1, 1, 2, 3, 0, 1, 1, 2, 3)), "")
    expect("seed range", witness_verdict(b, Agg(1, 1, 2, 3, 0, 1, 7, 2, 3)), "witness:range")
    expect("cap", witness_verdict(Block(7, 3, 4, 0, 7), Agg(1, 1, 2, 3, 0, 1, 1, 2, 3)), "witness:cap")
    expect("not a cycle", witness_verdict(b, Agg(1, 1, 2, 2, 0, 1, 1, 2, 2)), "witness:cycle")
    expect("not the first repeat", witness_verdict(b, Agg(1, 1, 3, 3, 0, 1, 1, 3, 3)), "witness:distinct")
    expect("pigeonhole", witness_verdict(Block(7, 3, 4000000000, 0, 7), Agg(1, 1, 3999999990, 3, 0, 1, 1, 3999999990, 3)), "witness:distinct")
    expect("zero lambda", witness_verdict(b, Agg(1, 1, 2, 0, 0, 1, 1, 2, 0)), "witness:cycle")
    expect("absent witness is zeros", witness_verdict(b, Agg(1, 0, 0, 0, 0, 0, 1, 0, 0)), "witness:canonical")
    expect("has_w is a flag", witness_verdict(b, Agg(1, 1, 2, 3, 0, 2, 1, 2, 3)), "witness:canonical")


def test_merge_is_partition_invariant() raises:
    var b = Block(1009, 2, 1009, 0, 1009)
    var whole = encode(b, census(b))
    for cut in [0, 1, 17, 500, 1008, 1009]:
        var left = census(Block(1009, 2, 1009, 0, cut))
        var right = census(Block(1009, 2, 1009, cut, 1009))
        expect("cut " + String(cut), encode(b, merge(left, right)), whole)
        expect("swapped " + String(cut), encode(b, merge(right, left)), whole)


def main() raises:
    var checked = check_vectors()
    if checked < 50:
        raise Error("only " + String(checked) + " vectors checked")
    test_declared_domain_is_refused_as_unsupported()
    test_witness_replay_is_independent()
    test_merge_is_partition_invariant()
    print("finite_field_orbit laws passed on", checked, "vectors.")
