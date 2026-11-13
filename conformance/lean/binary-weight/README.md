# Binary-weight acceptance evidence

The focused universal arithmetic proofs **passed** at source commit
`8750345c496390a7ce4f6a80be331451aa999408`, tree
`2a3cc11797c1bca3acc35c1ec1b51946fd1f4b0e`. The broader repository gates did
**not** all pass in the available local runtime. These are separate outcomes.

## Accepted focused result

The authoritative result is [focused/report.json](focused/report.json).
It accepted an exact clean checkout, comparing all fourteen focused source files
byte for byte with the named commit before and after verification. The source
identity regression demonstrates rejection even when Git's assume-unchanged flag
hides a modified proof from a normal status check.

| Module | Compiled declarations | Compiled theorem declarations |
| --- | ---: | ---: |
| BinaryWeight | 26 | 25 |
| BinaryWeightContracts | 12 | 12 |
| BinaryWeightControls | 12 | 12 |
| Total | 50 | 49 |

The arithmetic source has twelve explicit theorem statements and thirteen
generated proof helpers. The other modules contain twelve explicit public type
wrappers and twelve positive control statements. These counts are not counts of
independent mathematical discoveries. All compiled declarations, including
helpers, were audited for transitive assumptions. Only `propext`,
`Classical.choice`, and `Quot.sound` were permitted. All seven negative controls
were rejected for their intended diagnostic: five arithmetic/type controls and
two compiled local/transitive assumption injections.

The gate used Lean 4.34.0-rc2, compiler commit
`6a10ac8c22beadecabdbb0919c2b50214762f91d`, and all nine pinned Lake package
revisions. It fresh-compiled the three modules without reusing project oleans.
The focused report's twenty-six hashed artifacts and the unchanged report are
all included. The run began 2026-11-13 13:31:16 UTC and finished 13:31:55 UTC.
Its report SHA-256 is
`2d221b314f87cd658b6bb7fb72bb4217f6c0bab86a98960be7cedf9de2adc5ec`.
An independent read-only audit reconciled the source identities, all artifacts,
raw compiled inventory, exact types, expected controls, compiler and dependency
identities; it reran no tests or compilers.

The result concerns natural-number binary weights and square bounds. It makes
no native BigZ/compiler refinement claim and no normality claim. The full
mathematical contracts and literature attribution are in
[the source documentation](../../../docs/binary-weight.md).

## Required repository gates

The final [task-graph report](repository-gates/report.json) records every literal
task command, its dependency chain, exit status, log, and runtime context.

| Required gate | Outcome | Observed evidence or limitation |
| --- | --- | --- |
| Aggregate `test` | Failed | Two tasks require an unavailable Mojo MAX module; the required frontier toolchain check also failed. |
| `test-audit` | Passed | 114 tests passed. |
| `test-provenance` | Passed | 7 tests passed; a separate source-manifest check passed. |
| `references` | Passed | Every checked path/task reference resolved. |
| `property` | Passed | Exact native/oracle agreement on 300 integer and 200 rational cases. |
| `test-polyglot` | Failed | Bend was unavailable on the active PATH and the required TLC jar was not configured; Bend-dependent tasks remained blocked. |

The task graph has 64 nodes: 55 passed, 5 failed, and 4 were blocked by failed
dependencies. Seventeen successful exact-source task results were retained from
an interrupted earlier harness attempt after checking command-token equivalence,
working directory, source/tree, task-graph, compiler and configuration identities.
Their original logs were copied and hashed; the other thirty-eight successful
tasks ran in the final literal-command pass. This avoids repeating successful
checks. The original records and retained-task provenance are included.

The final pass used explicit runtime paths, host Python 3.12.14, pinned Mojo
1.1.0.dev2026090805, and the installed runtime's MODULAR_HOME configuration. Both
Modular telemetry controls were false for every native invocation. It executed
no Pixi activation hook, `pixi run`, installation, or kernel modification.
Temporary test directories were outside the repository, matching fixture
requirements. The orchestrator completed to write its report; individual gate
statuses and the explicit all-repository-gates-passed field remain failed/false.

The projective-limits task passed its first seven component commands, then
stopped at the MAX-dependent component; subsequent commands joined by `&&` did
not execute. The parallel-fold task failed for the same missing MAX module.
Read-only runtime inspection found only the standard Mojo library and no
installed MAX package records. This is retained in
[environment-limits.json](repository-gates/environment-limits.json).

The initial active PATH lacked Rust, Bend, and Julia for the required frontier
check. Existing Rust 1.100.0 and a matching Mix 1.19.0/Erlang OTP 27 installation
were subsequently inspected and their versions succeeded. Repeating only that
previously failing frontier check with the inspected paths confirmed that Bend
and Julia still remained unavailable to it. That follow-up and its exact paths
are recorded in [the follow-up report](repository-gates/frontier-toolchain-followup.json).
No claim that Rust or Elixir is globally absent is made. The orchestrator tests
were blocked by their failed Bend build dependency, not executed and failed for
lack of Mix. TLC tests failed because TLA_TOOLS did not name a jar.

The broad Python task passed 1,812 tests with two observed skips; proof-record
tests passed 118 with two observed skips. The frontier task had 108 passes,
sixteen skips, and one required-toolchain failure before the focused follow-up.
These optional skips remain visible and are not treated as exercised coverage.
The repository source revision was unchanged throughout the completed run.

## Earlier attempts and exact provenance

- `attempts/initial-environment-a68e284/` preserves the initial repository-gate
  attempt at the preceding source revision. Missing MODULAR_HOME prevented the
  standard Mojo library from resolving; using a temporary directory inside Git
  broke fixtures requiring an outside directory. Its new-document reference
  failure was corrected before the accepted source revision. These failures are
  retained without attributing harness configuration failures to native kernels.
- `attempts/interrupted-command-rewrite/` preserves an interrupted attempt at
  the final source revision. An executable-name rewrite also rewrote a .mojo
  filename suffix before a shell separator. The owner stopped that harness;
  its recorded exit was 130. Malformed or unfinished commands supply no passing
  evidence. Only seventeen command-equivalent completed successes were retained
  by the final literal-command run; failed groups were rerun literally.
- `attempts/superseded-focused-a68e284/` preserves the earlier focused result.
  It is superseded by the authoritative hardened source/gate report above and
  is not counted as additional current acceptance.

The copied task-runner scripts are historical records of this local execution,
with machine-specific runtime paths. Their repository-root calculation assumes
the original location under the repository's .build directory; do not execute a
copied script from this nested evidence directory. Replay the declared tasks
with the recorded explicit runtime configuration or restore the runner to its
original location with the stated dependencies provisioned.

The original reports and logs are copied byte for byte. The two frontier
follow-up files were produced after the main task-graph report was finalized;
they are covered by this packet's manifest rather than retroactively inserted
into that unchanged report's artifact list. The interrupted attempt's separate
status record explains its incomplete report. A packet manifest hashes every
included file except the manifest itself and maps the copied directories to
their original runs.

Adding this evidence packet also updates `policy/provenance.json`. That manifest
is one of the fourteen focused source inputs, so its hash necessarily changes
after the accepted run to register the evidence files. The other thirteen inputs
are unchanged. The accepted source revision remains exactly the source commit
named above; no report is relabeled as accepting its later evidence child.
