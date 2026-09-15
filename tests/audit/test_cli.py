from pathlib import Path

import pytest

from claim_governance import cli
from claim_governance.runner import CHECKS, run
from tests.audit.conftest import make_policy, write_tree

POLICY = """
[repository]
name = "example/repo"

[scan]
prose = ["docs/**/*.md"]

[status]
classes = ["proved", "open"]
[status.synonyms]
"[PROVED]" = "proved"
"[OPEN]" = "open"

[claims]
paths = ["docs/**/*.md"]
statement_kinds = ["Theorem"]
window_lines = 1

[[claim]]
name = "G1"
status = "open"
[[claim.surfaces]]
path = "docs/a.md"
window_lines = 0

[[numerics.rule]]
name = "no-trig"
pattern = "\\\\bsin\\\\b"
paths = ["src/*.py"]
"""


def repo(tmp_path: Path, doc: str) -> Path:
    return write_tree(tmp_path, {"claim_governance.toml": POLICY, "docs/a.md": doc, "src/k.py": "y = sin(x)\n"})


def test_cli_passes_on_clean_repository(tmp_path, capsys):
    root = repo(tmp_path, "## Theorem 1\n[PROVED]\n\nG1 [OPEN]\n")
    (root / "src" / "k.py").write_text("y = x\n", encoding="utf-8")
    assert cli.main(["--root", str(root)]) == 0
    assert "OK: claim governance audit of example/repo passed" in capsys.readouterr().out


def test_cli_reports_findings_and_selects_checks(tmp_path, capsys):
    root = repo(tmp_path, "## Theorem 1\n\nG1 [PROVED]\n")
    assert cli.main(["--root", str(root)]) == 1
    out = capsys.readouterr().out
    assert "docs/a.md:1: [claims/Theorem]" in out
    assert "docs/a.md:3: [consistency/G1]" in out
    assert "src/k.py:1: [numerics/no-trig]" in out
    assert "3 finding(s)" in out
    assert cli.main(["--root", str(root), "--check", "numerics"]) == 1
    assert "1 finding(s) [numerics]" in capsys.readouterr().out


def test_cli_policy_error_exit_code(tmp_path, capsys):
    (tmp_path / "claim_governance.toml").write_text("[repository]\n", encoding="utf-8")
    assert cli.main(["--root", str(tmp_path)]) == 2
    assert "policy error" in capsys.readouterr().err


def test_cli_malformed_numerics_rule_exits_two(tmp_path, capsys):
    (tmp_path / "claim_governance.toml").write_text(
        '[repository]\nname = "example/repo"\n[numerics]\nrule = "bad"\n',
        encoding="utf-8",
    )
    assert cli.main(["--root", str(tmp_path)]) == 2
    assert "numerics.rule must be a list of tables" in capsys.readouterr().err


def test_cli_lists_checks(capsys):
    assert cli.main(["--list-checks"]) == 0
    assert capsys.readouterr().out.split() == list(CHECKS)


def test_run_rejects_unknown_check(tmp_path):
    with pytest.raises(KeyError):
        run(make_policy(), tmp_path, ["nope"])
