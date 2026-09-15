# Finite proof records: specification

**Status:** specification of the `finite_proof_records` package, written before any code, as required by the extraction audit that named it (`larsbx/NLAP-JT` and `larsbx/pisot-substitution-conjecture-research`, `docs/library-extraction-candidates-2026-09-14.md`, section 5). The canonical implementation is `finite_proof_records/records.mojo`; the executable reference of this document is `finite_proof_records/records.py`, and `fixtures/vectors.json` is the replay set both agree on.

The package states no theorem. It classifies records of work, checks that each carries the finite evidence its class requires, serializes records canonically, and decides whether the dependency closure of a claim is complete. What counts as a forbidden primitive, an open frontier, or an acceptable source is **repository policy**, supplied by the consumer as a predicate. The package ships no policy of its own.

## 1. Record kinds

| Kind | Value | Meaning | Can support a theorem |
| --- | --- | --- | --- |
| verified finite computation | `verified_finite_computation` | replayable, canonical, machine-checked; carries the replay command and the canonical digest of its inputs and outputs | yes |
| imported theorem | `imported_theorem` | an external result with a named source whose hypotheses were checked against finite data | yes, when `hypotheses_checked` is `true` |
| pending dependency | `pending_dependency` | a conjectural or source-pending premise: named, unchecked, blocks completion | no |
| bounded experiment | `bounded_experiment` | evidence over an enumerated finite domain; never a general theorem | no |
| rejected | `rejected` | malformed or refused; carries the reason | no |

These five kinds, together with the two-valued **closure status** of section 5, are the generalizable content of NLAP-JT's C1 ledgers and PSC's census, import, and obligation records. The C1 vocabulary (theorem tags, payload strength classes, proof blocks) and the PSC vocabulary (censuses, Barge-Stimac-Williams import, source-pending Galois material, the G1, concentration, and renewal obligations) are instances, not part of the package.

## 2. Record fields

```text
Record(
  id          non-empty identifier, unique in a ledger
  kind        one of the five kinds
  statement   non-empty opaque text; the package never interprets it
  depends_on  ordered tuple of identifiers, no duplicates, not containing id
  evidence    ordered pairs (key, value), keys unique; required keys per kind below
  tags        set of strings the consumer's policy may act on
)
```

Required evidence keys:

| Kind | Required keys | Constraint |
| --- | --- | --- |
| verified | `replay`, `digest` | `replay` is the command that reproduces the computation; `digest` is the canonical digest of its inputs and outputs |
| imported | `source`, `hypotheses_checked` | `hypotheses_checked` must be exactly `true` |
| pending | `reason` | why it is unchecked (conjectural, source pending, open obligation) |
| bounded | `domain` | the enumerated finite domain |
| rejected | `reason` | |

## 3. Validation fails closed

`validate(record)` returns the record unchanged when it is well-formed and otherwise its `rejected` form with a reason. Rejections: unknown kind; empty identifier or statement; duplicate evidence key; missing required evidence; duplicate or self dependency; imported theorem whose `hypotheses_checked` is not `true`; a rejected record without a reason. A malformed record is therefore never silently a valid one, and a consumer that reads a record kind reads it after validation.

## 4. Canonical serialization

`canonical_bytes(record)` is deterministic and injective on validated records:

```text
chunk(s) = len(utf8(s)) as 8-byte big-endian, then utf8(s)
bytes    = chunk("finite_proof_record") chunk("1")
           chunk(id) chunk(kind) chunk(statement)
           n_deps(8 bytes)  chunk(dep_1) ... chunk(dep_n)          # order significant
           n_ev(8 bytes)    chunk(key_1) chunk(val_1) ...          # sorted by key
           n_tags(8 bytes)  chunk(tag_1) ...                       # sorted
```

`digest(record)` is the SHA-256 of those bytes. Map iteration order never enters the encoding; lists carry their length before their items (the same discipline as NLAP-JT's `docs/canonical-serialization.md`, whose composite certificate schemas stay in that repository).

## 5. Dependency closure

`close(ledger, root, policy)` walks `depends_on` from `root` depth-first and returns

```text
Closure(root, complete, reached (sorted identifiers), missing_links (in discovery order))
```

A **missing link** is `(record_id, reason)` with one of these reasons:

| Reason | When |
| --- | --- |
| `unknown record` | the identifier is not in the ledger |
| `ledger key differs from record identifier` | the ledger maps a key to a record with another id |
| `rejected: <reason>` | validation rejected the record; its dependencies are not walked |
| `pending: <reason>` | a pending dependency was reached |
| `bounded experiment is evidence, not a theorem` | a bounded experiment was reached, as root or as support |
| `policy: <reason>` | the consumer's predicate refused the record |
| `dependency cycle` | the record is already on the current path |

The closure is **complete** iff there are no missing links: every reached record is a validated verified computation or imported theorem, accepted by the policy, and the graph below the root is acyclic. A bounded experiment as root is therefore never complete; it is evidence with a complete evidence closure only in the consumer's own reading, which the package does not offer. Pending and bounded records still have their dependencies walked, so a report names every missing link below them, not only the first.

## 6. Consumer policy predicates

A policy is a function `Record -> reason | None`. The package provides `tag_policy(forbidden)`, which refuses a record carrying any tag in `forbidden` with the consumer's stated reason, and `no_policy`. Examples the consumers already encode by hand today:

| Consumer | Today | As a policy |
| --- | --- | --- |
| NLAP-JT `mojo_theorem_kernel.check_proof_object` | rejects `uses_rank2_circle`; marks `claims_global_mlc` as open frontier; requires a theorem-tag import for a non-finite statement | `tag_policy({"uses_rank2_circle": "rank-2 circle primitive rejected"})`; a global-MLC-strength claim is recorded as `pending_dependency` with reason `open frontier`, never imported; a non-finite claim without an imported-theorem dependency fails as an unknown or pending link |
| NLAP-JT theorem-tag import ledger | allowed conclusion kinds and strength classes; `MLC_STRENGTH_GLOBAL` and `FORBIDDEN_PLACEHOLDER` never imported | tags `strength:<class>` with a policy refusing the two forbidden classes; a placeholder is a `pending_dependency`, not an `imported_theorem` |
| PSC | finite exact censuses (CI-pinned numbers); the imported Barge-Stimac-Williams density theorem; source-pending Galois material; the open G1, concentration, and renewal obligations | censuses are `verified_finite_computation` (replay: the pixi task; digest: the pinned census output) or `bounded_experiment` when cited as evidence for a general claim; the density theorem is `imported_theorem` with `hypotheses_checked` decided by the consumer; Galois material and the open obligations are `pending_dependency`, so any closure that reaches them is incomplete with the link named |

The package never decides that a source is acceptable, that hypotheses hold, or that a tag is forbidden. It only refuses to call a closure complete while any such decision is missing.

## 7. Non-goals

- No proof checking of statements: `statement` is opaque.
- No hash-suite selection beyond SHA-256 of the canonical bytes; consumers that need a different suite hash the same bytes.
- No promotion of evidence: a complete closure of verified and imported records is a complete dependency record, not a claim that the mathematics is correct. That remains the consumer's verification-architecture and claim-status discipline.

## 8. Mojo implementation

The canonical implementation is `finite_proof_records/records.mojo`, compiled and tested under the pinned toolchain from its first commit. It replays `fixtures/vectors.json` through `tests/replay_vectors.mojo`: `tools/replay_mojo.py` writes the vectors as a tab-separated transcript, the Mojo driver constructs the ledger and runs `validate`, `canonical_bytes`, and `close` with the named policy, and the harness compares every kind, reason, closure, and the SHA-256 of the printed canonical octets with the fixture (`pixi run replay`). `tools/make_vectors.py` regenerates the fixture from the Python reference; the test suite fails if the committed fixture and the regeneration differ, so the fixture is a stable contract rather than a snapshot. Two implementation choices are fixed by this section: the policy type in Mojo is `TagPolicy` (forbidden tag, reason), which is section 6's `tag_policy`, with an empty policy as `no_policy`; and an absent evidence value and an empty one are the same (`Record.field` returns the empty string), matching the reference model's truthiness test.

Origin of the classification: `larsbx/NLAP-JT` `src/mojo_theorem_kernel.mojo` (`KernelStatement`, `TheoremTagImport`, `RuleApplication`, `ProofObject`, `CheckedTheoremStatus`), `src/C1_theorem_tag_import_ledger.mojo`, `src/C1_theorem_tag_assumption_payloads.mojo`, `src/C1_final_proof_block_ledger.mojo` (`ProofBlockStatus`), and `docs/canonical-serialization.md`. None of that code was moved: the audit found it outside the compiled closure and policy-laden, so the extraction starts here, from the specification.
