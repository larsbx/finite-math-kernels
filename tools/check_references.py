#!/usr/bin/env python3
"""Check that the path and task references in this repository resolve.

The engine is the vendorable `references` package; this file is the policy:
which paths this repository skips, and which references live in another
repository and are attested rather than resolved.

Usage: check_references.py            exit 1 on any unresolved reference
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from references.check_references import Policy, run  # noqa: E402

#: Dated audit records quote past states verbatim, and the reference tests
#: contain synthetic references by construction; both are read as history.
SKIPPED_PREFIXES = ("audit/POST_CONSOLIDATION_AUDIT_", "tests/references/")

# The finite-regime Mandelbrot program moved from larsbx/NLAP-JT to this
# repository on 2026-09-16; NLAP-JT is historical and receives no new work,
# so every row below names the live home of the file it attests. The Mandelbrot
# repository was renamed on 2026-09-17, from the transposed spelling it had
# carried since creation to the correct one; the old name redirects.
NLAP = "larsbx/finite-mandelbrot-research (formerly larsbx/finite-mandlebrot-research, and before that larsbx/NLAP-JT)"
PSC = "larsbx/pisot-substitution-conjecture-research"
EXTERNAL: dict[str, str] = {
    "docs/canonical-serialization.md": NLAP,
    "docs/library-extraction-candidates-2026-09-14.md": NLAP,
    "docs/finite-proof-records-spec.md": NLAP,
    "src/mojo_theorem_kernel.mojo": NLAP,
    "src/interval_orbit.mojo": NLAP,
    "src/smoke_report.mojo": NLAP,
    "tools/check_vendored_sync.py": NLAP,
    # The manifest the vendoring checker reads lives in whichever repository
    # vendors these packages, never here: this monorepo is the upstream.
    "vendored.toml": "each consumer repository that vendors packages from this monorepo",
    "src/C1_theorem_tag_import_ledger.mojo": NLAP,
    "src/C1_theorem_tag_assumption_payloads.mojo": NLAP,
    "src/C1_final_proof_block_ledger.mojo": NLAP,
    "tools/audit_exact_arithmetic.py": NLAP,
    "docs/C1_theorem_tag_import_ledger.md": NLAP,
    "src/checked_ray_address.mojo": NLAP,
    "docs/C1_residual_directive_carrier.md": NLAP,
    "docs/cross-pollination-round-two-2026-09-16.md": f"{NLAP} and {PSC}",
    "docs/cross-pollination-round-three-2026-09-17.md": PSC,
    "docs/release-provenance.md": "larsbx/sprucegoose at the commit named in docs/evidence-vocabulary-map.md",
    "tdd_ledger.zig": "larsbx/crypto-composer at the commit named in docs/evidence-vocabulary-map.md",
    "test/harness.zig": "larsbx/crypto-composer at the commit named in docs/evidence-vocabulary-map.md",
    "docs/exact-arithmetic-binding.md": PSC,
    "docs/overlap-finiteness-and-coincidence-density-2026-09-13.md": PSC,
    "src/psc_research/bpa.py": PSC,
    "mojo/psc/finite_cokernel_address.mojo": PSC,
    "docs/padic-representation-literature-gate-2026-09-16.md": PSC,
    "tests/test_substitution_dynamics_oracle.py": PSC,
    "docs/ledger-index.md": "the consumer repository (docs/ledger-generation-spec.md, section 3.4)",
    "interval_q/closed_q.mojo": "larsbx/interval_q at the commit pinned in audit/provenance.json",
}

POLICY = Policy(external=EXTERNAL, skipped_prefixes=SKIPPED_PREFIXES)


if __name__ == "__main__":
    sys.exit(run(ROOT, POLICY))
