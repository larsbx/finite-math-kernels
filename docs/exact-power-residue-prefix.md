# Exact decimal folds and finite pair-power residues

The reusable Mojo module `kernel/finite_polynomial/pair_power_residue.mojo`
implements two independent, algebraic operations.

**Decimal folds.** `decimal_digit_sum(n)` calculates the base-ten digit
sum and `decimal_alternating_sum(n)` calculates the alternating
units-first sum, both for nonnegative machine integers. The identities
`n ≡ digit_sum(n) (mod 9)` and
`n ≡ alternating_sum(n) (mod 11)` motivate exact residue filters.
There is no decimal-to-floating-point conversion and negative input is
explicitly refused.

**PairPowerResiduePrefix(m,k).** This data structure represents all
residues

`{a^k + b^k mod m : 1 <= a <= b <= c}`

after `c` calls to `advance()`. For each new `b=c`, it uses the
canonical runtime `Modulus` ring arithmetic to add every previously
admissible `(a,c)` pair, including `(c,c)`, without losing collisions.
Membership `contains(t)` is exact; both positive and signed `t`
reduce canonically in `Z/mZ`. Storage is `O(m+c)`; update work is
`O(c)`; membership is constant-time after table construction. The
generic residue filter caps `2 <= m <= 100000` and
`1 <= k <= 64` because `m` entries are allocated. Its finite bounds
are resource policy, not a limit on the algebraic identity.

The kernel is reusable by any Diophantine equation whose left side is
an admissible ordered pair sum. The **consumer** must check the domain
inclusion: membership in the complete prefix is a necessary condition,
not a proof of the original integer equation. A missing residue may
only eliminate candidates when every allowed pair lies in this prefix.

In particular, for `a^5+b^5+c^5+d^5=e^5` with
`1 <= a <= b <= c <= d < e`, the complement
`t=e^5-c^5-d^5` necessarily belongs to
`PairPowerResiduePrefix(m,5)` advanced through base `c`,
for every `m>=2`. This does not require prime modulus or CRT
independence; `m=2475=9*11*25` incorporates decimal digit-sum,
alternating-digit, and last-two-digit congruences through a single
exact composite ring.

This library only supplies the arithmetic. The Euler application owns
the search, witness records, ranking constraints, proof statements,
benchmarks, and decision to reject a candidate.

## Conformance

`pixi run test-pair-power-residue` executes the native Mojo
program and independently reconstructs every reported prefix
cardinality and exact decimal fold in Python. The native probe also
checks every small positive pair and rejection of invalid inputs.
This task is included in the default `pixi run test` gate.

No cryptographic freshness, model of signed fifth-power searches,
larger brute-force coverage, or production speedup follows from this
module alone.
