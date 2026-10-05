"""Port executable for the `orbit-census-v1` Mojo kernel.

    census_cli census P C CAP LO HI    one record line, or malformed:<field>
    census_cli replay RECORD           accepted, or the authority's first reason not to

Always exactly one line on stdout and exit status 0 for an answer, so the
orchestrator reads any other behaviour (a crash, silence, a second line) as an
infrastructure fault and never as a verdict.
"""

from std.sys import argv

from finite_field_orbit.census import Block, census, encode, parse_canonical, replay, request_verdict


def answer_census(args: List[String]) raises -> String:
    var names: List[String] = ["p", "c", "cap", "lo", "hi"]
    if len(args) != 5:
        return "malformed:arity"
    var v = List[Int]()
    for i in range(5):
        var value = parse_canonical(args[i])
        if not value:
            return "malformed:" + names[i]
        v.append(Int(value.value()))
    var b = Block(v[0], v[1], v[2], v[3], v[4])
    var refusal = request_verdict(b)
    return refusal if refusal.byte_length() > 0 else encode(b, census(b))


def main() raises:
    var args = List[String]()
    for a in argv():
        args.append(String(a))
    if len(args) == 7 and args[1] == "census":
        print(answer_census(List[String](args[2:])))
    elif len(args) == 3 and args[1] == "replay":
        print(replay(args[2]))
    else:
        print("malformed:arity")
