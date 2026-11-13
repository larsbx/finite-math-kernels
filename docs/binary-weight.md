# Binary digit weight

`tests/lean/FiniteMathKernels/BinaryWeight.lean` defines the weight of a natural
number as the sum of its ordinary base-two digits:

\[
W(n)=\sum \operatorname{Nat.digits}(2,n).
\]

Zero has the empty digit list and weight zero. This definition uses Mathlib's
existing natural-number digit API. It does not introduce an alternative native
integer package, change any Mojo facade, or claim implementation refinement.

## Universal arithmetic contracts

The module proves the following for all natural-number inputs:

| Operation | Contract |
| --- | --- |
| Low zero bit | \(W(2n)=W(n)\) |
| Low one bit | \(W(2n+1)=W(n)+1\) |
| Successor | \(W(n+1)\le W(n)+1\) |
| Addition | \(W(m+n)\le W(m)+W(n)\) |
| Binary shift | \(W(2^kn)=W(n)\) |
| Dropping low bits | \(W(\lfloor n/2^k\rfloor)\le W(n)\) |
| Consecutive low ones | \(W(2^k-1)=k\) |
| Square | \(2W(n^2)\le W(n)(W(n)+1)\) |

The square proof uses binary induction. An even input only shifts the square.
For an odd input, the exact identity

\[
(2n+1)^2=4(n^2+n)+1
\]

reduces the step to the addition bound and the induction hypothesis. The factor
two in the statement avoids truncated division. The example \(n=5\), whose
square is \(25\), attains equality: \(2\cdot3=2(2+1)\).

The addition inequality can be strict because of carries: \(W(1+1)=1<2\).
Dropping bits can also lose weight: \(W(7/4)=1<3=W(7)\). These examples are
retained as compiled positive controls, while attempted proofs of the stronger
equalities are required to fail.

## Literature and mathematical scope

Bailey, Borwein, Crandall and Pomerance, *On the binary expansions of algebraic
numbers*, [author manuscript](https://www.davidhbailey.com/dhbpapers/algebraic-bits.pdf),
Lemma 4.1 and Theorem 4.2, give the classical shift and addition weight bounds.
Their Section 5 applies binary weight to algebraic-number digit sparsity.
The present square estimate is proved directly here; no priority claim is made
for this refinement or these elementary arithmetic facts.

This upstream module is independent of any particular real number. It proves no
normality result, no asymptotic digit distribution, and no native BigZ or compiler
refinement. A downstream application must separately connect an integer to the
correct source prefix before using these inequalities.

## Focused acceptance

The focused gate requires an exact clean source revision. It checks all pinned
Lake package revisions, the exact Lean toolchain version, source and executable
hashes, and fresh compilation into an empty output directory. It never places
an existing project olean on `LEAN_PATH`.

```sh
LEAN_BIN=/absolute/path/to/lean \
FMK_MATHLIB_PACKAGES=/absolute/path/to/pinned/.lake/packages \
python3 tools/verify_binary_weight.py \
  --expected-revision FULL_SOURCE_COMMIT_SHA \
  --output .build/binary-weight-acceptance
```

Three modules are compiled: the arithmetic proofs, twelve explicit public type
wrappers, and twelve positive control statements. The gate audits every compiled
declaration from each module, including generated helpers, and collects all
transitive proof assumptions. Only `propext`, `Classical.choice`, and `Quot.sound`
are permitted. It prints the twelve wrapper types and requires each expected
named theorem to be present as a compiled theorem.

Isolated negative controls reject a wrong weight, addition equality, division
equality, the stronger square bound, and a weakened replacement for the universal
square type. Two additional controls compile an injected assumption and require
the compiled audit to reject both the local assumption and a theorem that uses
it through another module. Each rejection must have the intended diagnostic;
an arbitrary compilation failure does not count as acceptance.

`report.json` records the exact source revision and tree, source hashes, dependency
revisions, compiler hash and version, commands, compiled theorem types, complete
assumption inventory, control outcomes and artifact hashes. It checks source,
revision, dependency and compiler identities again before acceptance. A separate
evidence-only child commit may preserve that report without changing which source
revision it checked.

The six repository-wide gates in `AGENTS.md` remain separate. This focused result
does not turn a missing optional toolchain or a failure elsewhere into a pass.
