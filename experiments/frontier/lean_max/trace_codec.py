"""Versioned, problem-bound interchange for successful Lean-MAX certificates."""
from hashlib import sha256
import json
import struct

import reference as ref

_HEADER = struct.Struct("<8s32sHH")
_RECORD = struct.Struct("<6H")
_MAGIC = b"LMTRACE\x01"
_UNUSED = 0xFFFF
_RULES = ("hyp", "refl", "symm", "congr", "trans")
_ARITIES = (0, 0, 1, 1, 2)


def _problem_digest(problem: ref.Problem) -> bytes:
    # The order and JSON encoding are part of wire version 1.
    fields = [
        problem.atoms,
        problem.functions,
        [(term.kind, term.name, term.child) for term in problem.terms],
        problem.premises,
        problem.goal,
    ]
    return sha256(json.dumps(fields, ensure_ascii=True, separators=(",", ":")).encode("ascii")).digest()


def encode_trace(problem: ref.Problem, result: dict) -> bytes:
    """Replay and serialize a successful certificate."""
    ref.replay(problem, result)
    records = result["steps"]
    trace = bytearray(_HEADER.pack(_MAGIC, _problem_digest(problem), len(records), result["goal_step"]))
    for step in records:
        rule = _RULES.index(step["rule"])
        refs = step["refs"]
        first = refs[0] if refs else _UNUSED
        second = refs[1] if len(refs) == 2 else _UNUSED
        # Congruence binds the function through its application endpoints.
        premise = step["data"] if step["rule"] == "hyp" else _UNUSED
        trace.extend(_RECORD.pack(rule, step["lhs"], step["rhs"], first, second, premise))
    return bytes(trace)


def decode_trace(problem: ref.Problem, trace: bytes) -> dict:
    """Reject malformed bytes and independently replay the decoded proof."""
    if len(trace) < _HEADER.size:
        raise ref.InvalidProblem("truncated trace header")
    magic, digest, count, goal = _HEADER.unpack_from(trace)
    if magic != _MAGIC:
        raise ref.InvalidProblem("unknown trace version")
    if not 1 <= count <= ref.MAX_RECORDS or len(trace) != _HEADER.size + count * _RECORD.size:
        raise ref.InvalidProblem("invalid trace length")
    if goal >= count:
        raise ref.InvalidProblem("invalid trace goal index")
    if digest != _problem_digest(problem):
        raise ref.InvalidProblem("trace belongs to a different problem")

    steps = []
    for offset in range(_HEADER.size, len(trace), _RECORD.size):
        opcode, lhs, rhs, first, second, premise = _RECORD.unpack_from(trace, offset)
        if opcode >= len(_RULES):
            raise ref.InvalidProblem("unknown trace opcode")
        rule = _RULES[opcode]
        arity = _ARITIES[opcode]
        refs = (first, second)
        if any(value != _UNUSED for value in refs[arity:]) or (rule != "hyp" and premise != _UNUSED):
            raise ref.InvalidProblem("noncanonical trace padding")
        data = None
        if rule == "hyp":
            data = premise
        elif rule == "congr" and lhs < len(problem.terms):
            data = problem.terms[lhs].name
        steps.append(ref.Step(lhs, rhs, rule, refs[:arity], data).json())

    result = {"status": "derived", "steps": steps, "goal_step": goal}
    ref.replay(problem, result)
    return result
