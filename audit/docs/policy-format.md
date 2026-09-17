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

## `[coverage]`: every test names what it guards

```toml
[coverage]
tests = ["mojo/tests/test_*.mojo"]
require_classes = ["finite-domain"]     # claim classes that must be guarded by a test
receipts = "mojo/build/claim-receipts.tsv"        # optional run log, see below
claim_pattern = 'require_claim\("(?P<claim>[^"]*)"\)'         # default
contract_pattern = 'require_contract\("(?P<contract>[^"]*)"\)'  # default
```

The proof-driven-test discipline of `larsbx/crypto-composer`, where a test
may not exist without a proof statement, read onto the ledger. Each test file
declares what it stands for: `require_claim` names a ledger claim (by name or
alias) whose supporting contract it guards, `require_contract` states a
contract that is no ledger claim, such as a vendored kernel's arithmetic.
Findings: a test file that declares neither; a named claim that is not in the
ledger; an empty contract; and, against `claim_governance.toml` itself, a
claim whose class is in `require_classes` that no test guards. Declarations
are read with comments blanked, so a commented-out declaration does not
count. Both patterns are regexes and must capture the named group
(`claim`, `contract`) the check reads, which is what lets a repository whose
tests are not Mojo keep its own spelling.

`receipts`, when named and present, is the run log of the suite in this
format, tab-separated, one line per declaration the run actually reached:

```text
# finite proof-test receipts 1
mojo/tests/test_overlap_context.mojo	claim	OneStepContextEquality
mojo/tests/test_finite_exact.mojo	contract	the vendored exact arithmetic contract
```

A declaration the run did not reach is reported and guards nothing, so a
claim whose only test body is never called from `main` is uncovered rather
than credited; a receipt no test declares is reported as drift; a malformed
receipts file is one finding and credits nothing. An absent receipts file
leaves the static layer alone, so a checkout without the test toolchain still
audits the declarations it can read.

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
