<!--
Derived from templates/records/CLAIM_LEDGER_ENTRY.md in larsbx/agent-icm @ sha256:ecfd74f589edb33e
Edit the canonical template or estate.toml in larsbx/agent-icm, then re-render there: make estate
Hand-edits here are drift, and agent-icm's `make estate-check` fails on them.
-->

# Claim — `<Name>`

<!--
One claim, one entry, mirroring the repository's authoritative claim record.
Where a generator derives claim entries from proof records, the record is the
single status surface and this entry is derived from it: edit the record, then
regenerate. Otherwise this entry is that surface. Anything else that states
this claim's status is generated from the source, or it is already drift.
-->

- **Name:** `<Name>`            <!-- the identifier tests declare against -->
- **Status:** proved | imported | scaffolded | open
- **Statement:** `<the claim, stated exactly, with its quantifiers and its domain>`
- **Domain:** `<the finite domain surveyed, or the hypotheses assumed>`

## Warrant

<!--
What makes this true. Exactly one of:
 - proved       — a deductive proof; cite it (file, theorem name)
 - imported     — a result from the literature; cite it, and state which
                  hypotheses transfer and which were re-derived here
 - scaffolded   — machinery is in place, the claim is not yet established
 - open         — stated, not established
Authority is preserved or lowered in translation. It is never raised.
-->

## Evidence

| Kind              | Where | What it establishes |
| ----------------- | ----- | ------------------- |
| exact computation |       |                     |
| formal proof      |       |                     |
| certificate       |       |                     |

## Guarded by

<!--
The test that pins the contract this claim rests on, and the receipt proving a
run actually reached the declaration. A declaration no run reached guards
nothing. A test that declares this claim is a link, not evidence: what the
contract is, the assertions decide; that the claim follows from it, the proof
or certificate decides.
-->

## Bound

<!--
Required for anything finite or searched. Where the search stopped, and what an
exhausted budget would have looked like as distinct from a mathematical verdict.
A bounded failure is not an absence.
-->

## Dependencies

<!-- The claims this one rests on, by name. Cycles are a defect. -->

## Independent control

<!-- The control that could have failed. A control derived from its subject cannot fail and is not a control. -->
