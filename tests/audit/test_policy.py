from pathlib import Path

import pytest

from claim_governance.policy import PolicyError, load_policy, policy_from_mapping
from tests.audit.conftest import BASE_STATUS, make_policy


def test_minimal_policy_loads_with_defaults():
    policy = make_policy()
    assert policy.repository == "example/repo"
    assert policy.ledger == () and policy.numerics == ()
    assert policy.status.classes_in("**Repository-proved** and [OPEN]") == {"proved", "open"}


def test_status_labels_match_on_word_boundaries_and_case_by_default():
    policy = make_policy()
    assert policy.status.classes_in("unproved OPENING reopened") == frozenset()
    assert policy.status.classes_in("status: OPEN.") == {"open"}
    assert policy.status.classes_in("status: open.") == frozenset()
    folded = make_policy(status={**BASE_STATUS, "ignore_case": True})
    assert folded.status.classes_in("status: open.") == {"open"}
    with pytest.raises(PolicyError, match="ignore_case"):
        make_policy(status={**BASE_STATUS, "ignore_case": "yes"})


@pytest.mark.parametrize(
    "overrides, message",
    [
        ({"repository": {}}, "requires 'name'"),
        ({"status": {"classes": ["open"], "synonyms": {"X": "proved"}}}, "undeclared classes"),
        ({"claim": [{"name": "G1", "status": "mythical"}]}, "undeclared status class"),
        ({"claim": [{"name": "G1", "status": "open"}, {"name": "G1", "status": "open"}]}, "duplicate claim names"),
        ({"numerics": {"rule": [{"name": "bad", "pattern": "(", "paths": ["src/*.py"]}]}}, "invalid pattern"),
        ({"promotion": {"settled_classes": ["nope"]}}, "undeclared classes"),
        ({"scan": {"prose": "docs/*.md"}}, "list of strings"),
        ({"claims": {"window_lines": -1}}, "non-negative integer"),
    ],
)
def test_policy_errors_fail_closed(overrides, message):
    with pytest.raises(PolicyError, match=message):
        make_policy(**overrides)


def test_load_policy_from_toml(tmp_path: Path):
    (tmp_path / "claim_governance.toml").write_text(
        '[repository]\nname = "x/y"\n[status]\nclasses = ["open"]\n[status.synonyms]\n"OPEN" = "open"\n'
        '[[claim]]\nname = "G1"\nstatus = "open"\naliases = ["finite BPA"]\n[[claim.surfaces]]\npath = "docs/a.md"\n',
        encoding="utf-8",
    )
    policy = load_policy(tmp_path / "claim_governance.toml")
    assert policy.ledger[0].names == ("G1", "finite BPA")
    assert policy.ledger[0].surfaces[0].window_lines == 3


def test_load_policy_reports_missing_or_invalid_file(tmp_path: Path):
    with pytest.raises(PolicyError):
        load_policy(tmp_path / "absent.toml")
    (tmp_path / "bad.toml").write_text("= nonsense", encoding="utf-8")
    with pytest.raises(PolicyError):
        load_policy(tmp_path / "bad.toml")


def test_policy_is_immutable():
    policy = policy_from_mapping({"repository": {"name": "x"}, "status": BASE_STATUS})
    with pytest.raises(Exception):
        policy.repository = "y"  # type: ignore[misc]
    with pytest.raises(TypeError):
        policy.status.synonyms["new"] = "open"  # type: ignore[index]
