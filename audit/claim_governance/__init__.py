"""Policy-driven claim-governance audits for mathematical repositories.

The package is a set of pure functions from ``(Policy, repository root)`` to
tuples of :class:`Finding`.  Nothing here decides mathematics: every check is
a lexical guard that keeps a repository's own status vocabulary, terminology
registry, claim ledger, and numerical-primitive bans consistent with its
prose and source.  Repository policy lives in the consumer's
``claim_governance.toml`` (see ``audit/docs/policy-format.md``); this package ships
no policy of its own.
"""

from claim_governance.findings import Finding
from claim_governance.policy import Policy, load_policy
from claim_governance.runner import CHECKS, run

__all__ = ["CHECKS", "Finding", "Policy", "load_policy", "run"]
