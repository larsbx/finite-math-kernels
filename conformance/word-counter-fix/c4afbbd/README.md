# Native word-counter overflow correction: exact-source evidence

Validated source: `c4afbbd5e7a069fe578aea45700820c272594cc8`.
Source tree: `305702269b67e0a279162c472eb7f2c8ed32db80`.
Review: [draft PR #98](https://github.com/larsbx/finite-math-kernels/pull/98),
stacked on unmerged PR #95. No merge or downstream re-vendor is performed.
The evidence branch adds only this archive and generated provenance; the
correction PR's source head remains the exact tested revision above.

| Check at validated source | Result / evidence |
| --- | --- |
| Aggregate `pixi run test` | Exit 0; clean start and finish. [Receipt](aggregate-receipt.json), [log](aggregate.log). Python lane: 1,813 passed, 2 skipped. Frontier: 109 passed, 16 skipped, 16 subtests passed. Native suites completed. Optional skips are not acceptance of absent hardware/dependencies. |
| Lean named model declarations | 69 accepted; axiom audit permits only propext, Classical.choice and Quot.sound. [Receipt](lean/receipt.json), [audit](lean/axioms.log). Full implementation refinement remains open. |
| Fresh native-to-Lean small controls | 373 cases accepted. [Native transcript](lean/native.log), [Lean propositions](lean/NativeReplay.lean). |
| Counter boundaries and refusal | 19 native cases agree with the independent arbitrary-precision oracle and pass closed Lean checks. [Observations](lean/counter-boundaries.log), [Lean propositions](lean/CounterReplay.lean). |
| False Lean controls | Four rejected specifically because their propositions are false; each retained log contains the Lean `decide` rejection. |
| Claim audit | 114 passed. [Log](test-audit.log). |
| Provenance | 7 passed. [Log](test-provenance.log). The modified word source retains its historical attribution. |
| References | All path/task references in 457 files resolve. [Log](references.log). |
| Independent property oracle | 300 integer and 200 rational cases passed. [Log](property.log). |
| Lean transcript/inventory/admission tools | 13 tests passed. [Log](test-lean-tools.log). |
| Separate polyglot lane | Exit 127: Bend absent locally. [Log](polyglot-missing-bend.log), [receipt](polyglot-receipt.json). No successful local polyglot acceptance claimed. |

The retained stress input is four million equal letters: its mathematical N3
count is 10,666,658,666,668,000,000 and native N3 now refuses with a checked
addition error. At 3,810,779 letters it returns 9,223,371,416,043,870,029;
at 3,810,780 letters it refuses. Adjacent Int.MAX addition results, nonzero
letter indexing, K3 propagation in either operand and equal oversized words,
and overflowing dimensions are separately tested. No N2/Parikh overflow
execution is claimed; N2's theoretical bound and fitting native N2/Parikh
outputs are separate evidence.

The new partial-machine model is distinct from the unbounded natural-number
word model. Its exactness/completeness/refusal theorems require fitting
intermediates; source arrays, imperative loops, checked-operation binding and
compiler behavior are still open refinement obligations.

The local Lean execution uses the same disclosed executable-path shim as
earlier PR #95 validation. It redirects current-process `/proc/PID/exe`
lookup to `/proc/self/exe`, without changing the Lean binary or proof sources.
Its full source, compilation command and source/library hashes are retained in
[runtime context](runtime-context.json). Pinned dependency artifacts and this
shim are explicit local trust inputs. Standard hosted execution uses no shim.

At the recorded inspection, all four hosted source runs were queued: Lean
[42268160923](https://github.com/larsbx/finite-math-kernels/actions/runs/42268160923),
CI [42268160875](https://github.com/larsbx/finite-math-kernels/actions/runs/42268160875),
polyglot [42268160885](https://github.com/larsbx/finite-math-kernels/actions/runs/42268160885),
and Julia [42268160894](https://github.com/larsbx/finite-math-kernels/actions/runs/42268160894).
No hosted acceptance at this source is claimed.

The public effect changes require approval before merge: n2, n3, k2 and k3
gain `raises`. The source contract/caller audit identifies local callers and
PSC wrappers, certificate and degree/census paths. PSC and three other known
consumers were inspected; finite-julia-set source access was unavailable.
Downstream wrappers must propagate refusal rather than convert it to false,
zero, an accepted degree or a successful certificate. Consumer pin changes
and downstream migration acceptance remain future work.

[SHA-256 manifest](sha256.json) covers every evidence file except itself.
