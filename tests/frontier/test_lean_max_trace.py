"""Golden wire encoding and independent replay of adversarial trace mutations."""
from dataclasses import replace
from hashlib import sha256
import json
from pathlib import Path
import struct
import sys
import unittest

BASE = Path(__file__).resolve().parents[2] / "experiments/frontier/lean_max"
sys.path.insert(0, str(BASE))

import reference as ref
from trace_codec import decode_trace, encode_trace


class TestTrace(unittest.TestCase):
    def setUp(self):
        self.problem = ref.Problem.parse(json.loads((BASE / "demo.json").read_text()))
        self.result = ref.construct(self.problem)
        self.trace = encode_trace(self.problem, self.result)

    def test_demo_is_stable(self):
        self.assertEqual(sha256(self.trace).hexdigest(), "91251e163c26a5963a78be36471b3028f63a70cf935044b0d617916f2508ebf6")
        decoded = decode_trace(self.problem, self.trace)
        self.assertEqual(decoded, self.result)
        self.assertEqual(encode_trace(self.problem, decoded), self.trace)
        self.assertEqual(ref.lean_source(self.problem, decoded), (BASE / "Demo.lean").read_text())

    def test_round_trip_reflexivity_and_symmetry(self):
        for goal in [(0, 0), (1, 0)]:
            with self.subTest(goal=goal):
                problem = replace(self.problem, goal=goal)
                result = ref.construct(problem)
                self.assertEqual(decode_trace(problem, encode_trace(problem, result)), result)

    def test_encoding_rejects_inconclusive_result(self):
        result = ref.construct(self.problem, max_rounds=0)
        with self.assertRaisesRegex(ref.InvalidProblem, "only derived"):
            encode_trace(self.problem, result)

    def test_wrong_problem_is_rejected_even_when_proof_still_replays(self):
        problem = replace(self.problem, atoms=(*self.problem.atoms, "unused"))
        ref.replay(problem, self.result)
        with self.assertRaisesRegex(ref.InvalidProblem, "different problem"):
            decode_trace(problem, self.trace)

    def test_bad_envelopes_and_steps(self):
        def write_u16(offset, value):
            trace = bytearray(self.trace)
            struct.pack_into("<H", trace, offset, value)
            return bytes(trace)

        def record(step, field, value):
            return write_u16(44 + 12 * step + 2 * field, value)

        cases = [
            (self.trace[:43], "truncated"),
            (self.trace[:7] + b"\x02" + self.trace[8:], "version"),
            (self.trace[:-1], "length"),
            (self.trace + b"\x00", "length"),
            (write_u16(40, ref.MAX_RECORDS + 1), "length"),
            (write_u16(42, 4), "goal index"),
            (write_u16(42, 2), "does not establish goal"),
            (record(0, 0, 99), "opcode"),
            (record(0, 3, 0), "padding"),
            (record(0, 5, 1), "unbound hypothesis"),
            (record(3, 1, 128), "endpoint"),
            (record(3, 3, 3), "future"),
            (record(3, 1, 4), "children mismatch"),
            (record(2, 3, 1), "chain mismatch"),
        ]
        for trace, error in cases:
            with self.subTest(error=error):
                with self.assertRaisesRegex(ref.InvalidProblem, error):
                    decode_trace(self.problem, trace)


if __name__ == "__main__":
    unittest.main()
