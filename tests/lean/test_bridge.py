import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("bridge", ROOT / "tools/kernel_lean_conformance.py")
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class AdmissionControls(unittest.TestCase):
    def test_complete_workload_count(self):
        self.assertEqual(len(bridge.workloads()), 373)

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

    def test_noncanonical_field_output_refuses(self):
        with self.assertRaisesRegex(ValueError, "noncanonical"):
            bridge.proposition(dict(kind="field", p=7, a=0, b=1, op=0, reject=False,
                                    output=8, refusal_eq=False))

    def test_coverage_inventory_is_current_and_complete(self):
        spec = importlib.util.spec_from_file_location("inventory", ROOT / "tools/kernel_lean_inventory.py")
        inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(inventory)
        actual = json.loads((ROOT / "tests/lean/coverage.json").read_text())
        self.assertEqual(actual, inventory.inventory())
        paths = {r["source"] for r in actual["modules"]}
        self.assertEqual(paths, {p.relative_to(ROOT).as_posix() for p in (ROOT / "kernel").rglob("*.mojo")})
        self.assertTrue(all(r["implementation_refinement"] == "open" for r in actual["modules"]))


if __name__ == "__main__":
    unittest.main()
