# Quadratic beta carry: remaining proof ladder (2026-11-28)

Status: route-specific closure plan, not a certificate or a claim promotion. Base: [merged carry contract](beta-numeration-carry-contract-2026-11-27.md), [PR #101](https://github.com/larsbx/finite-math-kernels/pull/101), merge b4d1c4f74b389d426432fb9f7447c2bdda69e0c6. The [PSC golden-base specialization, PR #660](https://github.com/larsbx/pisot-substitution-conjecture-research/pull/660) is a separate result for m=1; it is neither uniform carrier certification nor native refinement.

## Target and non-negotiable boundaries

For each integer m >= 1, beta > 1 with beta^2 = m beta + 1, r = 1/beta, and digit alphabet {0,...,m}, retain exact integer coordinates (a,b) for a+b beta. The transition is (b+d-e,a+mb). The seven-state set is (0,0), +/- (1,0), +/- (-m,1), +/- (1-m,1). No minimality assertion.

- Finite equal-length words: start zero, stay in the carrier, end zero.
- Infinite words: stay in the carrier at every prefix; no terminal-zero or recurrent-zero requirement.
- Infinite collision: additionally some digit pair differs. Divergence is sticky and based on digits, never edge identity.
- For finite labeled graphs with all infinite paths allowed, search for a reachable nonempty directed cycle at a divergent product vertex. Other omega acceptance conditions are out of scope.
- Malformed input and overflow or resource refusal must not be conflated with mathematical rejection, inequality or absence of a collision. No floating-point comparison.
- No PSC, normality, general univoque classification or general Pisot decidability novelty claim. No consumer pin, facade or claim-ledger changes in this plan.

## Evidence baseline (not upstream acceptance)

Two unpublished local source overlays were reported in the November 27 work. The second contains four Lean module candidates (BetaCarry, BetaCarryBase, BetaCarryLasso, BetaCarryGraph; 33 theorem declarations), an exact Mojo candidate, Python oracle, replay tools and an integration helper. Those files and their logs are not committed by this PR. Reported local checks: 21 Python test methods and four integration-helper fixture tests passed, covering 41,472 lattice comparisons, 87,696 digit transitions, 174,456 finite pairs, 410 graph cases (36 positive witnesses), and 64 parametric metallic-base witnesses. The corpus overlaps the earlier increment; do not add counts as independent samples. Native transcript checks used synthetic Python output. No Lean or Mojo compiler was available and cloning failed at DNS resolution. Treat these as reported candidate evidence only, not reproducible repository evidence until the source and receipts are admitted. The static source scan is not a Lean proof check.

## Dependency-ordered closure ledger

Every row below remains OPEN for upstream acceptance. A mathematical derivation, a compiled model, finite differential testing and implementation refinement are distinct evidence grades.

| ID | Prerequisites | Obligation | Required closure evidence |
| --- | --- | --- | --- |
| BC0 | contract | Recover and review candidate bytes against current main; pin toolchains and base revision; review integration helper; register provenance and proof inventory. | Exact source hashes, clean revision, no unrelated edits; reproducible focused command. |
| BC1 | BC0 | Uniform root and two embeddings: r^2+mr=1, 0<r<1, beta=m+r; integer recurrence and injectivity (irrational beta). | Lean builds with arbitrary m>=1, standard axiom audit, no proof escapes. |
| BC2 | BC1 | Valuation summability and prefix/tail identity; strict conjugate bound from zero; exact lattice classification and converse bounded-carry limit. | Lean proves all-m/all-stream equality iff every prefix is in the carrier; strict endpoint controls. |
| BC3 | BC1, BC2 | Finite terminal-zero iff equality and sticky divergence iff digit streams differ. | Lean finite-word and infinite-stream statements kept separate; golden and metallic negative controls. |
| BC4 | BC2, BC3 | Labeled product path correspondence and reachable divergent nonempty lasso iff a pair of distinct equal-value streams exists. | Lean proof of both directions, finite pigeonhole/repetition, actual labels, initial vertices and product state closure; bound 14 times left vertex count times right vertex count. |
| BC5 | BC1, BC3 | Compile canonical Mojo transition/finite acceptance and prove accepted arithmetic exactness; refuse overflowing intermediate/index operations and malformed input. | Native edge and signed-boundary transcript, independent Python verification, review machine representation and checked operations. |
| BC6 | BC4, BC5 | Reachable-product construction: exact valid successors, sticky divergence, completeness of expansion, preserved edge IDs; bounds on all indexing and allocation. | Lean executable/relational model and invariant linking native data to product vertices and edges; differential controls for parallel edges and malformed graphs. |
| BC7 | BC6 | SCC/cycle search completeness and soundness, including singleton self-loops, reachable versus unreachable cycles, and reconstruction of a nonempty labeled return path. | Prove search invariants or use a certified alternative with explicit native correspondence. A no-collision result requires exhaustive reachable search; exhausted budgets are inconclusive. |
| BC8 | BC6, BC7 | Witness checker and end-to-end refinement: positive output maps to BC4 certificate; completed negative output excludes BC4 certificate; refusal carries no decision. | Independently replay original edge IDs, labels, exact carry and sticky state at cycle cut; formal model-to-native linkage and explicit remaining compiler/memory trust assumptions. |
| BC9 | BC5-BC8 | Fresh native differential replay, adversarial controls, full repo gates, provenance and exact revision receipts. | Native-generated records (not synthetic); independent polynomial/periodic valuation oracle and graph verdicts; fail closed on wrong, missing, extra or truncated records; exact toolchain/revision and logs. |
| BC10 | BC1-BC9 | Review route closure, inventory and documented scope; separate any consumer integration proposal. | Reviewed upstream commit and evidence; no automatic consumer pin or theorem promotion. |

BC1-BC4 are candidate proof sources, not checked declarations. BC6-BC8 are the remaining algorithm/refinement proof work, not supplied by an SCC test or by BC4 alone. BC5 and BC9 require actual native execution. BC0 is the immediate next action; compile BC1-BC4 first while preparing BC5, then close BC6-BC8.

## Required controls

- Uniform finite collision 100 = 0m1 and infinite collision 10^omega = (0m)^omega (m is one digit). For m=1 the infinite pair avoids 11 yet is nonunique; it never returns to zero after divergence.
- Reject a witness with the correct value but a cycle cut before divergence; reject fabricated labels even if edge IDs are valid. Identical streams with different parallel edge IDs do not collide.
- Check all digit pairs per tested m, strict conjugate endpoints, malformed digits/graphs, out-of-carrier steps, signed-coordinate overflow and graph/index budgets.
- Include empty/dead-end graphs (no infinite path), unreachable cycles, singleton self-loop, reachable cycle before divergence only, divergence in a prefix followed by a cycle, and unequal finite lengths. Test resource exhaustion separately from mathematical negative cases.
- Exact periodic valuation checks must be independent of the carry recurrence (polynomial arithmetic and rational cross multiplication); finite controls never prove all streams.

## Acceptance and ownership

Follow [Lean verification](lean-verification.md): pinned Lean/Mathlib, declaration and standard-axiom audit, inventory regeneration and revision-bound native correspondence. A new focused Pixi task is a candidate until it exists on main; run the focused lane and then the existing aggregate test, test-audit, test-provenance, references, property, test-polyglot and Lean lane. Record each exit status, skips and environmental failures separately; never claim green for an unrun gate. Regenerate provenance and coverage inventories from the actual tracked sources. Do not promote model proofs to native refinement on finite evidence alone.

Only after BC10 may the PSC and golden-ratio normality consumers consider separate reviewed pin/vendor changes. This route provides constrained equal-valuation collision machinery, not a proof of either consumer's central conjecture.

This PR is documentation and provenance only. It publishes the closure ladder, not the unpublished candidate implementations or receipts.
