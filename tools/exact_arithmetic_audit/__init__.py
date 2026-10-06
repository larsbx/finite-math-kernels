"""The consumer audit of the exact-arithmetic specification (section 7).

A consumer of the exact-arithmetic layers (``finite_exact``'s ``Q`` and
``IQ``) with certificate paths binds itself to the rational-interval
specification by a binding table, and section 7 of that specification asks
for a CI-cheap lexical hook that keeps the binding honest. This package is
that hook's engine, one copy for every consumer; the consumer supplies a
frozen ``Policy`` and calls ``run(root, policy)``, exactly as with the
``references`` package.

It checks, in order, stopping early where a later check would be noise:

1. the specification (and a separate binding document, if the policy names
   one) exists, carries every required heading, and names this consumer;
2. the binding table has rows, and every row's class is admissible;
3. every module a row names exists and cites the specification by path
   (criterion C7), except files whose header is upstream's: the policy's
   explicit list and, when the policy says so, every file inside a package
   the consumer's vendored.toml vendors (read through the ``vendoring``
   package, so vendoring a package and widening the exemption are one step);
4. every scanned module that imports a ``finite_exact`` arithmetic module
   has a binding row;
5. the allowlist's list items and the quarantined rows are the same set, in
   both directions, so a quarantine cannot be granted or forgotten silently;
6. no floating-point type, SIMD float dtype or decimal float literal appears
   in a scanned file outside comments and string literals (criterion C1),
   except allowlisted files and the policy's exempt prefixes.

It is unified from the two diverged copies in larsbx/finite-julia-set-research
and larsbx/finite-mandelbrot-research (tools/audit_exact_arithmetic.py in
each). Where they agreed the shared behaviour is fixed here; where they
differed it is a ``Policy`` field. A consumer reproduces its old audit with:

finite-julia-set-research
    ``binding="docs/exact-arithmetic-binding.md"``, its four required
    headings, ``classes=CLASSES``, ``float_exempt_prefixes=
    ("vendor/mojo/finite_exact/",)``, the defaults otherwise.
finite-mandelbrot-research
    ``binding_heading`` its section 6.2 heading, its fourteen required
    headings, ``classes=None``, ``arithmetic_modules=("rat_q", "rational",
    "closed_q", "closed_interval")``, ``skip_hidden=True``,
    ``exempt_vendored_citations=False`` with its four vendored facades as
    ``citation_exempt``.

Behaviour that changed for one consumer, because the union of the two
copies' checks is the stricter one:

- C1 uses the Mandelbrot float pattern (every Mojo literal form, ``Float``,
  ``BFloat16``, ``FloatLiteral``) plus Julia's ``DType.float*`` dtype check,
  which the Mandelbrot pattern missed.
- The spec must name the consumer, and a table with no rows fails (Julia's
  checks; Mandelbrot had neither).
- Only list items of the allowlist grant (Julia's rule; Mandelbrot read every
  backticked path in the file, prose included).
- With a ``classes`` set, a row whose class is not in it is an error; the
  Julia copy silently dropped such a row.

One change is a loosening, recorded so it is not mistaken for an accident:
comments and string literals are masked by ``claim_governance.lexing`` (the
Mandelbrot copy's lexer), so a float literal spelled inside a one-line
string is no longer reported for Julia, whose coarse filter scanned such
strings. A float *type* is still reported wherever code names it.

Dependencies: the standard library, ``vendoring`` and ``claim_governance``
(for ``lexing``); a consumer vendors the three together.

It decides nothing about the mathematics of the code it reads: a clean
audit means the binding is complete and the scanned text is free of the
float tokens it looks for, not that any module is correct.
"""

from __future__ import annotations

from exact_arithmetic_audit.audit import (
    CLASSES,
    FLOAT_RE,
    Policy,
    allowlisted,
    arithmetic_consumers,
    audit,
    binding_rows,
    floating_point,
    run,
    scanned_files,
    section,
)

__all__ = [
    "CLASSES",
    "FLOAT_RE",
    "Policy",
    "allowlisted",
    "arithmetic_consumers",
    "audit",
    "binding_rows",
    "floating_point",
    "run",
    "scanned_files",
    "section",
]
