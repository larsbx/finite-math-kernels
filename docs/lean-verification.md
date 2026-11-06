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

## Historical counterexample and bounded correction

[Issue #97](https://github.com/larsbx/finite-math-kernels/issues/97) records an
executed counterexample at the unchanged native source revision
4fea04f7c2f88707bca8642d01711331dbeac792:

| Input / result | Value |
| --- | --- |
| Word | 4,000,000 copies of letter 0; alphabet size 1 |
| Exact scattered triples | 10,666,658,666,668,000,000 |
| Signed Int maximum | 9,223,372,036,854,775,807 |
| Observed native N3 | -7,780,085,407,041,551,616 |

At that historical revision the native routine returns a wrapped count without refusal. The general Lean
constant-word lemmas derive the binomial count for arbitrary lengths; the
closed stress case proves that this exact value cannot fit and that the observed
negative integer cannot represent a scattered-triple count. Replay with
`pixi run mojo run -I kernel tests/lean/word_counter_overflow.mojo`.

The corrected native routine checks every triple/pair/letter addition and
dimension product, propagating errors through K3. N2 has its own checked
accumulation; Parikh counts are bounded by representable list length. See the
[contract and affected callers](word-counter-bounds.md). The same probe path
now emits 19 boundary, stress, dimension and propagated-refusal observations;
the runner checks these against Python arbitrary-precision binomials and
independently checks their translated propositions in Lean. It requires refusal
at four million letters, not the historical wrapped value. Existing archived
receipts and logs retain their original source revision and are not rewritten.

`MachineWords.run` is a partial semantic model distinct from the unbounded
`Words.stream`. `run_success_exact` and `stream_success_exact` establish that
accepted summaries equal mathematical counts; `run_complete_iff` and
`run_refuses_iff` expose the explicit `Within` precondition on every intermediate.
`difference_fits` justifies subtraction of successful nonnegative operand
counts. This model checks exact unbounded steps before admitting them; native
code checks individual additions before execution. Relating those representations,
imperative loops and compiler behavior is still an open refinement obligation.
No N2 overflow execution is claimed; its large-input bound is a separate Lean
calculation, and ordinary N2/Parikh results are checked by native controls.

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

**Local acceptance at exact revision `326ac9599e957c3d60286be23cec7c341565d581`:**
61 named model proofs passed the Lean kernel and standard-axiom audit; all 373
finite native records passed their Lean propositions; all four false controls
were rejected. The known N3 overflow was separately reproduced and retained.

Permanent evidence is in [the receipt](../conformance/lean/receipt-326ac959.json),
[axiom output](../conformance/lean/axioms-326ac959.log),
[native transcript](../conformance/lean/native-326ac959.jsonl), and
[runtime context](../conformance/lean/runtime-context-326ac959.json).
The local runtime needed the disclosed executable-path compatibility shim in
that context record: it redirects only the current process's failed
`/proc/<pid>/exe` lookup to `/proc/self/exe`. The Lean binary, kernel, proof
sources and dependency versions are unchanged; the shim source, library hash
and exact compiler invocation are retained for independent assessment.

[Standard hosted run 42223221102](https://github.com/larsbx/finite-math-kernels/actions/runs/42223221102)
remains queued. No hosted acceptance of this exact source is claimed.
The earlier hosted aggregate, estate, polyglot, Julia and RT gates passed at
`1e6212da5514181b9843727c1497e62ee3d71e46`; those are separately scoped in the
runtime context. The local aggregate exited zero with six optional frontier
skips; local polyglot failed because Bend is absent. Audit (114), provenance (7),
reference checks, the 300-integer/200-rational property oracle and all ten new
admission/inventory/report-parser tests passed.

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
negative Lean controls. A fourth rejects a noncanonical field representative
even when it is equal modulo p. Division candidates are checked by proving
result times denominator equals numerator with a nonzero denominator; a generic
field lemma supplies the division equality. This avoids trying to execute
Mathlib's non-reducible field-inverse definition, and adds no proof assumption.
Receipts retain exact versions, commands and logs.

Pinned Lean/Mathlib and provisioned dependency artifacts are explicit trust
inputs. The native compiler and fixture producer are not assumed mathematically
correct: their observed outputs must pass Lean, but only at those finite inputs.
This is not a verified Mojo compiler or a proof of every kernel implementation.

## Scope and integration

The word API signatures and dependency description change as documented in the
caller audit. No vendored bytes or downstream pins are changed by this repair.
No PSC family theorem or overlap certificate is imported upstream. The generic
word model is alphabet-independent; downstream reuse and replacement of PSC's
local generic lemmas is a later, explicit integration step.

The six existing repository gates remain required and are reported separately
in the PR evidence table. This focused gate supplies no all-repository green
claim and no general PSC, pure-discreteness or geometric conclusion.
