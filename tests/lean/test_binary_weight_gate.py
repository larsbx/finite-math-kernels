"""Regression for exact source identity despite misleading Git index flags."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("binary_weight_gate", ROOT / "tools/verify_binary_weight.py")
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)


class SourceIdentity(unittest.TestCase):
    def test_assume_unchanged_cannot_hide_changed_proof(self):
        with tempfile.TemporaryDirectory(prefix="binary-weight-identity-") as temporary:
            root = Path(temporary)

            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True).strip()

            git("init", "--quiet")
            source = root / "Proof.lean"
            source.write_text("theorem checked : True := True.intro\n")
            git("add", "Proof.lean")
            git("-c", "user.name=Source Identity Test", "-c", "user.email=identity@example.invalid",
                "commit", "--quiet", "-m", "Create source identity fixture")
            expected = git("rev-parse", "HEAD")
            gate.require_source_matches_commit(expected, root=root, paths=["Proof.lean"])
            git("update-index", "--assume-unchanged", "Proof.lean")
            source.write_text("axiom injected : False\n")
            self.assertEqual(git("status", "--porcelain"), "")
            with self.assertRaisesRegex(RuntimeError, "source content differs from expected commit"):
                gate.require_source_matches_commit(expected, root=root, paths=["Proof.lean"])


if __name__ == "__main__":
    unittest.main()
