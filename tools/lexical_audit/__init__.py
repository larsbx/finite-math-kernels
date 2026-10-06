"""Terminology, banned-token and prose audits under a consumer policy.

A consumer that bans vocabulary from its prose, or requires a context for a
term, states the rule as data: a frozen ``Policy`` of governing
``Document``s and rules, run by ``run(root, policy)``, exactly as with
``exact_arithmetic_audit`` and ``references``. Three rule kinds cover the
audits this package replaces:

``ClauseRule``
    a banned pattern in a clause of prose, unless a denial word precedes it
    within reach in the same clause, an allowed phrase covers it, or it lies
    in an exempt section or the one block after a marker;
``ContextRule``
    every occurrence of a term needs a context marker within a radius of its
    start, unless the file carries a complete declaration or a pointer;
``DeclarationRule``
    a file that opens a declaration block must carry every field.

A ``Document`` must exist and match each ``Requirement`` (a pattern, at
least ``minimum`` times); a failed document stops the rules unless the
policy says otherwise. Findings are rendered from each rule's message
template (``{path}``, ``{line}``, ``{match}``, ``{term}``, ``{text}``,
``{missing}``), named once each, in rule order and then path order.

It is unified from three audits, each now a policy over this engine:

larsbx/finite-julia-set-research, tools/audit_terminology.py
    a ``ClauseRule`` for the circle vocabulary at rank 2 (exempt sections:
    headings that forbid; marker ``terminology-exempt``; allowed phrases read
    from the registry's field terms) and a ``ContextRule`` for rejected
    claims (``reject`` within 320).
larsbx/finite-mandelbrot-research, tools/audit_terminology.py
    two ``Document``s (registry and use manifest), a ``DeclarationRule``, and
    ``ContextRule``s for risky phrases, deprecated terms, C1-scoped terms and
    the rank-2 loci (radius 140).
larsbx/mandelbrot-bulbs-and-ford-circles-research, tools/audit_limits.py
    a ``ClauseRule`` for limit idioms over one register (exempt sections: three
    exact titles; marker ``limit-exempt``).

Where the audits differed only in mechanics, one behaviour is fixed here,
the stricter one unless that was an artefact:

- a block of prose is a paragraph joined across its line breaks (Julia);
  bulbs read line by line, so a denial ending one line now reaches into the
  next line of the same clause;
- a source file (any suffix but ``.md``) is read line by line, each line a
  block of its own; Julia joined contiguous source lines like a paragraph,
  so a denial on one comment line (``# no estimate``) reached a term on the
  next (``# circle exists``);
- a finding names the line of its match; Julia named the paragraph's first;
- a denial is a whole word ending within reach before the term (Julia);
  bulbs searched a window cut at ``reach``, where a cut word could count;
- a heading is an ATX heading (one to six ``#`` and a space); Julia took
  any Markdown line starting with ``#``;
- a section covers its subsections and ends at a heading of its level or
  higher; Julia ended a section at any heading, bulbs only at level 2;
- every heading outside an exempt section is audited; Julia audited none,
  bulbs skipped level-2 headings and the title line;
- a marker exempts the one block directly after it, whatever its reason
  says: a paragraph, or one list item or one table row, never the rest of
  the list or table; a blank line disarms it (Julia; bulbs kept it armed
  across blank lines). Both audits exempted every line up to the next blank
  line, so a marker before a list or table exempted all of it; no consumer
  marker preceded one, and the stricter reading is kept (a classical table
  belongs in an exempt section). Julia ignored a marker whose reason starts
  with ``#`` and let a marker on a heading line exempt that heading's
  section (both unused);
- an exempt-section pattern that matches no heading is a finding (bulbs
  refused to run; Julia had no such check);
- every occurrence of a term is read; Mandelbrot read only the first of a
  C1-scoped term and of a rank-2 locus, so a negated first occurrence hid
  the rest;
- terms are matched case-insensitively and the context window is centred on
  the occurrence's start (Mandelbrot); Julia matched rejected-claim names
  case-sensitively in a window running ``radius`` past their end;
- the report is one format, ``<title> failed:`` and one ``- finding`` line
  each, on standard output.

On the three consumers' trees at the commit they adopted this package, each
policy reported nothing, as each local audit did. Reading a source file line
by line, which came later, reports one place in Julia's tree:
``kernel/julia_orbit.mojo`` line 8, where the denial of an enumeration
("No circle, / disk, arc, or polar angle") is wrapped across comment lines.

Dependencies: the standard library, ``claim_governance`` (for ``lexing``)
and ``vendoring`` (for ``vendored_directories``); a consumer vendors the three
together.

It decides nothing about the mathematics of the text it reads: a clean audit
means the scanned text is free of the patterns the policy names outside the
exemptions the policy grants, not that any statement is correct.
"""

from __future__ import annotations

from lexical_audit.audit import (
    ClauseRule,
    ContextRule,
    Declaration,
    DeclarationRule,
    Document,
    Hit,
    Policy,
    Requirement,
    Rule,
    Scope,
    all_of,
    audit,
    contains,
    run,
    scanned_files,
)

__all__ = [
    "ClauseRule",
    "ContextRule",
    "Declaration",
    "DeclarationRule",
    "Document",
    "Hit",
    "Policy",
    "Requirement",
    "Rule",
    "Scope",
    "all_of",
    "audit",
    "contains",
    "run",
    "scanned_files",
]
