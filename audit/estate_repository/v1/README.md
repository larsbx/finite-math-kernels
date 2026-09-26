# Estate Repository Template v1 shared tooling

This directory is the shared mechanism for Estate Repository Template v1.

It deliberately owns **architecture validation only**. It does not own a consumer's
mathematical claims, proof status, certificate acceptance, deployment authorization,
or persisted operational state.

Contents:

- `CONTRACT.md` — the shared v1 architecture contract;
- `estate.template.toml` — copyable consumer manifest skeleton;
- `audit_estate_layout.py` — dependency-free audit CLI;
- `action.yml` — composite GitHub Action for mirror CI;
- `tests/` — conformance tests for the shared mechanism.

Run against a checked-out consumer:

```sh
python estate/v1/audit_estate_layout.py --root /path/to/consumer
```

Consumers should pin this repository by immutable commit revision. They keep their
own `estate.toml`, `ARCHITECTURE.md`, and domain-specific policy.

The canonical source/merge and CI policy of this repository remains independent of
the consumer's authority model. A passing estate-layout audit means the declared
repository architecture is internally consistent; it does not prove any domain claim.
