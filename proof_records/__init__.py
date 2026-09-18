"""Finite proof records: classification, identity, canonical serialization, dependency closure. See docs/proof-records-specification.md.

Importing this package runs `self_test.verify()`, which refuses to load when the
canonical codec cannot reproduce its committed known answers. Adopted from
`larsbx/coop_substrate`, whose application aborts boot on the same condition:
a ledger that content-addresses wrongly should never get as far as being used.

The gate runs unless `self_test.REGENERATING` is set in the environment, which
is for `tools/make_vectors.py` alone: the tool that writes the known answers
cannot be held to the ones it is replacing. A load that skips the gate says so
on stderr, because a check that can be turned off silently is not a check.
"""

import os
import sys

from proof_records.records import (Closure, Edge, Kind, MissingLink, Record, canonical_bytes, close, digest, edge, identified, identity,
                                   no_policy, outcome, preimage_bytes, tag_policy, validate)
from proof_records.self_test import REGENERATING, SelfTestError, verify

if os.environ.get(REGENERATING):
    print(f"proof_records: {REGENERATING} is set; the known-answer gate did not run.", file=sys.stderr)
else:
    verify()

__all__ = ["Closure", "Edge", "Kind", "MissingLink", "REGENERATING", "Record", "SelfTestError", "canonical_bytes", "close", "digest",
           "edge", "identified", "identity", "no_policy", "outcome", "preimage_bytes", "tag_policy", "validate", "verify"]
