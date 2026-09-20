"""This repository against its own policy file.

`audit/claim_governance` is the engine every consumer runs, and until this
file existed the publisher was the one tree nobody pointed it at. Two things
are checked: that the repository passes, and that the rules it ships would
notice if it stopped -- a policy whose patterns match nothing is a green
light that means nothing.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from claim_governance.policy import load_policy
from claim_governance.runner import CHECKS, run
from tests.audit.conftest import write_tree

ROOT = Path(__file__).resolve().parents[2]
POLICY = ROOT / "claim_governance.toml"


@pytest.fixture(scope="module")
def policy():
    return load_policy(POLICY)


def test_the_repository_passes_its_own_policy(policy):
    findings = run(policy, ROOT)
    assert not findings, "\n".join(f.render() for f in findings)


def test_the_policy_covers_every_check_it_means_to(policy):
    assert policy.repository == "larsbx/finite-math-kernels"
    assert {rule.name for rule in policy.numerics} == {
        "no-transcendental", "no-floating-point", "rank2-loci",
    }


def test_the_shipped_rules_bite(policy, tmp_path):
    """The repository's own patterns, against a tree that breaks each one."""
    root = write_tree(tmp_path, {
        "finite_exact/bad.mojo": "var x = sqrt(2)\nvar y: Float64 = 1.5\nvar ok = Q(1, 2)\n",
        "docs/bad.md": "Read off the polar angle of the record.\n",
        "README.md": "The map is essentially the same as the classical one.\n",
        "docs/unlabelled.md": "## Theorem 1\n\nEvery box is decided.\n",
    })
    reported = {(f.path, f.rule) for f in run(policy, root)}
    assert ("finite_exact/bad.mojo", "no-transcendental") in reported
    assert ("finite_exact/bad.mojo", "no-floating-point") in reported
    assert ("docs/bad.md", "rank2-loci") in reported
    assert ("README.md", "essentially the same") in reported
    assert ("docs/unlabelled.md", "Theorem") in reported


def test_a_document_that_declares_its_status_needs_no_per_statement_label(policy, tmp_path):
    """Every specification here opens with a `Status:` line, which is why the
    check reports nothing on this repository today."""
    root = write_tree(tmp_path, {
        "docs/spec.md": "# Spec\n\nStatus: specification of a package.\n\n## Theorem 1\n\nEvery box is decided.\n",
    })
    assert not run(policy, root, ["claims"])


def test_the_projective_citation_is_not_a_violation(policy, tmp_path):
    """README.md names the circular points, which is the field term for the
    two ideal elements; the rule bans the constructions, not the citation."""
    root = write_tree(tmp_path, {
        "docs/p.md": "the ideal line carrying the circular points; the quadrance form degenerates there\n",
    })
    assert not run(policy, root, ["numerics"])


def test_prose_that_forbids_a_locus_is_not_a_violation(policy, tmp_path):
    root = write_tree(tmp_path, {"docs/p.md": "The finite core has no unit circle.\n"})
    assert not run(policy, root, ["numerics"])


def test_every_check_the_engine_offers_is_reachable(policy):
    """A policy error must fail the audit rather than audit nothing, so the
    named checks have to be ones the runner knows."""
    assert set(CHECKS) >= {"numerics", "terminology", "claims"}
