#!/usr/bin/env python3
"""Complete kernel module inventory; a source binding grants no proof status."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "tests/lean/coverage.json"
MODELS = {
    "finite_exact/checked_int.mojo": ["CheckedInt.accept_exact", "CheckedInt.add_guard_exact", "CheckedInt.sub_guard_exact", "CheckedInt.neg_guard_exact", "CheckedInt.abs_guard_exact", "CheckedInt.magnitude_guard_exact"],
    "finite_exact/fp.mojo": ["AcceptedField.prime_field_inverse", "AcceptedField.rejection_compares_false"],
    "finite_exact/rat_q.mojo": ["AcceptedField.rational_inverse", "AcceptedField.rejection_compares_false"],
    "finite_exact/field.mojo": ["AcceptedField.inverse_sound", "AcceptedField.division_cancel"],
    "substitution_dynamics/words.mojo": ["Words.stream_correct", "Words.balanced_iff_perm", "Words.triples_replicate_self", "CounterBounds.stress_model_count", "CounterBounds.stress_count_does_not_fit", "CounterBounds.last_constant_count_fits", "CounterBounds.next_constant_count_refused", "CounterBounds.n2_constant_boundary", "MachineWords.stream_success_exact", "MachineWords.run_complete_iff", "MachineWords.run_refuses_iff", "MachineWords.difference_fits"],
    "substitution_dynamics/substitution.mojo": ["Words.parikh_inflate", "Words.balanced_iterate"],
    "substitution_dynamics/balanced_pairs.mojo": ["Words.balanced_image_length", "Words.witness_inflate"],
    "substitution_dynamics/strong_coincidence.mojo": ["Words.witness_inflate", "Words.witness_iterate"],
}
NATIVE = {"finite_exact/checked_int.mojo", "finite_exact/fp.mojo",
          "substitution_dynamics/words.mojo", "substitution_dynamics/substitution.mojo",
          "substitution_dynamics/balanced_pairs.mojo"}
OBLIGATIONS = {
    "finite_exact": ["BigZ limb denotation, carry/borrow, canonicality and division convention",
                     "Q normalisation, gcd/cross-cancellation and rejected carrier refinement",
                     "closed interval/box enclosure and singular guards",
                     "machine arithmetic intermediate bounds and signed/unsigned multiplication binding",
                     "Fp primality checker, modular reduction and Euclidean inverse loop"],
    "substitution_dynamics": ["array/list representation and valid alphabet indices",
                              "every machine Int count and intermediate must fit",
                              "decomposition completeness and minimal balanced cuts",
                              "bounded automaton refusal and sound search witnesses",
                              "address, symmetry, endpoint, tuning and return-lattice algorithms"],
    "finite_linear_algebra": ["matrix/vector dimensions, exact operations and overflow refusal", "elimination, rank and normal-form certificates", "Sturm and M-adic hypotheses and enclosures"],
    "finite_polynomial": ["coefficient normalisation and polynomial operations", "irreducibility, modular arithmetic and lifting hypotheses", "cyclotomic, jet and Taylor enclosure refinement"],
    "finite_graph": ["SCC partition, reachability and maximality", "union-find partition refinement", "signing and period/cyclic-class witnesses"],
    "finite_automata": ["language semantics, total transition validation", "subset construction and Boolean operations", "minimisation equivalence, counting and resource refusals"],
    "proof_records": ["canonical encoding and identity binding", "typed dependency closure and promotion boundary"],
    "certified_records": ["parser totality, canonicality and malformed/mismatch distinctions"],
    "parallel_fold": ["order-preserving associativity assumptions, MAX execution parity and resource refusals"],
    "mojo_smoke": ["receipt emission follows guarded assertions; no mathematical proof authority"],
}


def inventory():
    entries = []
    for p in sorted((ROOT / "kernel").rglob("*.mojo")):
        path = p.relative_to(ROOT / "kernel").as_posix()
        package = path.split("/", 1)[0]
        entries.append({"source": "kernel/" + path,
                        "model_declarations": ["FiniteMathKernels." + n for n in MODELS.get(path, [])],
                        "finite_native_lane": path in NATIVE,
                        "implementation_refinement": "open",
                        "known_counterexample": "Historical 4fea04f: n3([0]^4000000,1) wrapped. The corrected bounded API raises; unbounded exactness is not claimed." if path == "substitution_dynamics/words.mojo" else None,
                        "remaining_obligations": OBLIGATIONS.get(package, ["package-specific semantic model, guards and source refinement; no coverage claimed"])})
    return {"format": "finite-math-kernels-lean-coverage-v1", "scope": "all canonical Mojo module files",
            "authority": "Inventory only. Acceptance requires an exact-revision successful Lean receipt; no implementation is declared fully verified.",
            "model_source": "tests/lean/FiniteMathKernels", "modules": entries}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(inventory(), indent=2) + "\n"
    if args.check:
        if not TARGET.exists() or TARGET.read_text() != rendered:
            raise SystemExit("Lean coverage inventory is stale")
    else:
        TARGET.write_text(rendered)
