# Ledger generation from proof records: specification

**Status:** specification of `tools/generate_ledgers.py`, round-two item R2 of `docs/cross-pollination-round-two-2026-09-16.md`. The consumer repositories keep their claim status on several hand-maintained surfaces at once: a TLA+ ledger and its TLC model configurations (`larsbx/pisot-substitution-conjecture-research`, `tla/`), a `claim_governance.toml` claim ledger (`audit/docs/policy-format.md`), and a Markdown index. Each surface can drift from the others, and the claim-governance `consistency` check detects drift only after the fact. This document makes one named ledger of finite proof records (`docs/proof-records-specification.md`) the single source, and every other surface a deterministic function of it, so drift becomes impossible rather than detected. The example ledger `fixtures/ledger/example.json` and its generated surfaces are committed; `tools/make_ledger_example.py --check` fails when they are stale.

## 0. Scope and non-scope

The generator decides no mathematics. It reads records, validates them with the proof-records reference model, computes their dependency closures, and renders. The status of a claim is a function of the record's kind, its tags, and its closure (section 2.3); the generator never promotes a claim on its own. The TLA+ state machine it targets, `proof_records/ProofArchitecture.tla`, is the generic dependency machine of the PSC program with its repository-specific observables removed: a result is established only by assumption or by discharging a proved result whose prerequisites are all established, and a withdrawn result is never discharged.

## 1. The named ledger

A ledger is a JSON object:

```text
format           "finite_proof_records ledger 1"
repository       free text, printed in headers
module           TLA+ module name; default "Ledger"
tla_dir          directory of the generated TLA+ files, relative to the consumer root; default "tla"
index_path       path of the generated Markdown index; default "docs/ledger-index.md"
records          object: name -> proof record (docs/proof-records-specification.md, section 2, in the
                 JSON shape of fixtures/vectors.json: depends_on as 5-tuples, evidence as pairs)
assumption_sets  object: name -> list of record names; each becomes a TLA+ definition a consumer model may
                 bind to Assumed; optional
status_classes   object: overrides of the default status classes of section 2.3; optional
status_labels    object: class -> label written in the index; default the class itself; optional
```

Names are TLA+ identifiers (`[A-Za-z][A-Za-z0-9_]*`). Record identifiers are the digests the preimage determines and are verified, never trusted. Two names may not carry one identifier. Dependency edges name records by identifier; the generator resolves them to names and refuses an edge to an identifier outside the ledger.

Two tags are interpreted. `withdrawn` marks a withdrawn claim; it is allowed only on a `pending_dependency` record, so that a withdrawn claim can never be accepted or bounded. `status:<class>` overrides the claim's status class (section 2.3) and nothing else; at most one is allowed.

## 2. Analysis

### 2.1 Fail closed

The ledger is refused, with every reason listed, when: the module or a record name is not an identifier; two names share an identifier; an assumption set has an invalid or reserved name (`ResultSet`, `RequiresDef`, `ProvedDef`, `ImportedDef`, `BoundedDef`, `WithdrawnDef`, `NoAssumptions`, `ImportsAssumed`), collides with a record name, or names an unknown record; a record validates as `rejected` (the reason is reported); a record depends on an unknown identifier; a record tagged `withdrawn` is not pending; a record carries more than one `status:` tag. A refused ledger renders nothing (exit 2).

### 2.2 Partition of the results

Every accepted, bounded, or open record is a result. With `outcome` as in the proof-records specification:

| Set | Members |
| --- | --- |
| `ProvedDef` | outcome `accepted` and kind `verified_finite_computation` |
| `ImportedDef` | outcome `accepted` and kind `imported_theorem` |
| `BoundedDef` | outcome `bounded` |
| `WithdrawnDef` | tagged `withdrawn` |
| `RequiresDef[r]` | the names of the records `r` depends on, in edge order |

Imported theorems are never `Proved`: `ProofArchitecture` establishes a proved result by discharge, and an import is not discharged in the repository. They are established only by assumption, which is what `ImportsAssumed == ImportedDef` and the `Imports` model of section 3.2 make explicit. Bounded experiments and pending records are in `ResultSet` and never in `Proved`, so anything that requires them stays unestablished in every model; this is the `ProofArchitecture` form of the proof-records rule that a bounded experiment is evidence, not a theorem. A verified record whose edge requires a bounded outcome on its own scope has a complete closure (proof-records section 5) but is still not established by TLC without assuming the experiment; this leak is deliberate and documented in the index by the closure column.

### 2.3 Status class of a claim

In order: `withdrawn` (class `retired`); a `status:<class>` tag; kind `verified_finite_computation` with an incomplete closure (class `conditional`); the class of the kind (`proved`, `imported`, `finite-domain`, `open`). `status_classes` may rename any of the six classes by its key (`verified_finite_computation`, `conditional`, `imported_theorem`, `bounded_experiment`, `pending_dependency`, `withdrawn`).

### 2.4 The established fixpoint

`established(A, assumed)` is the least set containing `assumed` minus `WithdrawnDef` and closed under: if `r` is in `ProvedDef`, every name in `RequiresDef[r]` is in the set, and none is withdrawn, then `r` is in the set. This is the reachable-state limit of `ProofArchitecture` under the same constants; the models of section 3.2 make TLC verify the agreement.

## 3. Generated surfaces

### 3.1 The TLA+ ledger `<tla_dir>/<Module>.tla`

`EXTENDS ProofArchitecture` and defines `ResultSet`, `RequiresDef` (a `CASE` over the results), the four sets of section 2.2, `NoAssumptions == {}`, `ImportsAssumed == ImportedDef`, every assumption set of the ledger, and one observable `<Name>NotEstablished == "<Name>" \notin established` per result. Results are listed in name order, so the file is a canonical function of the ledger.

### 3.2 The TLC models `MC<Module>Open` and `MC<Module>Imports`

Each model is a `.tla` extending the ledger and a `.cfg` binding `Results`, `Requires`, `Proved`, `Withdrawn` to the definitions above and `Assumed` to `NoAssumptions` or `ImportsAssumed`. The invariants are `TypeOK`, `NothingUnjustified`, `NoWithdrawnDependency`, and `<Name>NotEstablished` for every result outside `established` (section 2.4) under the model's assumptions. The model also defines `Reachable`, the established set, and the property `EventuallyReachable == <>(established = Reachable)`, checked as a `PROPERTY`. TLC therefore verifies both directions of section 2.4 against the state machine: a result the fixpoint calls unreachable is never established, and the results it calls reachable are all eventually established. A consumer runs them with `ProofArchitecture.tla` beside the generated files.

### 3.3 Claim-governance entries (`--claims POLICY`)

One `[[claim]]` per result, `name` the result name and `status` its class, with two surfaces: the TLA+ ledger, anchored on the quoted name inside `ProvedDef == {` (`expect = "present"`) for proved results, inside `ImportedDef` for imports, inside `WithdrawnDef` for withdrawn claims, and `expect = "absent"` from `ProvedDef` otherwise; and the index, anchored on the row `| <Name> |` with `window_lines = 0` and the default `expect = "labelled"`, so the row's label must spell the claim's class through the consumer's `[status.synonyms]`. The entries are spliced between the markers `# BEGIN generated claims ...` and `# END generated claims` of the policy file, or appended when the markers are absent; the head of the file stays the consumer's. The spliced policy is then loaded with the claim-governance package and refused (exit 2) if it does not load or if any index label is not a synonym of its class, so the generator never writes a policy the checker would reject.

### 3.4 The index `<index_path>`

A Markdown table with one row per result: name, status label, kind, scope, statement, dependencies (as code spans, so a dependency cell never reads as a row anchor), and the proof-records closure of the record: `complete`, or the missing links by name and reason.

## 4. Command line and currency

`generate_ledgers.py LEDGER [--out ROOT] [--claims POLICY] [--check]` writes the surfaces under `ROOT` (exit 0), or with `--check` compares them with the files on disk and exits 1 naming every stale file. A consumer runs the check in CI so that generated surfaces are current and never hand-edited. Rendering is a pure function of the ledger: running the generator twice changes nothing. `pixi run ledgers` regenerates the committed example.

## 5. Conformance tests

`tests/proof_records/test_generate_ledgers.py` checks, over the example ledger and variants of it: the committed example is current; the partition and statuses of section 2; the fixpoint of section 2.4 including the exclusion of assumed withdrawn results; the rendering of each surface; every refusal of section 2.1 by name; the splice and the policy refusal of section 3.3; the claim-governance audit of the example directory passes; the command line's exit codes. When the environment variable `TLA_TOOLS` names a `tla2tools.jar`, the tests also run TLC on both generated models of the example and on a deliberately wrong configuration, which must report the violated invariant. CI does not carry the jar, so that part is skipped there and run locally.

## 6. Consumer binding

A consumer replaces its hand-written ledger module, model configurations, `[[claim]]` entries, and index with the generated ones, keeps `ProofArchitecture.tla` (or its own extension of it) in `tla_dir`, and adds `generate_ledgers.py LEDGER --claims claim_governance.toml --check` to its verification chain. Observables that named repository-specific results in the original PSC module (`MainResultIsConditional` and the others) become `<Name>NotEstablished` entries of the generated module. The PSC `MCArchitectureOpen` configuration is the `Open` model of section 3.2; a configuration assuming a named set of results is an assumption set of the ledger and a hand-written `.cfg` binding `Assumed` to it.

## 7. Non-claims

The generator does not decide that a record is true, that an import's hypotheses hold, that a bounded experiment generalizes, or that a `status:` override is justified. Those are the consumer's records and the consumer's policy; the generator only guarantees that every surface says the same thing about them.
