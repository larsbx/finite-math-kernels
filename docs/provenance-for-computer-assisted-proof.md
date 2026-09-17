# Provenance for computer-assisted proof

**Status:** methodological note. It states no theorem, depends on no conjecture, and is written for
readers who have never seen the research programmes that produced the machinery it describes. The
reference implementation is this repository: `proof_records/` for the record layer and
`audit/claim_governance/` for the enforcement layer.

## 1. The problem

A computer-assisted proof ships as a paper plus an artefact. The paper carries the mathematics and
the artefact carries the computation, and the join between them — which statement rests on which
computation, and on whose theorem — is carried in prose. Prose is where three distinctions go to
blur:

1. **Derived here against imported.** A step the artefact establishes, and a step taken from the
   literature whose hypotheses the artefact merely checks, read identically in a sentence. They are
   not the same object: the second inherits every hypothesis of its source, including the ones the
   artefact never sees.
2. **Refused against negative.** A method that cannot decide an instance and a method that decides
   it in the negative produce the same absence of a positive result. Reporting them alike is the
   most common way a computer-assisted argument becomes wrong rather than incomplete.
3. **Bounded against general.** Evidence over an enumerated finite domain is a theorem about that
   domain. The sentence that reports it usually is not.

None of this is a failure of rigour by the authors. It is a failure of the medium: there is nowhere
in a LaTeX file for a machine to check that the sentence and the artefact still agree after the
fourth revision.

## 2. The three outcomes

Every procedure in the reference implementation returns one of three things, and the type system
keeps them apart:

| Outcome | Meaning | What it licenses |
| --- | --- | --- |
| accepted | the procedure decided, positively | the statement, on its stated scope |
| refused | the procedure could not decide this instance | nothing, in either direction |
| rejected | the input was malformed, or the procedure decided negatively | the negation, only when the input was well formed |

The discipline is that a refusal is never read as a negative. Three refusals worth naming, all real:

- An exact Pisot screen composed from Schur–Cohn and Routh–Hurwitz refuses `x^3 - 3x^2 - 3x - 3`,
  which is a Pisot polynomial: the Routh array has a zero in the first column of a row that is not
  itself zero, a classical singularity with classical remedies, none of them implemented. The screen
  reports a refusal. Reporting "not Pisot" would have been a false statement about a specific cubic.
- An interval exclusion on a parameter box refuses when the box is too wide to separate two orbit
  iterates. Widening the horizon by one step can turn an accepted box into a refused one; the box
  did not become wrong, the question became harder.
- A bounded graph search that exhausts its state budget refuses. Most inputs to such a search have
  infinite graphs, so an exhausted budget is the expected outcome for them and carries no verdict.

## 3. The record layer

A record is a claim plus the evidence its class requires. Five kinds, with the outcome each can
carry, are specified in `docs/proof-records-specification.md` and implemented in
`proof_records/records.mojo`:

| Kind | Can support a theorem |
| --- | --- |
| verified finite computation — replayable, canonical, digest-carrying | yes |
| imported theorem — named source, hypotheses checked against finite data | yes, once the hypotheses are checked |
| pending dependency — named, unchecked, blocking | no |
| bounded experiment — evidence over an enumerated domain | only its own bounded proposition, on its own scope |
| rejected — malformed or refused, carrying the reason | no |

Two properties matter more than the taxonomy. First, a record's identifier is *verified* against a
preimage that excludes it, so a record cannot claim an identity its content does not determine.
Second, dependency edges carry identity, so the closure of a claim is computable: a claim is
complete exactly when no record in its closure is a pending dependency. That turns "is this proved?"
into a graph query rather than a reading exercise.

The package interprets no statement and ships no policy. What counts as a forbidden primitive, an
open frontier, or an acceptable source is the consumer's, supplied as a predicate.

## 4. The enforcement layer

One policy file per repository (`audit/docs/policy-format.md`, with a worked example in
`audit/docs/example-policy.toml`) drives five checks over prose and source:

- **status vocabulary** — every claim has a declared status from a closed set;
- **promotion** — a claim the prose describes as proved must be proved in the ledger; this is the
  check that catches drift between a sentence and the record behind it;
- **risky phrases** — "essentially the same", "obvious isomorphism", "proof by analogy" and their
  relatives, flagged wherever a declaration is not present;
- **numerics** — no floating point inside a declared exact-arithmetic scope;
- **consistency** — a claim's status agrees across every surface that names it.

The checks run in CI beside the tests, and they are cheap. What makes them useful is not their
sophistication but their placement: they read the same prose a referee reads.

Two incidents from writing this material, as calibration. A sentence describing a census as settling
a family was rejected by the promotion check, because the conjecture that census bears on is open
and the sentence sat near its name — the sentence was rewritten to say what the census reports. And
an edit to an exact-arithmetic kernel was rejected by a digest check, because that kernel is
vendored from another repository and must stay byte-identical; the function moved to a consumer
module instead. Neither was a deep error. Both would have survived review.

## 5. Adopting it elsewhere

Four steps, none of which requires the mathematics of the adopting project:

1. Give every procedure three outcomes rather than two, and make the refusal carry a reason.
2. Record each computation as a record with its scope, its replay command, and the digest of its
   inputs and outputs. Scope is the field that prevents a bounded experiment from reading as a
   theorem.
3. Name every imported theorem, with its source and the hypotheses the artefact actually checked.
   The unchecked hypotheses are the interesting part of the record.
4. Write one policy file and run the checks in CI. Start with the promotion check; it pays for
   itself first.

Generating the ledgers from the record table rather than maintaining them by hand is the fifth step,
and the one that makes the first four stay true. `pixi run ledgers` shows the shape.

## 6. Non-claims

Governance proves nothing. It does not make a computation correct, a source correctly applied, or a
bounded experiment general. It makes the provenance of an assertion checkable by a machine, so that
the reader's remaining work is the mathematics rather than the bookkeeping. A repository that passes
every check above may still be wrong; it will be wrong in a way that is stated rather than implied.
