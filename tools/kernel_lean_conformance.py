"""Translate strict native transcripts into closed Lean propositions.

No Python result is accepted as mathematical evidence: Lean checks every output.
The deterministic workload is repeated here solely to reject omissions/changes.
"""
from __future__ import annotations

import itertools
import json

BOUNDS = [0, 1, -1, -(2**63), 2**63-1, 3037000499, 3037000500]
SCHEMAS = {
    "word": ({"size", "input"}, {"parikh", "pairs", "triples"}),
    "substitution": ({"images", "input", "n"}, {"output", "incidence", "prefix_lengths"}),
    "integer": ({"op", "a", "b"}, {"output"}),
    "field": ({"p", "a", "b", "op", "reject"}, {"output", "refusal_eq"}),
    "cuts": ({"size", "u", "v"}, {"output"}),
}


def workloads():
    out = []
    for size in range(1, 5):
        for length in range(4):
            for code in range(size**length):
                word = [(code // size**i) % size for i in range(length)]
                out.append(dict(kind="word", size=size, input=word))
    out.append(dict(kind="word", size=13, input=[0, 12, 0]))
    for n in range(5):
        for images, word in [([[0, 1], [0]], [0, 1, 0]),
                             ([[0, 1], [0, 2], [0]], [0, 1, 2]),
                             ([[0, 1], [0, 2], [0, 3], [0]], [3, 0, 1])]:
            out.append(dict(kind="substitution", images=images, input=word, n=n))
    for a in BOUNDS:
        for b in BOUNDS:
            for op in range(3):
                out.append(dict(kind="integer", op=op, a=a, b=b))
        out.extend(dict(kind="integer", op=op, a=a, b=0) for op in [3, 4])
    for a, b, op in itertools.product(range(-1, 3), range(-1, 3), range(3)):
        out.append(dict(kind="field", p=7, a=a, b=b, op=op, reject=False))
    out.extend(dict(kind="field", p=7, a=0, b=1, op=op, reject=True) for op in range(3))
    out.append(dict(kind="cuts", size=2, u=[0, 1, 1, 0], v=[1, 0, 0, 1]))
    return out


def strict_json(text):
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=object_pairs)


def integer(value, *, natural=False):
    if type(value) is not int or abs(value) > 2**64 or (natural and value < 0):
        raise ValueError("invalid integer literal")
    return str(value) if value >= 0 else "(-" + str(-value) + ")"


def vector(value):
    if type(value) is not list or len(value) > 10000:
        raise ValueError("invalid vector")
    return "[" + ",".join(integer(x, natural=True) for x in value) + "]"


def option_int(value):
    return "none" if value is None else "some (" + integer(value) + ")"


def proposition(r):
    kind = r["kind"]
    if kind == "word":
        size, word = integer(r["size"], natural=True), vector(r["input"])
        return " ∧ ".join(f"Conformance.{name} {size} {word} = {vector(r[field])}"
                          for name, field in [("parikhVector", "parikh"), ("pairVector", "pairs"),
                                              ("tripleVector", "triples")])
    if kind == "substitution":
        images = "[" + ",".join(vector(w) for w in r["images"]) + "]"
        word, n = vector(r["input"]), integer(r["n"], natural=True)
        return (f"Words.iterate (Conformance.substitution {images}) {n} {word} = {vector(r['output'])} ∧ "
                f"Conformance.incidenceVector {images} = {vector(r['incidence'])} ∧ "
                f"Conformance.prefixLengths {images} {word} = {vector(r['prefix_lengths'])}")
    if kind == "integer":
        a, b = integer(r["a"]), integer(r["b"])
        expr = [f"{a}+{b}", f"{a}-{b}", f"{a}*{b}", f"-{a}", f"|{a}|"][r["op"]]
        return f"CheckedInt.accept64 ({expr}) = {option_int(r['output'])}"
    if kind == "cuts":
        return (f"Conformance.zeroReturns {integer(r['size'], natural=True)} "
                f"{vector(r['u'])} {vector(r['v'])} = {vector(r['output'])}")
    if kind == "field":
        p = integer(r["p"], natural=True)
        a = f"some (({integer(r['a'])} : ℤ) : ZMod {p})"
        b = "none" if r["reject"] else f"some (({integer(r['b'])} : ℤ) : ZMod {p})"
        operation = ["add", "mul", "div"][r["op"]]
        expected = "none" if r["output"] is None else f"some (({integer(r['output'], natural=True)} : ℕ) : ZMod {p})"
        # The kernel, not a Python arithmetic check, must also reject v+p.
        canonical = "True" if r["output"] is None else f"({integer(r['output'], natural=True)} : ℕ) < {p}"
        if type(r["refusal_eq"]) is not bool:
            raise ValueError("refusal equality must be boolean")
        eq = "true" if r["refusal_eq"] else "false"
        return (f"AcceptedField.{operation} ({a}) ({b}) = {expected} ∧ ({canonical}) ∧ "
                f"AcceptedField.eqAccepted (none : Option (ZMod {p})) none = {eq}")
    raise ValueError("unknown record kind")


def generate(text):
    records = [strict_json(line) for line in text.splitlines()]
    expected = workloads()
    if len(records) != len(expected):
        raise ValueError("native transcript workload count mismatch")
    statements = []
    for i, (r, want) in enumerate(zip(records, expected, strict=True)):
        if type(r) is not dict or r.get("kind") not in SCHEMAS:
            raise ValueError("unknown native record")
        inputs, outputs = SCHEMAS[r["kind"]]
        if set(r) != {"kind"} | inputs | outputs:
            raise ValueError("native record schema mismatch")
        actual_input = {k: v for k, v in r.items() if k not in outputs}
        # Comparing canonical JSON also distinguishes bool from integer inputs.
        if json.dumps(actual_input, sort_keys=True) != json.dumps(want, sort_keys=True):
            raise ValueError("native workload identity/order mismatch")
        statements.append(f"theorem native_case_{i:04d} : {proposition(r)} := by decide")
    code = ("import FiniteMathKernels\nset_option maxRecDepth 100000\n"
            "set_option maxHeartbeats 4000000\nnamespace FiniteMathKernels.NativeReplay\n"
            "local instance : Fact (Nat.Prime 7) := ⟨by decide⟩\n"
            + "\n".join(statements) + "\nend FiniteMathKernels.NativeReplay\n")
    return code, len(records)
