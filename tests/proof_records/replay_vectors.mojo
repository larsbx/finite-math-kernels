"""Replays a vector transcript through the Mojo implementation.

Input (path in the REPLAY_INPUT environment variable, or argv[1]) is
written by tools/replay_mojo.py from fixtures/vectors.json, one
tab-separated line per item, counts before lists:

  P <name> <n> <tag> <reason> ...                  a named tag policy
  R <key> <id> <kind> <statement> <scope> <ndeps> (<rid> <claim> <site> <relation> <outcome>)...
    <nev> <k> <v>... <ntags> <tag>...
  C <root> <policy>                                a closure case

Output, one line per R and C in order:

  V <key> <kind after validate> <reason or empty> <identity> <canonical bytes as octets joined by ".">
  C <root> <0|1 complete> <reached joined by ","> <nlinks> <id> <reason> ...

The identity is this implementation's SHA-256 over the preimage; the harness
compares it with the Python reference on every record. No other number
printed here is trusted by the harness beyond the 0/1 flag and the list
counts; digests of the octets are recomputed in Python. Before printing, the
driver checks the FIPS 180-4 known answers for SHA-256.
"""

from std.os import getenv
from std.sys import argv

from proof_records.records import Closure, Edge, Ledger, Pair, Record, TagPolicy, canonical_bytes, close, identity, validate
from proof_records.sha256 import hex, sha256


def octets(bytes: List[UInt8]) -> String:
    var parts = List[String]()
    for i in range(len(bytes)):
        parts.append(String(Int(bytes[i])))
    return String(".").join(parts)


def take(fields: List[String], mut pos: Int) -> String:
    var value = fields[pos]
    pos += 1
    return value


def take_count(fields: List[String], mut pos: Int) raises -> Int:
    return Int(take(fields, pos))


def parse_record(fields: List[String], mut pos: Int) raises -> Record:
    var id = take(fields, pos)
    var kind = take(fields, pos)
    var statement = take(fields, pos)
    var scope = take(fields, pos)
    var deps = List[Edge]()
    for _ in range(take_count(fields, pos)):
        var record_id = take(fields, pos)
        var claim = take(fields, pos)
        var site = take(fields, pos)
        var relation = take(fields, pos)
        var required = take(fields, pos)
        deps.append(Edge(record_id, claim, site, relation, required))
    var evidence = List[Pair]()
    for _ in range(take_count(fields, pos)):
        var key = take(fields, pos)
        var value = take(fields, pos)
        evidence.append(Pair(key, value))
    var tags = List[String]()
    for _ in range(take_count(fields, pos)):
        tags.append(take(fields, pos))
    return Record(id, kind, statement, scope, deps, evidence, tags)


def check_sha256_known_answers() raises:
    var empty = List[UInt8]()
    if hex(sha256(empty)) != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855":
        raise Error("SHA-256 known answer failed for the empty message")
    var abc = List[UInt8]()
    for byte in String("abc").as_bytes():
        abc.append(byte)
    if hex(sha256(abc)) != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad":
        raise Error("SHA-256 known answer failed for abc")
    var long = List[UInt8]()
    for byte in String("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq").as_bytes():
        long.append(byte)
    if hex(sha256(long)) != "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1":
        raise Error("SHA-256 known answer failed for the two-block message")


def main() raises:
    check_sha256_known_answers()
    var path = getenv("REPLAY_INPUT", "")
    if path.byte_length() == 0:
        if len(argv()) < 2:
            raise Error("usage: REPLAY_INPUT=<transcript> mojo run -I . tests/proof_records/replay_vectors.mojo")
        path = String(argv()[1])
    var text = open(path, "r").read()
    var ledger = Ledger()
    var policy_names = List[String]()
    var policies = List[TagPolicy]()
    for raw in text.split("\n"):
        var line = String(raw)
        if line.byte_length() == 0:
            continue
        var fields = List[String]()
        for part in line.split("\t"):
            fields.append(String(part))
        var pos = 1
        if fields[0] == "P":
            var name = take(fields, pos)
            var policy = TagPolicy()
            for _ in range(take_count(fields, pos)):
                var tag = take(fields, pos)
                var reason = take(fields, pos)
                policy.forbid(tag, reason)
            policy_names.append(name)
            policies.append(policy^)
        elif fields[0] == "R":
            var key = take(fields, pos)
            var record = parse_record(fields, pos)
            ledger.add(key, record)
            var checked = validate(record)
            var reason = checked.field("reason") if checked.kind == "rejected" else String("")
            print("V\t" + key + "\t" + checked.kind + "\t" + reason + "\t" + identity(record) + "\t" + octets(canonical_bytes(record)))
        elif fields[0] == "C":
            var root = take(fields, pos)
            var name = take(fields, pos)
            var found = -1
            for i in range(len(policy_names)):
                if policy_names[i] == name:
                    found = i
            if found < 0:
                raise Error("unknown policy " + name)
            var closure = close(ledger, root, policies[found])
            var out = "C\t" + root + "\t" + ("1" if closure.complete else "0") + "\t" + String(",").join(closure.reached) + "\t" + String(len(closure.missing_links))
            for i in range(len(closure.missing_links)):
                out += "\t" + closure.missing_links[i].record_id + "\t" + closure.missing_links[i].reason
            print(out)
        else:
            raise Error("unknown line kind " + fields[0])
