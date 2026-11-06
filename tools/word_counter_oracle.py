"""Independent arbitrary-precision oracle for the fixed native overflow probe.

Python is supporting evidence, never the canonical count implementation.
Missing/refused fitting results and unrelated errors fail admission.
"""
import json
from math import comb

MAX = 2**63 - 1
ADDITION_ERROR = "checked integer addition overflow"
DIMENSION_ERROR = "checked integer multiplication overflow"
CONSTANTS = [(0, 0, 1), (1, 0, 1), (2, 0, 1),
             (3810778, 0, 1), (3810779, 0, 1), (3810780, 0, 1),
             (4000000, 0, 1), (3810779, 1, 2), (3810780, 1, 2)]


def check_transcript(text):
    def unique(pairs):
        result = {}
        for k, v in pairs:
            if k in result:
                raise ValueError("duplicate JSON key")
            result[k] = v
        return result
    rows = [json.loads(line, object_pairs_hook=unique) for line in text.splitlines()]
    expected = ([dict(kind="constant", length=n, letter=a, size=s) for n, a, s in CONSTANTS]
                + [dict(kind="addition", a=a, b=1) for a in (MAX-2, MAX-1, MAX)]
                + [dict(kind="k3", length=n, mode=r) for n, r in
                   [(3810779, 0), (3810779, 1), (3810780, 0), (3810780, 1), (3810780, 2)]]
                + [dict(kind="dimension", order=k) for k in (2, 3)])
    if len(rows) != len(expected):
        raise ValueError("missing or extra overflow probe case")
    for row, case in zip(rows, expected):
        keys = set(case) | {"value", "error"}
        if case["kind"] == "constant":
            keys |= {"n2", "parikh"}
        if set(row) != keys or any(type(row[k]) is not type(v) or row[k] != v
                                   for k, v in case.items()):
            raise ValueError("unexpected overflow probe workload")
        kind = case["kind"]
        if kind == "dimension":
            value, error = None, DIMENSION_ERROR
        else:
            if kind == "addition":
                exact = row["a"] + row["b"]
            else:
                n = row["length"]
                exact = comb(n, 3)
                if kind == "constant":
                    if type(row["n2"]) is not int or row["n2"] != comb(n, 2):
                        raise ValueError("native N2 disagrees with arbitrary-precision oracle")
                    if type(row["parikh"]) is not int or row["parikh"] != n:
                        raise ValueError("native Parikh disagrees with oracle")
                # Refuse when an operand count overflows, even if K3 fits.
                if kind == "k3" and exact <= MAX:
                    exact = 1-exact if row["mode"] == 1 else exact-1
            value = exact if exact <= MAX else None
            error = "" if value is not None else ADDITION_ERROR
        if (row["value"] != value or type(row["value"]) is not type(value)
                or row["error"] != error):
            raise ValueError("native overflow result/refusal disagrees with oracle: " + repr(row))
    return rows


def lean_replay(rows):
    """Closed checks of native observations, independently decided by Lean.

    Refused K3 checks the oversized operand, not the potentially fitting
    difference. The abstract machine model gives the propagation contract;
    these finite cases do not prove source refinement.
    """
    source = ["import FiniteMathKernels", "open FiniteMathKernels"]
    option = lambda v: "none" if v is None else f"some ({v} : ℤ)"
    for row in rows:
        kind = row["kind"]
        if kind == "constant":
            n = row["length"]
            proposition = (f"CheckedInt.accept64 (({n} : ℕ).choose 3) = {option(row['value'])} ∧ "
                           f"({n} : ℕ).choose 2 = {row['n2']} ∧ {n} = {row['parikh']}")
        elif kind == "addition":
            proposition = f"CheckedInt.accept64 ({row['a']}+{row['b']}) = {option(row['value'])}"
        elif kind == "k3":
            expr = f"(({row['length']} : ℕ).choose 3 : ℤ)"
            proposition = (f"CheckedInt.accept64 ({expr}) = none" if row["value"] is None
                           else (f"1-{expr} = {row['value']}" if row["mode"] == 1
                                 else f"{expr}-1 = {row['value']}" ))
        else:
            expr = "9223372036854775807 * 9223372036854775807" if row["order"] == 2 else "3000000^3"
            proposition = f"CheckedInt.accept64 ({expr}) = none"
        source.append(f"example : {proposition} := by\n"
                      "  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, "
                      "CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, "
                      "Nat.descFactorial, Nat.factorial]")
    return "\n".join(source) + "\n"


if __name__ == "__main__":
    import sys
    check_transcript(sys.stdin.read())
    print("19 native counter boundary/refusal cases agree with the arbitrary-precision oracle")
