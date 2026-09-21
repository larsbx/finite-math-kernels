# Julia spike lane

This directory is for rapid Julia experiments concerning exact finite arithmetic, algebraic kernels, and differential checks against Mojo.

## Lifecycle

1. State the question, assumptions, and deletion or promotion criterion.
2. Pin inputs, random seeds, Julia version, dependencies, and precision.
3. Keep outputs outside trusted certificate and proof paths.
4. Promote a successful spike only by moving reviewed logic into the oracle lane or reimplementing it behind the canonical boundary.
5. Delete abandoned spikes once their result or counterexample is recorded.

A spike is never imported by production, proof, certificate-acceptance, authorization, or deployment code.
