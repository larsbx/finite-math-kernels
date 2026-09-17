# The claim ledger as a typed relationship graph: specification

**Status:** specification of `proof_records/graph.py`, the second half of round-two item R8 of `docs/cross-pollination-round-two-2026-09-16.md` (transfer A3.1, "export the registries as a typed graph", with A3.2, "import provenance into the graph"). It states no mathematics. It re-presents records that `docs/ledger-generation-spec.md` has already validated, in the edge vocabulary of the `larsbx/tui-story` semantic graph, so that a relationship which is not a dependency becomes a queryable edge instead of prose. The committed example is `fixtures/ledger/relationship-graph.json`; `tools/make_ledger_example.py --check` fails when it is stale.

## 0. Why a second reading of the same ledger

A proof-record ledger stores one edge type, `depends_on`, and says everything else in prose: that two names denote one claim, that a gate assumes a set of results, that a live result stands on a withdrawn one. The first is an alias list, the second an assumption set, the third an audit finding somebody has to notice. All three are relationships between the same nodes, and a graph with a type per relationship makes each of them a query.

The direction of transfer is symmetric. `tui-story` types nine kinds of relationship and scores each with a certainty, but its edges are LLM-asserted and carry no provenance class, so a verified relationship and a guess are stored alike. A proof-record ledger has exactly what that lacks: every relationship here is read off a registry, and every node states what backs it and what it leaks. So the export types the ledger, and the ledger sources the graph.

## 1. Nodes

Three kinds, each group in name order: claims first, then declared aliases, then assumption sets.

| Field | Meaning |
| --- | --- |
| `id` | the claim name, alias string, or assumption-set name; unique across the graph |
| `kind` | `claim`, `alias`, `assumption_set` |
| `label` | the consumer's status label for a claim (`status_labels`), the alias text, or `assumption set` |
| `provenance` | section 3 |
| `statement`, `scope`, `record_kind` | the record's own fields, on claim nodes |
| `source` | what backs the record, by kind (section 4) |
| `leaks` | what the node does not carry (section 5) |
| `members` | the claim an alias names, or the members of an assumption set |

Empty optional fields are omitted from the rendered surface, so a node states only what it has. Every edge endpoint is a node: an alias is a node precisely so that a `synonymous` edge has one at both ends.

## 2. Edges

The nine edge types of the `tui-story` graph are declared in the surface (`edge_types`); this export emits four of them.

| Type | From → to | Read as |
| --- | --- | --- |
| `implicative` | premise → conclusion | a `depends_on` edge, in the direction of proof sufficiency, carrying its `use_site` |
| `synonymous` | alias → claim | a declared alias names that claim |
| `part-whole` | member → assumption set | the set assumes that result |
| `contradictory` | withdrawn premise → live conclusion | a result that is not withdrawn requires one that is |

A dependency on a withdrawn result yields both an `implicative` edge and a `contradictory` edge: the dependency is still what the ledger records, and the contradiction is what an audit wants to query. Nothing is inferred beyond these four: `hierarchical`, `evolutionary`, `analogous`, `antonymous` and `causal` have no registry to read them from, and this export does not guess them.

Every edge carries `certainty`, which is the integer `1` and means *declared, not estimated*. A graph whose edges come from a registry has no scores to model; the field exists so that an importing `tui-story` graph can hold both kinds of edge without conflating them, and the exact integer is deliberate — an exact certainty is not a rounded one.

## 3. Provenance

The provenance of a node is read from its own record, never from a consumer's status label, so two repositories with different vocabularies produce comparable graphs:

| Class | When |
| --- | --- |
| `withdrawn` | tagged withdrawn |
| `open` | outcome `open` (a pending record) |
| `bounded-evidence` | outcome `bounded` |
| `imported-theorem` | kind `imported_theorem`, accepted |
| `conditional` | a proved kind whose dependency closure is incomplete |
| `theorem-backed` | a proved kind with a complete closure |
| `declared` | alias and assumption-set nodes |

An `implicative` edge takes the provenance of its premise, a `synonymous` edge that of the claim it names, a `part-whole` edge that of the member, and a `contradictory` edge is `withdrawn` by construction.

## 4. The source rule

**An `implicative` or `synonymous` edge of provenance `theorem-backed` must name its source, or the export is refused.** This is the constraint A3.2 proposed for the `tui-story` edge schema, enforced at the exporting end: it is what keeps a verified relationship from being stored like a guess.

A node's `source` is the evidence its kind requires, mirroring `REQUIRED_EVIDENCE` of the proof-records specification: `replay` and `digest` for a verified finite computation, `source` for a repository or imported theorem, `domain` for a bounded experiment, `reason` for a pending or rejected record. The reference model already refuses a record missing that evidence, so the rule bites only on a record whose backing evidence is present but empty.

## 5. Leaks

`leaks` states what the node does not carry, in this order: the record's own `leaks` evidence when it declares one; else, for a withdrawn or open node, the `reason` it is pending; else the direct premises that are not themselves `theorem-backed`, as `premises not established: A, B`. A `theorem-backed` node with a complete closure leaks nothing and says so by omission. An edge leaks `premise is <provenance>` whenever its premise is not theorem-backed, and a contradictory edge leaks `a live result stands on a withdrawn one`.

## 6. Fail closed

`build` refuses the graph, naming every reason, when: two nodes share an identifier; an alias collides with a claim name; a node or edge carries a provenance outside section 3; an edge carries a type outside the nine; an edge endpoint is not a node; or the source rule of section 4 is broken. A refused graph renders nothing and, through the generator, exits 2.

## 7. The rendered surface

Deterministic JSON, newline-terminated, with the generator's `do not edit` banner in `generated`:

```text
format               "finite typed relationship graph 1"
generated            the banner naming the ledger it came from
repository, source   the ledger's own
edge_types           the nine types, in the tui-story order
provenance_classes   the seven classes of section 3
nodes, edges         sections 1 and 2, each sorted: nodes by kind group then id,
                     edges by (type in edge_types order, source, target, use_site)
```

A consumer declares `graph_path` in its ledger (`docs/ledger-generation-spec.md`, section 1) and the graph becomes one more generated surface, current in CI under `--check` like every other. Without that key nothing is emitted.

## 8. Conformance tests

`tests/proof_records/test_graph.py` checks, over the committed example: the rendered graph is the committed one; the declared vocabularies; every endpoint is a node; one test per edge type including the contradictory edge and its absence once the dependent is withdrawn too; provenance per class; the three leak routes; the source rule; and every refusal of section 6 by name.

## 9. Non-claims

The export asserts no mathematics and no new relationship. A `contradictory` edge reports that the ledger records a live result standing on a withdrawn one; it does not decide which of the two is wrong. `certainty = 1` is a statement about the edge's origin — a registry — and not about the truth of the claims it joins.
