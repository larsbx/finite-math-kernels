"""Finite proof records: classification, identity, canonical serialization, dependency closure. See docs/proof-records-specification.md.

Importing this package runs `self_test.verify()`, which refuses to load when the
canonical codec cannot reproduce its committed known answers. Adopted from
`larsbx/coop_substrate`, whose application aborts boot on the same condition:
a ledger that content-addresses wrongly should never get as far as being used.
"""

from proof_records.records import (Closure, Edge, Kind, MissingLink, Record, canonical_bytes, close, digest, edge, identified, identity,
                                   no_policy, outcome, preimage_bytes, tag_policy, validate)
from proof_records.self_test import SelfTestError, verify

verify()

__all__ = ["Closure", "Edge", "Kind", "MissingLink", "Record", "SelfTestError", "canonical_bytes", "close", "digest", "edge", "identified",
           "identity", "no_policy", "outcome", "preimage_bytes", "tag_policy", "validate", "verify"]
