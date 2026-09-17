# Finite proof records: specification

**Status:** specification of the `proof_records` package. Version 1 was written before any code, as required by the extraction audit that named it (`larsbx/NLAP-JT` and `larsbx/pisot-substitution-conjecture-research`, `docs/library-extraction-candidates-2026-09-14.md`, section 5). Version 2 (this document) adopts the identity and dependency contract of `docs/finite-proof-records-spec.md` at commit `e10c665` of that Mandelbrot program, then `larsbx/NLAP-JT` and since 2026-09-16 `larsbx/finite-mandlebrot-research` (sections 3, 6, and 8): identity-bearing dependency edges and a record identifier verified against a preimage that excludes it. The canonical implementation is `proof_records/records.mojo`; the executable reference of this document is `proof_records/records.py`, and `fixtures/vectors.json` is the replay set both agree on.

The package states no theorem. It classifies records of work, checks that each carries the finite evidence its class requires, verifies that each record carries the identifier its content determines, serializes records canonically, and decides whether the dependency closure of a claim is complete. What counts as a forbidden primitive, an open frontier, or an acceptable source is **repository policy**, supplied by the consumer as a predicate. The package ships no policy of its own.

## 1. Record kinds

| Kind | Value | Meaning | Outcome | Can support a theorem |
| --- | --- | --- | --- | --- |
| verified finite computation | `verified_finite_computation` | replayable, canonical, machine-checked; carries the replay command and the canonical digest of its inputs and outputs | `accepted` | yes |
| repository theorem | `repository_theorem` | a theorem proved in the consumer repository by a human-reviewed proof at a named location (manuscript section, proof note, pull request) | `accepted` | yes, when `proof_reviewed` is `true` |
| imported theorem | `imported_theorem` | an external result with a named source whose hypotheses were checked against finite data | `accepted` | yes, when `hypotheses_checked` is `true` |
| pending dependency | `pending_dependency` | a conjectural or source-pending premise: named, unchecked, blocks completion | `open` | no |
| bounded experiment | `bounded_experiment` | evidence over an enumerated finite domain; never a general theorem | `bounded` | only its own bounded proposition, on its own scope |
| rejected | `rejected` | malformed or refused; carries the reason | `rejected` | no |

These six kinds, together with the two-valued **closure status** of section 5, are the generalizable content of the Mandelbrot program's C1 ledgers and PSC's census, import, and obligation records. The C1 vocabulary (theorem tags, payload strength classes, proof blocks) and the PSC vocabulary (repository-proved theorems, censuses, Barge-Stimac-Williams import, source-pending Galois material, the G1, concentration, and renewal obligations) are instances, not part of the package. A `repository_theorem` is distinguished from a `verified_finite_computation` by what closes it, a reviewed proof rather than a replay, and from an `imported_theorem` by where the proof lives; the package checks only that the proof is named and marked reviewed, never the proof itself. That contract's further kinds (`formal_derivation`, `countermodel`) and states (`incomplete`, `refuted`) are not implemented here; a consumer needing them records them as `pending_dependency` until the package grows.

The **outcome** of a validated record is the fourth column: `outcome(record)`. Consumer policy is reported separately (section 6) and never changes the outcome.

## 2. Record fields

```text
Record(
  id          the identifier the preimage determines (section 4); verified, never trusted
  kind        one of the six kinds
  statement   non-empty opaque text; the package never interprets it
  scope       non-empty opaque text: the exact domain on which the statement is asserted
  depends_on  ordered tuple of dependency edges, no two naming the same record
  evidence    ordered pairs (key, value), keys unique; required keys per kind below
  tags        set of strings the consumer's policy may act on
)

Edge(
  record_id         the record depended on
  expected_claim    the exact statement that record must make
  use_site          the consumer-owned position at which the claim is used
  scope_relation    `same`: the dependency's scope must equal this record's scope;
                    `scope=<literal>`: the dependency's scope must equal <literal>
  required_outcome  `accepted` or `bounded`: the outcome this use requires
)
```

All five edge fields are identity-bearing. A `bounded` requirement is admissible only under the `same` relation: bounded evidence closes a claim only on the domain the evidence enumerated (the Mandelbrot contract's rule that an accepted general claim may not rest on a bounded experiment). Every relation is decided by string equality; the package interprets neither statements nor scopes.

Required evidence keys:

| Kind | Required keys | Constraint |
| --- | --- | --- |
| verified | `replay`, `digest` | `replay` is the command that reproduces the computation; `digest` is the canonical digest of its inputs and outputs |
| repository | `source`, `proof_reviewed` | `source` names where the proof is; `proof_reviewed` must be exactly `true` |
| imported | `source`, `hypotheses_checked` | `hypotheses_checked` must be exactly `true` |
| pending | `reason` | why it is unchecked (conjectural, source pending, open obligation) |
| bounded | `domain` | the enumerated finite domain |
| rejected | `reason` | |

## 3. Validation fails closed

`validate(record)` returns the record unchanged when it is well-formed and otherwise its `rejected` form with a reason, in this order:

| Reason | When |
| --- | --- |
| `unknown record kind` | |
| `rejected without reason` | a `rejected` record with no `reason` |
| `empty statement or scope` | |
| `duplicate evidence key` | |
| `missing evidence: <keys>` | required keys absent, sorted |
| `duplicate or self dependency` | two edges name one record, or an edge names the record itself |
| `unknown scope relation: <relation>` | neither `same` nor `scope=<literal>` |
| `unknown required outcome: <outcome>` | neither `accepted` nor `bounded` |
| `bounded dependency outside its own scope` | `required_outcome` is `bounded` under a relation other than `same` |
| `imported theorem with unchecked hypotheses` | |
| `repository theorem without a reviewed proof` | |
| `identifier does not match preimage` | `id` is not `identity(record)` (section 4) |

Structural checks precede the identity check: a construction that cannot produce the envelope is not a record and has no authoritative encoding, whatever identifier it carries. A structurally well-formed record whose outcome is `open` or `bounded` validates unchanged and keeps its identity, so a closure can name it exactly. A record refused only by consumer policy likewise keeps its identity; the refusal is a missing link, not a rejection. A malformed record is therefore never silently a valid one, and a consumer that reads a record kind reads it after validation.

## 4. Identity and canonical serialization

```text
chunk(s)  = len(utf8(s)) as 8-byte big-endian, then utf8(s)
count(n)  = n as 8-byte big-endian
preimage  = chunk("finite_proof_record") chunk("2")
            chunk(kind) chunk(statement) chunk(scope)
            count(n_deps)  [chunk(record_id) chunk(expected_claim) chunk(use_site)
                            chunk(scope_relation) chunk(required_outcome)]...   # order significant
            count(n_ev)    chunk(key_1) chunk(val_1) ...                           # sorted by key
            count(n_tags)  chunk(tag_1) ...                                        # sorted
identity  = "sha256:" + lowercase hex of SHA-256(preimage)
canonical = preimage chunk(id)                                                     # authoritative encoding
digest    = SHA-256(canonical)
```

The **preimage** (`preimage_bytes`) is the canonical encoding of every identity-bearing field except the identifier; `identity(record)` is the identifier the record must carry; the **authoritative encoding** (`canonical_bytes`) is the preimage followed by the identifier, so a validator recomputes the preimage and verifies the identifier without circularity. Changing the kind, statement, scope, any edge field, any evidence pair, or any tag changes the identity. Map iteration order never enters the encoding; lists carry their length before their items (the same discipline as `larsbx/finite-mandlebrot-research`'s `docs/canonical-serialization.md`).

Because identifiers are digests of their preimage, a record can name only records that already exist: a dependency cycle or a self-dependency cannot be constructed from verified identifiers. The closure's cycle guard (section 5) remains as defense in depth and fires only on identifiers that have not been verified.

`identified(record)` returns the record carrying its identity; `edge(target, use_site, scope_relation, required_outcome)` builds an edge expecting exactly the statement `target` makes. The identifier suite is fixed to SHA-256 (section 7); the `sha256:` prefix names it so a consumer suite can be added without changing verified identifiers.

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
| `claim mismatch: <use_site>` | the record's statement is not the edge's `expected_claim` |
| `scope mismatch: <use_site>` | the record's scope is not the scope the edge's relation requires |
| `pending: <reason>` | a pending dependency was reached, whatever the edge required |
| `bounded experiment is evidence, not a theorem` | a bounded experiment was reached as root, or through an edge requiring `accepted` |
| `outcome mismatch: <use_site> requires bounded, found accepted` | an edge required `bounded` and reached an accepted record |
| `policy: <reason>` | the consumer's predicate refused the record |
| `dependency cycle` | the record is already on the current path (unreachable through verified identifiers) |

The root is reached without an edge, so it is held to `accepted` with no claim or scope requirement. The closure is **complete** iff there are no missing links: every reached record is validated, matches the edge that reached it in claim, scope, and outcome, is accepted by the policy, and the graph below the root is acyclic. A bounded experiment as root is therefore never complete, and a verified record's closure is complete over a bounded experiment only when its edge requires `bounded` on the `same` scope: bounded evidence closes its own proposition on its own domain and nothing more. Records with claim, scope, or outcome mismatches and pending or bounded records still have their dependencies walked, so a report names every missing link below them, not only the first. A record reached through several edges is validated and walked once, but the claim, scope, and outcome of every incoming edge are checked, so a diamond whose second edge is wrong is incomplete.

## 6. Consumer policy predicates

A policy is a function `Record -> reason | None`. The package provides `tag_policy(forbidden)`, which refuses a record carrying any tag in `forbidden` with the consumer's stated reason, and `no_policy`. Examples the consumers already encode by hand today:

| Consumer | Today | As a policy |
| --- | --- | --- |
| Mandelbrot `mojo_theorem_kernel.check_proof_object` | rejects `uses_rank2_circle`; marks `claims_global_mlc` as open frontier; requires a theorem-tag import for a non-finite statement | `tag_policy({"uses_rank2_circle": "rank-2 circle primitive rejected"})`; a global-MLC-strength claim is recorded as `pending_dependency` with reason `open frontier`, never imported; a non-finite claim without an imported-theorem dependency fails as an unknown or pending link |
| Mandelbrot theorem-tag import ledger | allowed conclusion kinds and strength classes; `MLC_STRENGTH_GLOBAL` and `FORBIDDEN_PLACEHOLDER` never imported | tags `strength:<class>` with a policy refusing the two forbidden classes; a placeholder is a `pending_dependency`, not an `imported_theorem` |
| PSC | finite exact censuses (CI-pinned numbers); the imported Barge-Stimac-Williams density theorem; source-pending Galois material; the open G1, concentration, and renewal obligations | censuses are `verified_finite_computation` on the census scope (replay: the pixi task; digest: the pinned census output) or `bounded_experiment` when cited for a general claim; the density theorem is `imported_theorem` with `hypotheses_checked` decided by the consumer; Galois material and the open obligations are `pending_dependency`, so any closure that reaches them is incomplete with the link named |

The package never decides that a source is acceptable, that hypotheses hold, that a tag is forbidden, or that two scopes are related other than by equality. It only refuses to call a closure complete while any such decision is missing.

## 7. Non-goals

- No proof checking of statements: `statement` and `scope` are opaque.
- No hash-suite selection beyond SHA-256 of the preimage and of the canonical bytes; consumers that need a different suite hash the same bytes under a new prefix.
- No promotion of evidence: a complete closure of verified and imported records is a complete dependency record, not a claim that the mathematics is correct. That remains the consumer's verification-architecture and claim-status discipline.

## 8. Mojo implementation

The canonical implementation is `proof_records/records.mojo`, with SHA-256 in `proof_records/sha256.mojo`, compiled and tested under the pinned toolchain. It replays `fixtures/vectors.json` through `tests/proof_records/replay_vectors.mojo`: `tools/replay_mojo.py` writes the vectors as a tab-separated transcript, the Mojo driver checks the FIPS 180-4 SHA-256 known answers, constructs the ledger, and runs `validate`, `identity`, `canonical_bytes`, and `close` with the named policy, and the harness compares every kind, reason, identity, closure, and the SHA-256 of the printed canonical octets with the fixture (`pixi run replay`). The identity line is the Mojo SHA-256 over the preimage and the fixture identity is `hashlib`'s, so the two implementations cross-check on every record. `tools/make_vectors.py` regenerates the fixture from the Python reference; the test suite fails if the committed fixture and the regeneration differ, so the fixture is a stable contract rather than a snapshot. Two implementation choices are fixed by this section: the policy type in Mojo is `TagPolicy` (forbidden tag, reason), which is section 6's `tag_policy`, with an empty policy as `no_policy`; and an absent evidence value and an empty one are the same (`Record.field` returns the empty string), matching the reference model's truthiness test.

Origin of the classification: in the Mandelbrot program (`larsbx/finite-mandlebrot-research`, named `larsbx/NLAP-JT` at the time), `src/mojo_theorem_kernel.mojo` (`KernelStatement`, `TheoremTagImport`, `RuleApplication`, `ProofObject`, `CheckedTheoremStatus`), `src/C1_theorem_tag_import_ledger.mojo`, `src/C1_theorem_tag_assumption_payloads.mojo`, `src/C1_final_proof_block_ledger.mojo` (`ProofBlockStatus`), and `docs/canonical-serialization.md`. None of that code was moved: the audit found it outside the compiled closure and policy-laden, so the extraction starts here, from the specification.
