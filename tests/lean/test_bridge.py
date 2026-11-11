import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("bridge", ROOT / "tools/kernel_lean_conformance.py")
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)
sys.path.insert(0, str(ROOT / "tools"))
from run_kernel_lean_verification import check_axiom_log


class AdmissionControls(unittest.TestCase):
    def test_complete_workload_count(self):
        self.assertEqual(len(bridge.workloads()), 494)
        self.assertEqual(sum(row["kind"] == "bigz" for row in bridge.workloads()), 121)

    def test_refuses_missing_case(self):
        with self.assertRaisesRegex(ValueError, "count"):
            bridge.generate("{}\n")

    def test_duplicate_keys_refuse(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            bridge.strict_json('{"kind":"word","kind":"integer"}')

    def test_boolean_is_not_an_integer_literal(self):
        with self.assertRaisesRegex(ValueError, "integer"):
            bridge.integer(True)

    def test_code_injection_cannot_be_a_vector(self):
        with self.assertRaisesRegex(ValueError, "integer"):
            bridge.vector(["0]; example : False := by"])

    def test_noncanonical_field_output_reaches_an_impossible_lean_bound(self):
        proposition = bridge.proposition(dict(kind="field", p=7, a=0, b=1, op=0, reject=False,
                                             output=8, refusal_eq=False))
        self.assertIn("(8 : ℕ) < 7", proposition)

    def test_noncanonical_bigz_output_reaches_lean_without_normalization(self):
        zero = dict(sign=0, limbs=[])
        record = dict(kind="bigz", a=zero, b=zero, sum=dict(sign=1, limbs=[0]),
                      difference=zero)
        self.assertIn("BigZLimbs.Canonical 1000000000 1 [0]", bridge.proposition(record))

    def test_bigz_schema_rejects_invalid_sign_and_nested_limb(self):
        for carrier in [dict(sign=True, limbs=[]), dict(sign=1, limbs=[[0]])]:
            with self.assertRaisesRegex(ValueError, "integer"):
                bridge.bigz_terms(carrier)

    def test_coverage_inventory_is_current_and_complete(self):
        spec = importlib.util.spec_from_file_location("inventory", ROOT / "tools/kernel_lean_inventory.py")
        inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(inventory)
        actual = json.loads((ROOT / "tests/lean/coverage.json").read_text())
        self.assertEqual(actual, inventory.inventory())
        paths = {r["source"] for r in actual["modules"]}
        self.assertEqual(paths, {p.relative_to(ROOT).as_posix() for p in (ROOT / "kernel").rglob("*.mojo")})
        self.assertTrue(all(r["implementation_refinement"] == "open" for r in actual["modules"]))

    def test_wrapped_standard_axioms_are_admitted(self):
        check_axiom_log("'N.p' depends on axioms: [propext,\n Classical.choice, Quot.sound]\n", ["N.p"])

    def test_wrapped_unapproved_axiom_refuses(self):
        with self.assertRaisesRegex(ValueError, "unapproved"):
            check_axiom_log("'N.p' depends on axioms: [propext,\n sorryAx]\n", ["N.p"])

    def test_truncated_axiom_block_refuses(self):
        with self.assertRaisesRegex(ValueError, "malformed"):
            check_axiom_log("'N.p' depends on axioms: [propext,\n", ["N.p"])


if __name__ == "__main__":
    unittest.main()
