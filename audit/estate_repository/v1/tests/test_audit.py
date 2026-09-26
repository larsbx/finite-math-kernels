from __future__ import annotations

import importlib.util
import tempfile
import textwrap
import unittest
from pathlib import Path

AUDIT_PATH = Path(__file__).resolve().parents[1] / "audit_estate_layout.py"


def load_audit():
    spec = importlib.util.spec_from_file_location("estate_v1_audit", AUDIT_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def manifest(extra: str = "") -> str:
    return textwrap.dedent(
        f"""
        version = 1
        template = "estate-repository-v1"

        [repository]
        id = "example/repo"
        kind = "research"
        lifecycle = "active"
        default_branch = "main"
        layout_status = "transitional"

        [principles]
        ordering = ["authority", "domain", "language"]
        empty_silos = "forbidden"
        cross_language_disagreement = "fail_closed"
        generated_surfaces = "derived_only"
        vendor_code = "non_local"
        experimental_code = "non_authoritative"

        [[plane]]
        id = "policy"
        target = "policy"
        authority = "governance"
        required = true
        current = ["policy.toml"]

        [[plane]]
        id = "kernel"
        target = "kernel"
        authority = "canonical_executable"
        required = true
        current = ["kernel"]

        [[language]]
        name = "Lean"
        authority = "canonical"
        roles = ["kernel", "proof_acceptance"]
        acceptance_authority = true

        [[language]]
        name = "Python"
        authority = "supporting"
        roles = ["tooling"]
        acceptance_authority = false

        [migration]
        mode = "boundary_first"
        mass_move = false
        next = []

        {extra}
        """
    ).strip() + "\n"


class EstateAuditTests(unittest.TestCase):
    def make_repo(self, manifest_text: str | None = None) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "ARCHITECTURE.md").write_text("# Architecture\n", encoding="utf-8")
        (root / "policy.toml").write_text("version = 1\n", encoding="utf-8")
        (root / "kernel").mkdir()
        (root / "estate.toml").write_text(
            manifest_text if manifest_text is not None else manifest(),
            encoding="utf-8",
        )
        return root

    def test_minimal_consumer_passes_without_contract_copy(self):
        audit = load_audit()
        root = self.make_repo()
        audit.audit(root)
        self.assertFalse((root / "docs/architecture/estate-repository-template-v1.md").exists())

    def test_supporting_language_cannot_claim_acceptance_authority(self):
        audit = load_audit()
        bad = manifest().replace(
            'name = "Python"\nauthority = "supporting"\nroles = ["tooling"]\nacceptance_authority = false',
            'name = "Python"\nauthority = "supporting"\nroles = ["tooling"]\nacceptance_authority = true',
        )
        root = self.make_repo(bad)
        with self.assertRaisesRegex(AssertionError, "supporting language cannot have acceptance authority"):
            audit.audit(root)

    def test_missing_required_mapping_fails_closed(self):
        audit = load_audit()
        root = self.make_repo()
        (root / "policy.toml").unlink()
        with self.assertRaisesRegex(AssertionError, "missing current path policy.toml"):
            audit.audit(root)

    def test_duplicate_plane_target_is_rejected(self):
        audit = load_audit()
        bad = manifest().replace('target = "kernel"', 'target = "policy"', 1)
        root = self.make_repo(bad)
        with self.assertRaisesRegex(AssertionError, "duplicate plane target"):
            audit.audit(root)

    def test_shared_tooling_pin_must_match_executing_action(self):
        audit = load_audit()
        revision = "0123456789abcdef0123456789abcdef01234567"
        pinned = manifest(
            f"""
            [estate_tooling]
            repository = "larsbx/finite-math-kernels"
            path = "audit/estate_repository/v1"
            revision = "{revision}"
            """
        )
        root = self.make_repo(pinned)
        audit.audit(
            root,
            tooling_repository="larsbx/finite-math-kernels",
            tooling_path="audit/estate_repository/v1",
            tooling_revision=revision,
        )

    def test_shared_tooling_pin_rejects_revision_drift(self):
        audit = load_audit()
        declared = "0123456789abcdef0123456789abcdef01234567"
        executing = "89abcdef0123456789abcdef0123456789abcdef"
        pinned = manifest(
            f"""
            [estate_tooling]
            repository = "larsbx/finite-math-kernels"
            path = "audit/estate_repository/v1"
            revision = "{declared}"
            """
        )
        root = self.make_repo(pinned)
        with self.assertRaisesRegex(AssertionError, "revision disagrees"):
            audit.audit(
                root,
                tooling_repository="larsbx/finite-math-kernels",
                tooling_path="audit/estate_repository/v1",
                tooling_revision=executing,
            )

    def test_shared_tooling_pin_must_be_immutable_sha(self):
        audit = load_audit()
        pinned = manifest(
            """
            [estate_tooling]
            repository = "larsbx/finite-math-kernels"
            path = "audit/estate_repository/v1"
            revision = "main"
            """
        )
        root = self.make_repo(pinned)
        with self.assertRaisesRegex(AssertionError, "immutable 40-hex"):
            audit.audit(root)

    def test_pixi_identity_must_match_repository(self):
        audit = load_audit()
        root = self.make_repo()
        (root / "pixi.toml").write_text('[workspace]\nname = "wrong"\n', encoding="utf-8")
        with self.assertRaisesRegex(AssertionError, "pixi workspace identity disagrees"):
            audit.audit(root)


if __name__ == "__main__":
    unittest.main()
