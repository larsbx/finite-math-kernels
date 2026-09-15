"""Replays a vector transcript through the Mojo implementation.

Input (path in the REPLAY_INPUT environment variable, or argv[1]) is
written by tools/replay_mojo.py from
fixtures/vectors.json, one tab-separated line per item, counts before lists:

  P <name> <n> <tag> <reason> ...                  a named tag policy
  R <key> <id> <kind> <statement> <ndeps> <dep>... <nev> <k> <v>... <ntags> <tag>...
  C <root> <policy>                                a closure case

Output, one line per R and C in order:

  V <key> <kind after validate> <reason or empty> <canonical bytes as octets joined by ".">
  C <root> <0|1 complete> <reached joined by ","> <nlinks> <id> <reason> ...

No number printed here is trusted by the harness beyond the 0/1 flag and
the list counts; digests are recomputed in Python from the octets.
"""

from std.os import getenv
from std.sys import argv

from proof_records.records import Closure, Ledger, Pair, Record, TagPolicy, canonical_bytes, close, validate


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
    var deps = List[String]()
    for _ in range(take_count(fields, pos)):
        deps.append(take(fields, pos))
    var evidence = List[Pair]()
    for _ in range(take_count(fields, pos)):
        var key = take(fields, pos)
        var value = take(fields, pos)
        evidence.append(Pair(key, value))
    var tags = List[String]()
    for _ in range(take_count(fields, pos)):
        tags.append(take(fields, pos))
    return Record(id, kind, statement, deps, evidence, tags)


def main() raises:
    var path = getenv("REPLAY_INPUT", "")
    if path.byte_length() == 0:
        if len(argv()) < 2:
            raise Error("usage: REPLAY_INPUT=<transcript> mojo run -I . tests/replay_vectors.mojo")
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
            print("V\t" + key + "\t" + checked.kind + "\t" + reason + "\t" + octets(canonical_bytes(record)))
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
