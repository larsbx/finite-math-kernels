#!/usr/bin/env python3
"""The input distribution of a generator, declared and checked.

`larsbx/meta_test` requires a generator to declare a codomain refinement
``phi_G``: the subset of its type it actually produces, as an object a run can
refuse, rather than an accident of how the test was written. This repository
has already paid for not having one. The M-adic carrier formed ``a[i] - b[i]``
in 64-bit ``Int`` before lifting, which wraps; the defect survived a
differential run of 1200 checks because every coordinate that run generated lay
in ``[-9, 9]``, where the wrap is unreachable. A singular matrix survived the
same run because the corpus contained none. Both oracles were correct. Both
corpora were silent.

A refinement makes two claims, and a run can refuse either:

``holds``
    every drawn value lies in the declared codomain. A generator that escapes
    its own declaration is reported, not tolerated.

``classes``
    each named class is either **reached** -- at least one draw satisfies it --
    or explicitly **missed**, carrying the reason it is out of reach. Both
    directions are checked, so a declaration cannot rot in either direction: a
    class declared reached and never drawn is a weak corpus, and a class
    declared missed and then drawn is a stale declaration.

The second direction is the one that bites. A generator whose codomain contains
the wrap boundary but which never draws near it is not wrong, it is weak, and
without a declared class nothing reports the weakness. Declaring a class missed
is not a way to dismiss it: it is how the gap becomes a written finding with a
reason attached, which is what `docs/generator-refinement-spec.md` asks for.
"""

from __future__ import annotations

from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass, field

OUTSIDE = "produces a value outside its codomain"
UNREACHED = "declares it reaches"
UNEXPECTED = "declares it misses"


@dataclass(frozen=True)
class Class:
    """One named region of a generator's codomain.

    ``reason`` is empty for a class the corpus must witness, and states why the
    class is out of reach for one it must not.
    """

    name: str
    holds: Callable[..., bool]
    reason: str = ""

    @property
    def required(self) -> bool:
        return not self.reason


@dataclass(frozen=True)
class Refinement:
    """``phi_G`` for one generator: what it produces, and what it does not."""

    name: str
    codomain: str
    holds: Callable[..., bool]
    classes: Sequence[Class] = field(default=())

    def audit(self, drawn: Iterable[object], examples: int = 3) -> tuple[str, ...]:
        """Every way this corpus fails the declaration, named, in declared order."""
        corpus = list(drawn)
        inside = [v for v in corpus if self.holds(v)]
        problems: list[str] = []
        escaped = [v for v in corpus if not self.holds(v)][:examples]
        if escaped:
            problems.append(f"{self.name} {OUTSIDE} ({self.codomain}): " + ", ".join(repr(v) for v in escaped))
        # A class is a region of the codomain, so it is only asked about values
        # that reached it: a predicate need not be defined on an escapee.
        for cls in self.classes:
            seen = any(cls.holds(v) for v in inside)
            if cls.required and not seen:
                problems.append(f"{self.name} {UNREACHED} {cls.name!r} and no draw of {len(inside)} does")
            if not cls.required and seen:
                problems.append(f"{self.name} {UNEXPECTED} {cls.name!r} ({cls.reason}) and a draw does")
        return tuple(problems)

    def reached(self) -> tuple[str, ...]:
        return tuple(c.name for c in self.classes if c.required)

    def missed(self) -> tuple[str, ...]:
        return tuple(c.name for c in self.classes if not c.required)


def audit_all(refinements: Iterable[tuple[Refinement, Iterable[object]]]) -> tuple[str, ...]:
    """Every problem across several generators at once, so one run names them all."""
    return tuple(p for refinement, corpus in refinements for p in refinement.audit(corpus))
