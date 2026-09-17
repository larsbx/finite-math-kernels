<!--
Derived from templates/docs/AGENTS.md in larsbx/agent-icm @ sha256:e0ea75600e3d136a
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Agent policy — finite-math-kernels

The estate's exact-arithmetic monorepo: BigZ, Q, intervals, Mat3, substitution
dynamics, proof records, claim governance.

**Language / toolchain:** Mojo with Python oracles, under pixi
**CI:** GitHub Actions (`.github/workflows/ci.yml`); runs `pixi run test`

This file is for whoever is working here next, human or otherwise. It states
what is settled, so that it does not get re-litigated by someone reading only
the code.

## Read first

- `README.md`
- `docs/`
- `audit/`
- `proof_records/`

## Gates

Before proposing a change as finished, run:

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

Report honestly which ran. A partial environment that reports a skip is worth
more than one that passes vacuously.

## What this repository treats as evidence

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

## Scope discipline

- Make the change that was asked for. If the surrounding code is wrong in a way
  the task did not name, say so — do not widen the diff to fix it.
- If something is blocked, finish everything that is not, and say precisely what
  was left and why.
- Where a decision is already recorded, follow it or reopen it explicitly. Do
  not route around it in code.
