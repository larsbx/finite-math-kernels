# Repository architecture

This repository adopts the estate repository template `estate-repository-v1`,
whose canonical source is `larsbx/estate-governance`.

The machine-readable source of repository structure and authority is
[`estate.toml`](estate.toml). The reusable contract is
[`docs/architecture/estate-repository-template-v1.md`](docs/architecture/estate-repository-template-v1.md),
vendored byte-for-byte and pinned by sha256 in the `[governance]` table of
`estate.toml`. Do not edit it or `tools/audit_estate_layout.py` locally; change
them in governance and re-vendor.

The ordering rule is:

```text
authority -> mathematical/domain concern -> implementation language
```

Mojo packages at the root (`finite_exact/`, `finite_linear_algebra/`, ...) are the
canonical kernels. Python references and oracles under `tools/`, and the frontier
polyglot lane under `benchmarks/frontier/`, are non-authoritative.

The layout is transitional. Each plane in `estate.toml` records its future
`target` and the existing paths it currently covers; existing paths remain
authoritative until a dedicated migration PR moves one bounded context. Directory
renames alone must not change claim status, acceptance, or authority.
