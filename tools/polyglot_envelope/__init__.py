"""The polyglot boundary envelope, one template rendered per repository.

The envelope schema and its conformance vectors are the same contract in every
repository that declares a polyglot boundary. Only three facts differ: the
owner and the repository, which name the schema, and the boundary it guards.
This package holds the one template of each file and `render`, which
substitutes those facts, read from the consumer's `polyglot.manifest.toml`,
and writes or checks the consumer's `.polyglot/` copies.

It decides nothing about the envelope's semantics: the template is the
contract, and finite-math-kernels' `reference/boundary_envelope.py` checks
that every rendering keeps its accepted and rejected verdicts.
"""
