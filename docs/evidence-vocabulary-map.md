# One outcome vocabulary: external evidence classes as proof records

**Status:** specification of `proof_records/vocabularies.py`, round-two item R4 of `docs/cross-pollination-round-two-2026-09-16.md` (A1, item 2). Three programs in this account keep content-addressed evidence ledgers and arrived at the same shape with different vocabularies: `larsbx/sprucegoose` with five evidence classes for governed releases, `larsbx/crypto-composer` with a two-status test ledger, and this package with six record kinds and four outcomes. This document fixes the map between them and the authority rule it must obey. It states no mathematics and changes no claim status.

## 0. What a map may and may not do

Translating a receipt **preserves or lowers authority, never raises it**. Concretely: a non-transferable exercise never becomes a theorem, an unexecuted step never becomes a failure, and a failing test never becomes a malformed record. Each row below therefore carries the outcomes its class may never reach, and `authority_preserved` checks a translated record against them. Whatever the map produces is an ordinary record: `validate` applies the usual fail-closed rules, and `close` applies the usual dependency rules, including the one that bounded evidence closes only its own scope.

## 1. Sources

| Program | Vocabulary | Read from |
| --- | --- | --- |
| `larsbx/sprucegoose` | five evidence classes | `docs/release-provenance.md`, section "Evidence classes", at commit `c211ff6` |
| `larsbx/crypto-composer` | two ledger statuses | `tdd_ledger.zig` (`Status = enum { red, green }`) and `test/harness.zig` (`requireProof`), at commit `6b8ee2c` |

Both were read at those commits rather than transcribed from the round-two audit; if either vocabulary changes, this document and `proof_records/vocabularies.py` change with it, and the conformance tests fail until they do.

## 2. The map

| External class | Kind | Outcome | May never reach | Why |
| --- | --- | --- | --- | --- |
| `Source/static PASS` | `verified_finite_computation` | `accepted` | `bounded`, `open` | formatter, standalone compilation, and regressions on exact bytes: a replayable computation over named inputs |
| `Boot-free behavioral PASS` | `verified_finite_computation` | `accepted` | `bounded`, `open` | codecs, in-memory inspection, CLI, and no-write accounting, replayable without booting the application |
| `Dirty build exercise` | `bounded_experiment` | `bounded` | `accepted` | always non-transferable evidence, even if repeated bytes match, so it closes only its own enumerated domain |
| `Transferable clean release` | `verified_finite_computation` | `accepted` | `bounded`, `open` | a clean committed candidate built twice from identical declared inputs, byte-identical archives and receipts, validated against destination inventory |
| `UNEXECUTED` | `pending_dependency` | `open` | `accepted`, `bounded` | dependency or setup prevented execution: neither PASS nor implementation FAIL, hence an open premise and never a rejection |
| `red` | `pending_dependency` | `open` | `accepted`, `bounded` | a recorded failing test is an open obligation, not a malformed record; the package has no `refuted` state and section 1 of `docs/proof-records-specification.md` directs a consumer to record one as pending |
| `green` | `verified_finite_computation` | `accepted` | `bounded`, `open` | a green row is admitted only after a red row for the same test and only under `--run`, so it carries a command, an exit code, and the manifest digest of the tree it ran against |

Required evidence follows the kind: `replay` and `digest` for a verified computation, `domain` for a bounded experiment, `reason` for a pending dependency. `translate` refuses a receipt that does not supply them, so a translation never yields a record with less evidence than its class asserts.

### Kinds with no external image

| Kind | Why nothing maps to it |
| --- | --- |
| `repository_theorem` | neither system carries a human-reviewed proof at a named location |
| `imported_theorem` | neither system imports an external theorem with checked hypotheses |
| `rejected` | malformed-record status, not an evidence class; a failing or unexecuted step is `pending_dependency` |

The gap is the point: the research repositories have theorem kinds the release and test ledgers have no use for, and those two have a historical plane (a receipt per run, with command and exit code) that the research repositories lack. The map does not invent either side.

### One asymmetry worth stating

`red` and `UNEXECUTED` both become `pending_dependency`, yet they mean different things: a red row ran and failed, an unexecuted step never ran. The package cannot distinguish them, because it has no `refuted` state, so the distinction must survive in the `reason` text. A consumer that needs the distinction machine-readable should carry a tag, not a kind; adding a `refuted` state would change the outcome lattice and is out of scope here.

## 3. Canonical encoding

`docs/canonical-encoding.md` fixes the byte encoding of the integers and rationals a record's preimage contains, and section 4 of `docs/proof-records-specification.md` fixes the record preimage itself: length-prefixed fields, no maps, and an identifier that excludes itself. Sprucegoose's `Canonical` uses sorted string-keyed JSON and crypto-composer commits a `MANIFEST.SHA256` over tracked files; both are outside this package. A translated record is therefore identified by **this** package's preimage, and the external receipt's own identity belongs in its evidence (a `digest` key), never silently reused as the record identifier. That keeps one encoding authoritative per record and leaves the external ledgers' encodings untouched.

## 4. Conformance tests

`tests/proof_records/test_vocabularies.py` checks, for every row: the kind and its outcome; that the outcome is not one the class may never reach; that `translate` refuses a missing or empty required evidence key; that a translated record validates unchanged and carries the identifier its preimage determines; that a bounded translation cannot close a general claim, by closing it through an edge that requires `accepted`; and that the unmapped kinds have no row. It also checks the two source vocabularies are covered exactly, so adding a class upstream without updating this map fails.

## 5. Consumer obligations, not done here

This package supplies the map and its checks. The other two ends are separate changes in their own repositories: sprucegoose emitting release receipts as records through this table, and crypto-composer consuming the closure validator for its constraint findings. Neither is in this repository's scope, and neither is claimed by this document.
