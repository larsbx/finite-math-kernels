"""The polyglot boundary envelope is one template, rendered per repository.

Every repository's copy of the envelope schema and its conformance vectors is
the template with three facts substituted: the owner, the repository and the
boundary it guards. This repository's own `schemas/` and `conformance/` files
are one such rendering; each consumer's `.polyglot/` is another.
"""

from __future__ import annotations

import json
import tomllib
from pathlib import Path

import pytest

from boundary_envelope import refusal
from polyglot_envelope import render as envelope

ROOT = Path(__file__).resolve().parents[2]
HERE = {"owner": "larsbx", "repo": "finite-math-kernels", "boundary": "shared-finite-kernel"}
INSTANCE = {
    "boundary-envelope-v1.schema.json": "schemas/polyglot-boundary-envelope-v1.json",
    "conformance-v1.json": "conformance/polyglot_boundary_envelope_v1.json",
}
JULIA = {"owner": "larsbx", "repo": "finite-julia-set-research", "boundary": "finite-julia-certificate"}

MANIFEST = """\
version = 1
repository = "larsbx/finite-julia-set-research"
boundary_id = "finite-julia-certificate"
"""


def test_this_repository_is_a_rendering_of_the_template():
    rendered = envelope.render(HERE)
    assert set(rendered) == set(INSTANCE)
    for name, path in INSTANCE.items():
        assert rendered[name] == (ROOT / path).read_text(encoding="utf-8"), path


def test_only_the_three_facts_are_substituted():
    schema = json.loads(envelope.render(JULIA)["boundary-envelope-v1.schema.json"])
    assert schema["$id"] == "urn:larsbx:finite-julia-set-research:polyglot-boundary-envelope:v1"
    assert schema["title"] == "finite-julia-set-research polyglot boundary envelope v1"
    assert schema["properties"]["boundary"]["const"] == "finite-julia-certificate"
    here = json.loads(envelope.render(HERE)["boundary-envelope-v1.schema.json"])
    for key in ("$id", "title"):
        del schema[key], here[key]
    del schema["properties"]["boundary"], here["properties"]["boundary"]
    assert schema == here


@pytest.mark.parametrize("facts", [HERE, JULIA,
                                   {"owner": "larsbx", "repo": "pisot-substitution-conjecture-research",
                                    "boundary": "psc-bpa-census"}])
def test_every_rendering_keeps_its_verdicts(facts):
    """A rendered vector set is accepted and refused exactly as declared, by the reference validator."""
    rendered = envelope.render(facts)
    schema = json.loads(rendered["boundary-envelope-v1.schema.json"])
    vectors = json.loads(rendered["conformance-v1.json"])
    assert vectors["boundary"] == schema["properties"]["boundary"]["const"] == facts["boundary"]
    assert all(refusal(schema, case["value"]) is None for case in vectors["accepted"])
    assert all(refusal(schema, case["value"]) is not None for case in vectors["rejected"])


@pytest.mark.parametrize("field, value", [
    ("boundary", ""), ("boundary", "Upper"), ("boundary", 'quote"d'), ("boundary", "a/b"),
    ("boundary", "-leading"), ("boundary", "different-boundary"), ("repo", "{{boundary}}"),
    ("owner", "x y"), ("repo", 7),
])
def test_unsafe_facts_are_refused(field, value):
    """A fact must be a plain lowercase slug; and the wrong-boundary vector's own value is not a boundary."""
    with pytest.raises(ValueError):
        envelope.render({**JULIA, field: value})


@pytest.mark.parametrize("facts", [{"owner": "larsbx", "repo": "r"}, {**JULIA, "extra": "x"}])
def test_facts_are_exactly_the_three(facts):
    with pytest.raises(ValueError):
        envelope.render(facts)


def test_templates_name_only_known_placeholders():
    for text in envelope.templates().values():
        assert set(envelope.PLACEHOLDER.findall(text)) <= set(envelope.FACTS)


def test_facts_come_from_the_polyglot_manifest():
    assert envelope.facts(tomllib.loads(MANIFEST)) == JULIA


@pytest.mark.parametrize("manifest", [{"repository": "no-owner", "boundary_id": "b"},
                                      {"repository": "a/b/c", "boundary_id": "b"},
                                      {"repository": "a/b"}])
def test_a_malformed_manifest_is_refused(manifest):
    with pytest.raises(ValueError):
        envelope.facts(manifest)


def consumer(tmp_path: Path) -> Path:
    (tmp_path / envelope.MANIFEST).write_text(MANIFEST, encoding="utf-8")
    return tmp_path


def test_write_then_check(tmp_path):
    root = consumer(tmp_path)
    assert envelope.drift(root) == [f"{envelope.OUT}/{name} missing" for name in sorted(INSTANCE)]
    envelope.write(root)
    assert envelope.drift(root) == []
    assert envelope.main(["--root", str(root), "--check"]) == 0


def test_a_hand_edit_is_drift(tmp_path):
    root = consumer(tmp_path)
    envelope.write(root)
    path = root / envelope.OUT / "conformance-v1.json"
    path.write_text(path.read_text(encoding="utf-8").replace("fixture-0001", "fixture-0002"), encoding="utf-8")
    assert envelope.drift(root) == [f"{envelope.OUT}/conformance-v1.json differs from its rendering"]
    assert envelope.main(["--root", str(root), "--check"]) == 1


def test_main_writes(tmp_path):
    root = consumer(tmp_path)
    assert envelope.main(["--root", str(root)]) == 0
    assert envelope.drift(root) == []


def test_no_manifest_fails_closed(tmp_path):
    assert envelope.main(["--root", str(tmp_path), "--check"]) == 1
