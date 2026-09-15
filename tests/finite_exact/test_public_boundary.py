"""Wiring of the public boundary: documents, smoke target, probe, CI."""

from __future__ import annotations

import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_boundary_document_declares_names_semantics_and_promise():
    doc = text("docs/exact-arithmetic-public-boundary.md")
    for section in ["## 1. Public names", "## 2. Semantics that consumers may rely on",
                    "## 3. Semantics that consumers must not rely on", "## 4. Verification of the boundary",
                    "## 5. Stability promise"]:
        assert section in doc
    for name in ["`bigz_divmod`", "`q_canonical_bytes`", "`Q.from_int`", "`bigz_gcd`"]:
        assert name in doc
    assert "enables no certificate acceptance" in doc


def test_long_division_replaces_shift_and_subtract_and_keeps_the_reference():
    z = text("finite_exact/bigint_z.mojo")
    assert "def bigz_abs_divmod_shift_subtract(" in z
    assert "def bigz_abs_divmod(" in z
    assert "Knuth Algorithm D" in z
    assert "def bigz_long_division_smoke(" in z
    assert "if not bigz_long_division_smoke():" in text("tests/finite_exact/test_finite_exact.mojo")


def test_rational_operations_cancel_before_multiplying():
    q = text("finite_exact/rat_q.mojo")
    assert "def q_cross_terms(" in q
    assert "var g1 = bigz_gcd(self.num, other.den)" in q
    assert "var g2 = bigz_gcd(other.num, self.den)" in q
    assert "def q_cancellation_smoke(" in q
    assert "q_cancellation_smoke()" in text("tests/finite_exact/test_finite_exact.mojo")
    assert "bigz_lt(bigz_mul(self.num, other.den), bigz_mul(other.num, self.den))" not in q


def test_package_is_self_contained_and_never_raises_or_aborts():
    for name in ["bigint_z", "rat_q"]:
        body = text(f"finite_exact/{name}.mojo")
        assert "raise " not in body and "abort(" not in body
        for line in body.splitlines():
            if line.startswith("from ") or line.startswith("import "):
                assert line.startswith("from finite_exact."), line
    assert "from finite_exact.bigint_z import" in text("finite_exact/rat_q.mojo")


def test_probe_and_smoke_are_wired_into_pixi_and_ci():
    manifest = tomllib.loads(text("pixi.toml"))
    assert manifest["tasks"]["property"] == "python tools/property_oracle.py --layers zq"
    assert manifest["tasks"]["test-finite-exact"] == "mojo run -I . tests/finite_exact/test_finite_exact.mojo"
    workflow = text(".github/workflows/ci.yml")
    for task in ["pixi run test"]:
        assert task in workflow
    probe = text("tests/finite_exact/property_probe.mojo")
    assert "from finite_exact.bigint_z import" in probe and "from finite_exact.rat_q import" in probe
    assert "interval_q" not in probe.split("\n\n", 1)[1].replace("interval_q probe", "")
    assert "PROBE_Z_CASES, PROBE_Q_CASES, 0)" in probe


def test_spec_and_encoding_documents_are_present():
    spec = text("docs/rational-interval-arithmetic-spec.md")
    for section in ["## 0. The problem being solved", "## 1. Layer ℚ: eliminate rounding",
                    "## 2. Layer I: keep rounding, bound it", "## 5. Conformance criteria",
                    "## 6. Consumers and binding tables", "## 7. Hook: how a consumer enforces the specification"]:
        assert section in spec
    encoding = text("docs/canonical-encoding.md")
    assert "-1000000001 -> 02 0000000000000004 3b9aca01" in encoding
    assert "minimal big-endian magnitude" in encoding
