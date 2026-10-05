"""Executable laws for the finite_field_orbit package.

Run with `pixi run test-orbit-census`
(`mojo run -I kernel tests/finite_field_orbit/test_orbit_census.mojo`).

The kernel is checked against every golden vector in
`conformance/orbit_census_v1.txt` (written by `tools/make_orbit_vectors.py` from
the reference semantics), and the witness replay, which shares no code with
the census, is checked on its own.
"""

from certified_records.codec import vector_cases
from finite_field_orbit.census import (
    Agg,
    Block,
    census,
    decode,
    encode,
    merge,
    replay,
    request_verdict,
    step,
    witness_verdict,
)


def expect(label: String, got: String, want: String) raises:
    if got != want:
        raise Error(label + ": got '" + got + "', want '" + want + "'")


def check_vectors() raises -> Int:
    var text = open("conformance/orbit_census_v1.txt", "r").read()
    var checked = 0
    for row in vector_cases(text, "census"):
        var d = decode(row[0])
        expect("decode " + row[0], d.reason, "")
        expect("request " + row[0], request_verdict(d.block), "")
        expect("census", encode(d.block, census(d.block)), row[0])
        expect("replay " + row[0], replay(row[0]), "accepted")
        checked += 1
    for row in vector_cases(text, "tampered"):
        expect("tampered " + row[1], replay(row[1]), row[0])
        checked += 1
    for row in vector_cases(text, "request-malformed"):
        var v = List[Int]()
        for part in row[1].split(" "):
            v.append(Int(String(part)))
        expect("request " + row[1], request_verdict(Block(v[0], v[1], v[2], v[3], v[4])), "malformed:" + row[0])
        checked += 1
    for row in vector_cases(text, "wide"):
        var d = decode(row[0])
        expect("decode wide " + row[0], d.reason, "")
        expect("wide round trip", encode(d.block, d.agg), row[0])
        checked += 1
    for row in vector_cases(text, "decode-malformed"):
        expect("decode '" + row[1] + "'", decode(row[1]).reason, "malformed:" + row[0])
        expect("replay '" + row[1] + "'", replay(row[1]), "malformed:" + row[0])
        checked += 1
    return checked


def test_the_whole_contract_domain_is_supported() raises:
    """Every well-formed block is answered: a table of p words below 2^24, hashing above."""
    expect("p = 2^32 - 5", request_verdict(Block(4294967291, 0, 5, 0, 5)), "")
    expect("empty block at 2^32 - 5", replay("orbit-census-v1 4294967291 0 1 0 0 0 0 0 0 0 0 0 0 0"), "accepted")
    expect("still prime-checked", request_verdict(Block(4294967295, 0, 5, 0, 5)), "malformed:p")


def test_the_step_is_exact_in_64_bits() raises:
    """With p = 2^32 - 5, x^2 + c reaches 2^64 - 12 * 2^32: past Int, inside UInt64."""
    var p = 4294967291
    if step(p - 1, 5, p) != 6 or step(2147483648, 7, p) != 1073741836 or step(p - 1, p - 1, p) != 0:
        raise Error("step(x) = x^2 + c mod p is wrong near 2^32")


def test_sums_range_to_2_to_the_64() raises:
    """A sum is at most p^2 < 2^64: every value below 2^64 decodes and reaches replay."""
    expect("2^63 - 1", replay("orbit-census-v1 7 3 7 0 7 7 7 9223372036854775807 21 3 1 1 2 3"), "mismatch:sum_mu")
    expect("2^63", replay("orbit-census-v1 7 3 7 0 7 7 7 9223372036854775808 21 3 1 1 2 3"), "mismatch:sum_mu")
    expect("2^64 - 1", replay("orbit-census-v1 7 3 7 0 7 7 7 6 18446744073709551615 3 1 1 2 3"), "mismatch:sum_lambda")
    expect("2^64", decode("orbit-census-v1 7 3 7 0 7 7 7 6 18446744073709551616 3 1 1 2 3").reason, "malformed:sum_lambda")


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
    test_the_whole_contract_domain_is_supported()
    test_the_step_is_exact_in_64_bits()
    test_sums_range_to_2_to_the_64()
    test_witness_replay_is_independent()
    test_merge_is_partition_invariant()
    print("finite_field_orbit laws passed on", checked, "vectors.")
