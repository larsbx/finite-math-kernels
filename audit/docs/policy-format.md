# Policy file format

A consumer repository keeps one `claim_governance.toml` at its root. The
file is the whole of the repository's policy: the package reads it, walks the
repository, and reports findings. Every table is optional except
`[repository]`; a check with nothing configured reports nothing.

Paths are POSIX, relative to the repository root. Globs use `pathlib`
semantics (`**` recurses). Allowlists name files exactly.

```toml
[repository]
name = "owner/repo"                     # printed in the summary line

[scan]
prose  = ["docs/**/*.md", "manuscripts/*.tex", "README.md"]
source = ["src/**/*.mojo", "src/**/*.py"]
exclude = ["archive/**", "src/vendored/**"]   # never scanned by any check
```

Masking before matching: `.py` and `.mojo` files lose comments and string
literals, `.tex` files lose `%` comments, `.md` files lose fenced code
blocks. Line numbers are preserved.

## `[status]`: the status vocabulary

```toml
[status]
classes = ["proved", "imported", "finite-domain", "conditional", "open", "bridge", "evidence", "retired"]

[status.synonyms]                       # label as written on a surface -> class
"Repository-proved" = "proved"
"[PROVED]" = "proved"
"Open conjectural gate" = "open"
"[OPEN]" = "open"
```

Labels match exactly (set `ignore_case = true` under `[status]` to fold
case) and on word boundaries, so `OPEN` does not match `reopened`. Every
synonym must map to a declared class. Status surfaces are read with LaTeX
comments and source comments blanked but with Markdown code fences kept,
because dependency chains are often drawn inside them.

## `[terminology]`: undeclared, scoped, deprecated, and risky terms

```toml
[terminology]
registry = "docs/terminology-registry.md"
registry_sections = ["## Established field terms", "## Project terms with declarations"]
declaration_marker = "Terminology declaration:"
declaration_fields = ["Terminology declaration:", "Genealogy:", "Bridge claim:", "Known leaks:", "Use discipline:"]
project_terms = ["PointVertex", "rank-2 coordinate record"]   # must be declared in the registry
risky_phrases = ["isomorphic to", "essentially the same"]
negating_context = ["not ", "no ", "must not"]
migration_context = ["deprecated", "legacy", "replaces"]
allow = ["docs/terminology-registry.md"]                      # files exempt from the prose rules

[[terminology.scoped]]                  # free only under its home prefixes
term = "wake ambiguity"
home = ["docs/C1_", "src/C1_"]

[[terminology.deprecated]]
term = "catalogue extensionality"
replacement = "SeparatorCatalogueAdequacy"
allow = ["docs/C1_catalogue_extensionality.md"]
```

Findings: registry missing, a required section missing, a project term not
declared (by a `Terminology declaration:` line or a `##`-level heading), a
declaration block missing fields, a risky phrase in a file without a full
declaration and without negating context, a deprecated term without
migration context, a scoped term outside its home without a full
declaration or a mention of the registry path.

## `[claims]`: statements need a status label

```toml
[claims]
paths = ["docs/**/*.md"]
statement_kinds = ["Theorem", "Proposition", "Lemma", "Corollary", "Conjecture", "Open Problem"]
window_lines = 6
file_status_marker = "**Status:**"      # optional file-level status line
file_status_lines = 10                  # it must open a line within the first N
allow = ["docs/historical-snapshot.md"]
```

A statement opens a line as a Markdown heading (`## Theorem 4.4`), a bold
lead-in (`**Proposition 5.20 (x).**`), or a LaTeX environment
(`\begin{theorem}`); the kind may carry a number or tag and must then end
the line or meet punctuation, so a heading such as `# Hypothesis firewall`
and an in-sentence reference such as `Lemma 5.36 proves` do not count.
Within `window_lines` lines after a statement some status label from
`[status.synonyms]` must appear. A file that opens a line with
`file_status_marker` within its first `file_status_lines` lines declares a
file-level status and its statements need no individual label.

## `[[claim]]`: the ledger

```toml
[[claim]]
name = "OverlapProductivity"
status = "open"
aliases = ["seedwise overlap productivity", "Open Problem 5.35"]

[[claim.surfaces]]
path = "docs/claim-status-and-source-map.md"     # anchor defaults to name/aliases
window_lines = 0                                  # 0 = the anchor line only

[[claim.surfaces]]                                # set-membership surface
path = "tla/Ledger.tla"
section = "ProvedDef == {"                        # region bounded by two literals
section_end = "}"
expect = "absent"                                 # an open claim is not in the proved set
```

The ledger is the single source of truth. With the default
`expect = "labelled"`, the `consistency` check finds the first anchor
occurrence in the region and requires the ledger's class among the status
labels within `window_lines` lines after it. With `expect = "present"` or
`"absent"` the anchor must or must not occur in the region, which expresses
membership in a set such as a TLA+ proved-set or a code allowlist. Findings:
a missing surface, a region whose bounds are not found, a surface that never
mentions the claim, a window without any label, a window whose labels
exclude the ledger class, and a claim present in a region it must be absent
from.

## `[promotion]`: unsettled claims described as proved

```toml
[promotion]
proving_phrases = ["is proved", "we prove", "has been proved", "is a theorem", "establishes"]
negating_context = ["not ", "remains open", "would", "conditional", "without", "if "]
settled_classes = ["proved", "imported", "finite-domain"]
radius = 120
allow = []
```

For every ledger claim whose class is not settled, each word-bounded
occurrence of its name or alias in prose with a proving phrase within
`radius` characters and no negating context is a finding.

## `[[numerics.rule]]`: forbidden primitives in executable source

```toml
[[numerics.rule]]
name = "no-trig"
pattern = '\b(?:sin|cos|tan|exp|log|sqrt)\b|unit circle'
paths = ["src/**/*.mojo"]
message = "transcendental primitive; use quadrance, spread, or algebraic rotors"
allow_files = ["src/quarantined_backend.mojo"]
allow_lines = []                        # exact stripped lines that are exempt
negating_context = []                   # markers near a match that exempt it
radius = 140                            # in characters, for negating_context
```

Each rule is a regex applied to masked source; a line is reported at most
once per rule. `negating_context` serves prose files that name a primitive
only to forbid it, as in a design invariant that says "no unit circle".

## Exit status

`claim-governance` exits 0 with no findings, 1 with findings, 2 on a policy
error. A policy error is never silently ignored: a misconfigured file fails
the audit instead of auditing nothing.
