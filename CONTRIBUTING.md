<!--
Derived from templates/docs/CONTRIBUTING.md in larsbx/agent-icm @ sha256:88bf9172c22bc8da
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Contributing to finite-math-kernels

The estate's exact-arithmetic monorepo: BigZ, Q, intervals, Mat3, substitution
dynamics, proof records, claim governance.

**Language / toolchain:** Mojo with Python oracles, under pixi
**CI:** GitHub Actions (`.github/workflows/ci.yml`); runs `pixi run test`

Read these first — they are normative, not background:

- `README.md`
- `docs/`
- `audit/`
- `proof_records/`

---

## The gates

Run these before you open a pull request. Paste what they said into the PR's
evidence table.

1. the aggregate suite, as CI runs it —

   ```sh
   pixi run test
   ```

2. claim-governance audit —

   ```sh
   pixi run test-audit
   ```

3. provenance —

   ```sh
   pixi run test-provenance
   ```

4. reference integrity —

   ```sh
   pixi run references
   ```

5. independent property oracle —

   ```sh
   pixi run property
   ```

A check you did not run is not evidence. Say which ones you skipped and why;
the pull request template has a place for exactly that.

## What counts as evidence here

- A kernel change is proved by a Mojo regression under `tests/`, and where an
  independent language adds value, by a Python oracle beside it.
- Proof records under `proof_records/` carry the dependency closure. A
  promoted claim has a record; a record without a proof is scaffolding and
  says so.
- This repository is vendored byte-for-byte downstream.
  `larsbx/pisot-substitution-conjecture-research` pins three Mojo packages and
  two Python packages here by SHA-256 in its `vendored.toml`.

## Standing prohibitions

- Never change a package facade without saying so in the PR: downstream pins
  it by digest and must re-vendor and re-pin (`scripts/check_vendored_sync.py
  pin NAME COMMIT`).
- Never substitute a floating approximation for an exact predicate. Optimize
  the exact algorithm instead.
- Never let a claim's status surface drift from its proof record; the audit
  exists to catch exactly that.

These are not style preferences. Each one is settled somewhere in the documents
above; changing one is a decision record, not a pull request comment.

## Working shape

1. **Branch** from the default branch.
2. **Make the failing case first** where this repository's discipline requires
   it, and in every case make sure the new test fails without your change.
3. **Run the gates.** All of them, or name the ones you did not.
4. **Update the surfaces.** Documentation, status tables, ledgers and generated
   artifacts that name the behaviour you changed are part of the change, not a
   follow-up. Regenerate generated files with their tooling; never hand-edit one.
5. **Open the pull request** using the template. Fill in *What this does not
   establish* — it is required, and it is the section reviewers read first.

## Claim discipline

State exactly what your change establishes and no more.

- A search that stopped at a limit reports where it stopped.
- A bounded failure is not an absence.
- A refusal is not a clean answer.
- A translation preserves or lowers authority; it never raises it.
- "Verified" unqualified is not a claim. Say verified *by what*.

## Commits

Imperative, present tense, describing the difference: `Add the M-adic ball
carrier`, `Reject a singular M before the zeroth power`. The body carries the
reasoning when the subject cannot.
