#!/usr/bin/env python3
"""Check that the path and task references in this repository resolve.

The engine is the vendorable `references` package (`tools/references/`); this
file is the policy: which paths this repository skips, which include roots hold
package-relative paths, and which references live in another repository and
are attested rather than resolved. Dated audit records quote past states
verbatim, dated vendoring inventories name other repositories' paths
throughout, and the reference tests contain synthetic references by
construction; all three are skipped.

Usage: check_references.py            exit 1 on any unresolved reference
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from references.check_references import Policy, run  # noqa: E402

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
    # Likewise the facts `polyglot_envelope` renders from: this repository's
    # own rendering is checked by tests/polyglot instead.
    "polyglot.manifest.toml": "each consumer repository that vendors polyglot_envelope",
    "src/C1_theorem_tag_import_ledger.mojo": NLAP,
    "src/C1_theorem_tag_assumption_payloads.mojo": NLAP,
    "src/C1_final_proof_block_ledger.mojo": NLAP,
    "tools/audit_exact_arithmetic.py": NLAP,
    "docs/C1_theorem_tag_import_ledger.md": NLAP,
    "src/checked_ray_address.mojo": NLAP,
    "docs/C1_residual_directive_carrier.md": NLAP,
    "docs/literature/open-problems-survey-2026-10.md": NLAP,
    "kernel/mojo/dynamics/exact_type_irreducibility.mojo": NLAP,
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
    "claim_governance.toml": "the consumer repository root (docs/audit/policy-format.md)",
    "docs/ledger-index.md": "the consumer repository (docs/ledger-generation-spec.md, section 3.4)",
    "docs/enclosure-width-lemma.md": "larsbx/finite-julia-set-research, which supplies the step factor K of section 2.5",
    "docs/literature-gate-2026-10-06-algebraic-multiplier.md": "larsbx/finite-julia-set-research at efba3f2e0af31df4dc81169b6a83a5adc8aaaec6; finding 7 is a conditional route-D tail estimate for a proposed rotor-prefix consumer, not an implemented certificate",
    "docs/taylor-models.md": "larsbx/finite-julia-set-research, which built and measured the models of section 2.5",
    "docs/scaled-boxes.md": "larsbx/finite-julia-set-research, which implemented the E = F endpoints of section 2.1",
    "docs/tiling-connections-2026-09-20.md": "larsbx/finite-julia-set-research, whose item 2 asked for the general-size characteristic polynomial and the root isolation of docs/exact-polynomial-root-isolation-spec.md",
    "kernel/integer_vector_bench.mojo": PSC,
    "certificates/checked_krawczyk_witness.mojo": f"{NLAP}, under kernel/mojo; the checked-Int64 Krawczyk witness docs/root-isolation-spec.md section 8 leaves local",
    "reference/scaled.py": "larsbx/finite-julia-set-research; the separated-exponent boxes docs/root-isolation-spec.md section 8 leaves local",
    "certificates/krawczyk_witness.mojo": f"{NLAP}, under kernel/mojo; inventoried in docs/root-isolation-spec.md section 8",
    "kernel/bulbford/certify.py": "larsbx/mandelbrot-bulbs-and-ford-circles-research; inventoried in docs/root-isolation-spec.md section 8",
    "kernel/bulbford/antipode.py": "larsbx/mandelbrot-bulbs-and-ford-circles-research; inventoried in docs/root-isolation-spec.md section 8",
    "reference/preperiodic.py": "larsbx/finite-julia-set-research; inventoried in docs/root-isolation-spec.md section 8",
    "docs/literature-gate-2026-09-20-krawczyk.md": "larsbx/finite-julia-set-research, which gated KrawczykMooreUniqueness (docs/root-isolation-spec.md section 4)",
    "kernel/tests/test_census_library.mojo": PSC,
    "kernel/tests/test_endpoint_core.mojo": PSC,
    "kernel/tests/test_automata.mojo": PSC,
    "kernel/tests/test_barge_class.mojo": PSC,
    "kernel/tests/test_boundary_sync.mojo": PSC,
    "kernel/tests/test_return_lattice.mojo": PSC,
    "kernel/psc/coincidence_formula.mojo": PSC,
    "interval_q/closed_q.mojo": "larsbx/interval_q at the commit pinned in policy/provenance.json",
}

POLICY = Policy(
    external=EXTERNAL,
    skipped_prefixes=("docs/audit/POST_CONSOLIDATION_AUDIT_", "docs/vendoring-candidates-", "tests/references/"),
    package_roots=("kernel", "oracles", "tools"),
)


if __name__ == "__main__":
    sys.exit(run(ROOT, POLICY))
