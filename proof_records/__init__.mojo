# proof_records: finite proof records in Mojo.
#
#   records   Record, Edge, Pair, Ledger, MissingLink, Closure, TagPolicy;
#             validate, outcome, preimage_bytes, identity, canonical_bytes,
#             close, no_policy.
#   sha256    sha256, hex: the identifier suite over the record preimage.
#
# Specification: docs/proof-records-specification.md. The package states no
# theorem and ships no policy; repository policy is a TagPolicy the consumer
# builds. Every dependency is an identity-bearing Edge (record, expected
# claim, use site, scope relation, required outcome), and every record id is
# verified against the preimage that excludes it.
