# Bounded native word counts and issue #97

This correction is proposed for review, not authorization to merge an API
change. It is stacked on the unmerged Lean foundations PR #95 at
`befca03f2fdd25d7b10a5feacc4763f9373db53e`; its narrow review base is that
branch. Main at inspection was `4067c76dfa6cefbba888741c917a510868cb47cf`.
The defect was reproduced historically at
`4fea04f7c2f88707bca8642d01711331dbeac792`.

## Contract decision before implementation

The existing result carrier is `List[Int]`, not `BigZ`. The repository's
`finite_exact.checked_int` contract explicitly permits exact results or
inconclusive refusal when intermediates do not fit. No inspected native caller
documents a requirement to continue past machine bounds with an unbounded
result carrier. Exact certificate predicates require an exact answer when they
succeed; an arithmetic refusal must abort or propagate, never become a zero,
`false`, empty vector, successful certificate or accepted classification.
Python reference counts remain unbounded and are not replaced by native Ints.

The proposal therefore retains arguments, coordinate layout and return carrier,
adding `raises` to **n2, n3, k2 and k3**. This is a source-breaking effect change
for nonraising callers. It introduces `finite_exact.checked_int` as a dependency
of `words.mojo`; subset vendors must include that module. The package index
documents this facade/contract change. Approval is required before merging it.

Every N3 output, prefix pair and prefix letter addition uses `checked_add`;
N2 separately checks output and letter additions. `checked_mul` protects slot
counts before allocation. Valid alphabet symbols and nonnegative alphabet size
remain caller preconditions, as before. Once slot counts fit, valid lexicographic
indices fit too. Allocation failure remains a resource failure, not evidence.
No partial count vector escapes a raising call. K2/K3 propagate the same error.
Subtracting two successful coordinates in `[0, Int.MAX]` lies in
`[-Int.MAX, Int.MAX]`, so it fits without a new subtraction API.

A fitting final K3 difference does not guarantee success: either operand or an
N3 prefix pair may exceed the bound. The regression includes equal oversized
words: their mathematical K3 is zero, but native K3 explicitly refuses. A future
unbounded API would need separate BigZ signatures and caller review.

## Independent bounds and tests

| Fixture | Exact mathematical result | Required native outcome |
| --- | --- | --- |
| Constant length 3,810,778 | 9,223,364,155,031,292,776 triples | Exact value |
| Constant length 3,810,779 | 9,223,371,416,043,870,029 triples | Exact value; last fitting constant length |
| Constant length 3,810,780 | 9,223,378,677,060,258,060 triples | Addition overflow error |
| Constant length 4,000,000 | 10,666,658,666,668,000,000 triples | Addition overflow error |
| Guard result `Int.MAX-1`, `Int.MAX` | 9,223,372,036,854,775,806 / 807 | Exact value |
| Guard result `Int.MAX+1` | 9,223,372,036,854,775,808 | Addition overflow error |

The probe computes no binomial formula. `tools/word_counter_oracle.py` compares
its observations with independent Python `math.comb`/unbounded integer arithmetic.
Both missing and extra cases, blanket refusal of fitting cases, wrong error
types, wrapped values and wrong N2/Parikh results fail. The native compiler must
be present: the aggregate Python suite runs this test without an optional skip.
Lean independently checks the same observations as closed propositions, in
addition to symbolic streaming and partial-machine model theorems.

### Separate N2 and Parikh audit

For constant words, N2 is `choose(n,2)`. At `n=4,294,967,296` it is
9,223,372,034,707,292,160 and fits; the next value is
9,223,372,039,002,259,456 and does not. These bounds are checked in Lean.
No native N2 overflow allocation/execution is claimed: the input alone would
require over 32 GiB. Native N2 values through four million letters are checked
against the oracle. Its preventative addition guards reuse the independently
tested checked-integer primitive. Tests at Int.MAX exercise that primitive,
not an allocated N2 overflow input.

Each Parikh coordinate and letter-prefix counter is at most the processed
length, which is at most the representable `List` length (`Int.MAX`). Parikh's
API and accumulation therefore stay unchanged under valid-word/index
preconditions. N2/N3 letter increments are checked defensively. Neither an N2
nor a Parikh wraparound is claimed to have been reproduced.

## Local caller inventory

All canonical source, test and tooling files were searched for definitions,
imports and calls; no alias imports or additional production consumers exist
in this repository at the review base.

| Caller | Contract and action |
| --- | --- |
| `words.mojo:k2`, `words.mojo:k3` | Exact differences or propagated error; signatures gain `raises`. |
| `test_substitution_dynamics.mojo:test_generic_streaming_counts` | Small finite N2/N3 fixtures; already raising; no interface edit. |
| `test_substitution_dynamics.mojo:test_pairs_and_invariants_over_two_letters` | Finite K2/K3 checks; already raising; no interface edit. |
| `tests/lean/native_transcript.mojo:word_case` | Fresh finite outputs, no refusal expected for these inputs; gains `raises`, propagated to already-raising main. |
| `tests/lean/word_counter_overflow.mojo` | Replaces historical diagnostic with explicit observed values/errors; main and helpers propagate unexpected failures. |
| `tools/run_kernel_lean_verification.py` | Requires new stress refusal and accepted boundary cases; retains historical source provenance rather than expecting wrapped output. |

## Downstream caller inventory

PSC was inspected at `a7dcc6744fd60b7be5894fe625384412e91800e3`.
The complete direct call-site list, including enclosing signatures, is in
`conformance/word-counter-fix/psc-callers.json`. These are affected on a future
re-vendor, not modified in this PR. Existing downstream pins stay unchanged.

| PSC callers | Required migration / interpretation |
| --- | --- |
| `psc/words.mojo:n2,n3,k2,k3` | Four nonraising wrappers gain `raises`. A native compile probe confirms current n2/n3 wrappers reject the proposed package. |
| `psc/certificate.mojo:run_all` | Nonraising certificate runner: propagate/abort refusal, never accept a partial check list. |
| `psc/defect_degree.mojo:first_defect_degree,is_degree3` | Nonraising degree predicates: propagate refusal; cannot map it to a degree or false. Its separate N4 arithmetic is outside this repair. |
| `psc/degree3_taxonomy.mojo:commutes_with_theta,Degree3Summary.__init__` | Nonraising exact matrix/classification paths: propagate errors through their callers. |
| `degree3_catalog.mojo:is_first_degree3_component` | Nonraising census predicate: propagate error rather than classify. |
| `wedge_productivity_catalog.mojo:has_nonzero_k2` | Nonraising census predicate: propagate error rather than classify. |
| `psc/c4_physical_hub_area.mojo:weighted_hub_profile` | Already raising; retain exact checked-area comparison and propagate refusal. |
| [test_words_streaming.mojo](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/a7dcc6744fd60b7be5894fe625384412e91800e3/kernel/tests/test_words_streaming.mojo), [test_kernel.mojo](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/a7dcc6744fd60b7be5894fe625384412e91800e3/kernel/tests/test_kernel.mojo), [test_census_library.mojo](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/a7dcc6744fd60b7be5894fe625384412e91800e3/kernel/tests/test_census_library.mojo), [test_c4_recurrent_flat_exits.mojo](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/a7dcc6744fd60b7be5894fe625384412e91800e3/kernel/tests/test_c4_recurrent_flat_exits.mojo) | Existing finite tests already raise; update wrappers first and rerun downstream acceptance. |

Full Mojo source searches found no direct N2/N3/K2/K3 calls in the known
consumers finite-mandelbrot (`6b3e213ef66af8980427116e61e2cb704d1b6ce3`),
mandelbrot-bulbs-and-ford-circles (`70e9920a00b553a3e32649b7054cf45ff5fa51d1`),
and math-vizops (`ab2bf4a830b98bdc700a04c7b8ef6bbe4d070ef6`).
The finite-julia-set checkout was unavailable to the connected account, and
its source audit remains outstanding. This is a source audit of known consumers, not
a guarantee about uninspected external/private users. Public effect changes and
the new dependency require explicit re-vendoring and re-pinning downstream.

## Reproduction

```sh
pixi run mojo run -I kernel tests/lean/word_counter_overflow.mojo > /tmp/counts.jsonl
python tools/word_counter_oracle.py < /tmp/counts.jsonl
pixi run test-substitution
pixi run test
python tools/run_kernel_lean_verification.py --expected-revision FULL_SHA --output /tmp/count-lean
```

The Lean gate requires the pinned toolchain and Mathlib, a clean exact revision,
and audits all model declarations for standard axioms. Its evidence is model
proofs and finite native conformance; complete Mojo/compiler refinement remains
open. Exact accepted revision and environment details accompany the PR evidence.
