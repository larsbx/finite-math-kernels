# Lean verification of canonical kernels

This is the upstream verification layer requested after PSC PR #503. The earlier
Lean-MAX demo is an independent experiment, not coverage of these kernels.
The new project lives in `tests/lean/`, within the existing evidence plane;
Mojo remains the canonical executable implementation. No facade, consumer pin,
governed claim status, or theorem dependency is promoted by adding proof source.

## First acceptance slice

| Area | Deductive scope | Native linkage | Remaining boundary |
| --- | --- | --- | --- |
| Words | Generic finite words over any alphabet; Parikh addition; streaming pair/triple counter invariant | Exhaustive small words on alphabets 1–4, plus a 13-letter indexing control | Mojo memory/index representation and machine count bounds |
| Substitutions | Concatenation, iteration, incidence/Parikh law, balance preservation, equal image lengths, nonerasing witness propagation | Literal inflation, row-major incidence and prefix lengths | Constructors, resource limits, all imperative loops and complete decomposition |
| Checked integers | Accepted result exactness; addition/subtraction/negation/absolute-value guards; natural-magnitude division guard | All five operations on signed edge controls | Full signed/unsigned multiplication guard and compiler refinement |
| Accepted fields | Sticky rejection, zero-division refusal, nonzero inverse/cancellation over any field; Rat and prime ZMod instances | Fp[7] operations, canonical residues, zero division and rejected equality | BigZ/Q representation, primality/modular/Euclidean algorithms |

The streaming proof uses induction over arbitrary words and symbolic counters.
Natural-number word counts are unbounded mathematical values. The native
`words.mojo` counters use machine Int and do not automatically inherit an
unbounded guarantee: every relevant intermediate must fit. Native transcripts
are finite differential controls, never a universal implementation proof.

## Complete inventory and next obligations

`tests/lean/coverage.json` lists every canonical Mojo module, including uncovered
ones, its model declaration bindings, native lane and explicit remaining
obligations. Every implementation-refinement status remains open. Regenerate
with `python3 tools/kernel_lean_inventory.py`; check with its `--check` option.

The next milestones are BigZ denotation/canonicality and truncating division,
Q normalisation, rational interval enclosure, integer/matrix guards, finite
graph SCC certificates, and automata language/search soundness. The inventory
also tracks polynomial, orbit, projective, record and parallel packages so
untouched areas cannot disappear behind a green foundational gate.

## Replay and evidence

Kernel acceptance is pending the first exact-head hosted run. The local runtime
downloads the pinned release but its Lean launcher reports “failed to locate
application”; no local Lean pass is claimed. A local Pixi installation attempt
also hit a conda-forge HTTP 429 and is not evidence of native execution.

```sh
bash tools/setup_kernel_lean.sh
export PATH="$HOME/.elan/bin:$PATH"
python3 tools/run_kernel_lean_verification.py --expected-revision FULL_COMMIT_SHA --output /tmp/kernel-lean
python3 -m unittest discover -s tests/lean -p 'test_*.py'
```

Lean and Mathlib are pinned, matching the accepted PSC source-word layer.
The runner requires a clean matching revision and hashes mathematical sources,
native sources and replay tooling. It copies only proof sources/configuration
into a fresh workspace, builds the models, and translates 373 fresh native
records into closed Lean propositions checked by the kernel. All named model
proofs have an axiom audit allowing only propext, Classical.choice and Quot.sound.
Wrong Parikh counts, wrapped overflow and rejection-equals-true are separate
negative Lean controls. Receipts retain exact versions, commands and logs.

Pinned Lean/Mathlib and provisioned dependency artifacts are explicit trust
inputs. The native compiler and fixture producer are not assumed mathematically
correct: their observed outputs must pass Lean, but only at those finite inputs.
This is not a verified Mojo compiler or a proof of every kernel implementation.

## Scope and integration

No package facade changes. No vendored bytes or downstream pins are changed.
No PSC family theorem or overlap certificate is imported upstream. The generic
word model is alphabet-independent; downstream reuse and replacement of PSC's
local generic lemmas is a later, explicit integration step.

The six existing repository gates remain required and are reported separately
in the PR evidence table. This focused gate supplies no all-repository green
claim and no general PSC, pure-discreteness or geometric conclusion.
