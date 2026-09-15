"""``claim-governance``: audit a repository against its policy file."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from claim_governance.policy import PolicyError, load_policy
from claim_governance.runner import CHECKS, run


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="claim-governance", description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."), help="repository root (default: .)")
    parser.add_argument("--policy", type=Path, default=None, help="policy file (default: ROOT/claim_governance.toml)")
    parser.add_argument("--check", action="append", default=[], choices=sorted(CHECKS), help="run only this check (repeatable)")
    parser.add_argument("--list-checks", action="store_true", help="print the check names and exit")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.list_checks:
        print("\n".join(CHECKS))
        return 0
    root = args.root.resolve()
    try:
        policy = load_policy(args.policy or root / "claim_governance.toml")
    except PolicyError as exc:
        print(f"policy error: {exc}", file=sys.stderr)
        return 2
    findings = run(policy, root, args.check)
    for finding in findings:
        print(finding.render())
    checks = ", ".join(args.check or CHECKS)
    if findings:
        print(f"\nclaim governance audit of {policy.repository} failed: {len(findings)} finding(s) [{checks}]")
        return 1
    print(f"OK: claim governance audit of {policy.repository} passed [{checks}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
