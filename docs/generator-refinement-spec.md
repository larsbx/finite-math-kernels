# The input distribution of a generator: specification

**Status:** specification of `tools/refinement.py`, round-three item R9 of `docs/cross-pollination-round-three-2026-09-17.md` (transfer C1, the codomain refinement `φ_G` that `larsbx/meta_test` requires of every generator). It states no mathematics. It says what a differential or property oracle draws from, so that the strength of a comparison is a declared object rather than an accident of how the test was written.

## 0. Why a corpus needs a declaration

This repository has paid twice for not having one, both times in the same oracle.

The M-adic carrier formed `a[i] - b[i]` in 64-bit `Int` before lifting to `Q`. That subtraction wraps, and the wrapped difference can fail to be divisible by `M` where the true one is, so the carrier issued a false separation certificate — the one thing it exists to certify. It survived a differential run of 1200 checks over twenty matrices. The Python oracle was right throughout, because Python integers are unbounded; the comparison simply never asked, since **every coordinate the run generated lay in `[-9, 9]`**, where the wrap is unreachable.

The same run missed a second defect: `qmat_pow(m, 0)` is the identity whatever `m` was, so a singular `M` went undetected at level zero and every correctly sized delta read as a member. It survived because **no matrix in the corpus was singular**.

Neither model was wrong. Neither corpus was wrong either — both were *silent*, and a silent corpus is indistinguishable from a thorough one at the point where you read the green result. A declaration is what makes the difference visible before the defect is.

## 1. What a refinement declares

A `Refinement` is `φ_G` for one generator, and it makes two claims a run can refuse.

| Field | Meaning |
| --- | --- |
| `name` | the generator, as a reader would name it |
| `codomain` | prose: what the generator claims to produce |
| `holds` | the predicate every drawn value must satisfy |
| `classes` | named regions of the codomain, each **reached** or **missed** |

A `Class` carries a `name`, a predicate, and a `reason`. An empty `reason` marks a class the corpus **must** witness. A non-empty one marks a class the corpus is declared **not** to reach, and states why.

## 2. Both directions are checked

`audit` reports, in declared order:

| Finding | Meaning |
| --- | --- |
| `produces a value outside its codomain` | the generator escaped its own declaration |
| `declares it reaches X and no draw of N does` | the corpus is weaker than the declaration says |
| `declares it misses X (reason) and a draw does` | the declaration is stale and must be revised |

The third row is what keeps the second honest. Without it, "declared missed" would be a way to dismiss a gap; with it, a declaration that stops being true fails the run, so a gap can only be closed deliberately.

A class is a region **of the codomain**, so class predicates are evaluated only over values that satisfied `holds`. One malformed draw is reported once, rather than turning every class into an error.

## 3. Declaring a gap is not dismissing it

Each missed class states the branch it leaves unexercised, and `tests/refinement/test_refinement.py` requires the reason to be substantive. The declarations this repository ships, for the exact-arithmetic property probe, record three:

| Generator | Missed | What goes untested |
| --- | --- | --- |
| `random_int` | `zero` | the `Z` division-by-zero branch of the transcript grammar |
| `random_int` | `a unit` | the sign and gcd edges at ±1, outside the known-answer suites |
| `random_fraction` | `zero` | the `Q` division-by-zero branch |
| `random_fraction` | `integer-valued` | canonicalisation to denominator one |
| `random_interval` | `degenerate` | the point-interval reciprocal and sign paths |

These are not defects. They are the parts of the grammar the property probe does not reach, written down, so that the next reader sees a stated boundary rather than a green result. Closing them means changing the generator in `tools/property_oracle.py` **and** `tests/finite_exact/property_probe.mojo` call for call, which changes every line of the transcript and the copy `larsbx/interval_q` vendors; that is a separate change, not a side effect of declaring the gap.

## 4. Where the declarations live

Beside the generator, not beside the model: the corpus is what is being described.

| Declaration | Generator |
| --- | --- |
| `tools/property_oracle.py`: `INTEGER`, `FRACTION`, `INTERVAL` | the xorshift stream the exact-arithmetic probe and its oracle share |
| `tests/finite_linear_algebra/test_madic_oracle.py`: `COORDINATE`, `LATTICE` | the M-adic corpus, widened so it reaches the wrap boundary and contains a singular lattice |

The layer split is part of the declaration: `finite_exact` prints no interval case, so `INTERVAL` has no corpus to judge and is not asserted against an empty one; `larsbx/interval_q` runs the layer and it is.

## 5. Fail closed

`property_oracle.py` checks the declaration **before** the comparison it qualifies, and exits 1 when the corpus has departed from it, because a differential result carries no more weight than the corpus behind it. `--distribution` reports `φ_G` alone, which needs no `mojo` on the path.

## 6. Non-claims

- A declaration is a statement about a corpus, not about the implementation under test. A corpus that meets every declared class is not thereby adequate; it is adequate in the ways somebody thought to declare.
- `meta_test` is a normative specification whose implementation is not authorized and whose S0 is blocked. Nothing here runs any part of it, and `φ_G` is used as a requirement borrowed from a document, not as a tool imported from a working system.
- The M-adic corpus reaches the wrap boundary because a defect once lived there. That it now does is evidence about the corpus, not about the absence of other defects elsewhere in it.
