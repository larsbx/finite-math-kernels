# Weighted cycle-gain kernel research scaffold

## Purpose

Provide domain-neutral exact machinery for finite directed graphs carrying additive edge labels.

The motivating consumer is the post-PSC Growth Bridge programme, but this package must not encode PSC, Penrose, tilings, eigenvalues, or spectral claims.

## Proposed objects

- `WeightedEdge[T]`: source, target, exact additive gain;
- `WeightedDigraph[T]`: finite complete graph container with fail-closed validation;
- `CycleBasis`: deterministic cycle basis for a selected recurrent component;
- `CycleGain[T]`: exact sum of edge gains around a closed cycle;
- `GeneratedModule`: exact finitely generated subgroup/module presented by cycle gains.

The initial scalar backend should be chosen from existing exact finite algebra. Do not add a second rational or integer implementation.

## Required properties

1. cycle gains are exact and order-sensitive;
2. changing the cycle basis does not change the generated subgroup/module;
3. capped or incomplete graphs are rejected rather than interpreted;
4. deterministic vertex/edge order yields deterministic fixtures;
5. the kernel reports finite algebra only and attaches no theorem meaning to the result.

## Planned API slice

```text
cycle_basis(graph, component) -> CycleBasis
cycle_gain(graph, cycle) -> T
cycle_gains(graph, basis) -> List[T]
generated_module(gains) -> GeneratedModule
same_generated_module(a, b) -> Bool
```

The exact module representation is an implementation decision. For integer coordinate lattices, Hermite or Smith normal forms are natural candidates and should be benchmarked before the interface is frozen.

## Tests

The first tests should include:

- a tree plus one back edge: one generator;
- two different cycle bases for the same graph: same generated module;
- repeated parallel edges with different gains: multiplicity preserved;
- a zero-gain cycle mixed with nonzero cycles;
- disconnected and non-strongly-connected inputs;
- malformed cycle and incomplete graph rejection.

## Consumer boundary

PSC owns the map from its exact arithmetic state to integer/rational coordinate vectors. This kernel only receives validated finite coordinates.

Julia may independently recompute the same finite result, but its result is advisory.

## Promotion gate

Do not claim a reusable theorem until the representation and basis-independence tests are in place. The first implementation PR should contain the exact kernel plus deterministic tests, not domain-specific Growth Bridge language.
