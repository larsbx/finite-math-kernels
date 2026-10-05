# Repository architecture

This repository adopts the estate repository template `estate-repository-v1`,
whose canonical source is `larsbx/estate-governance`.

The machine-readable source of repository structure and authority is
[`ESTATE.toml`](ESTATE.toml): this repository's estate position (SPEC_estate v0.1)
and its layout. The contract, `estate-repository-template-v2`, and the audit live
only in `larsbx/estate-governance`; nothing from it is vendored here. CI checks
governance out at the commit the `estate-governance` `[[dep]]` pins and runs the
audit from there, and the audit verifies its own sha256 against that pin.
The ordering rule is:

```text
authority -> mathematical/domain concern -> implementation language
```

Mojo packages under `kernel/` (`kernel/finite_exact/`, `kernel/finite_linear_algebra/`, ...) are
the canonical kernels, and `kernel/` is their include root (`-I kernel`). Python
references under `reference/`, oracles under `oracles/`, and the frontier
polyglot lane under `experiments/frontier/` are non-authoritative. Normative
contracts are in `schemas/`, their vectors in `conformance/`.

Consumers vendor packages from `kernel/`, `oracles/` and `tools/`. Paths inside
those packages are package-relative, so a vendored copy reads the same in every
repository; references from a package to the rest of this repository name the
repository path.

The layout is canonical: every plane in `ESTATE.toml` maps exactly its `target`
(root-level files aside), every top-level directory is some plane's target, and
no migration step is pending; the audit enforces all three. Directory renames
alone must not change claim status, acceptance, or authority.
