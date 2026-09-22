# Typed proof-graph normalization contract

`finite-proof-graph.normalization@1.0.0` is the domain-owned registration for
the executable semantics already specified by
`docs/typed-relationship-graph-spec.md`. The registration and its vectors are
owned here because this repository remains authoritative for the proof-record
format. An independent implementation may be normative only for the three
questions named in the registration.

The normalizer interprets a well-formed `finite typed relationship graph 1`,
discards the non-semantic `generated` message, orders nodes and edges as the
source specification requires, and emits canonical JSON. Refusal is part of
the contract: malformed input, unknown vocabulary, missing endpoints,
duplicate node identifiers, non-exact certainty, or missing backing evidence
produces no normal form.

This registration does not decide whether a claim is true or proved, accept a
certificate, authorize an effect, or report persisted state. In particular,
the words `theorem-backed` and `imported-theorem` are provenance labels copied
from an already validated ledger; normalization does not validate the theorem.

The first canonical vector is the existing generated example graph. Its input
digest is pinned in the registration. The expected result under
`fixtures/oracle/` is committed separately so downstream implementations must
match a domain-owned answer rather than regenerate their own expectation.
