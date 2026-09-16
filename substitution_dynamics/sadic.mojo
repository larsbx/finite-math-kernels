"""Composition of substitutions and finite directive prefixes.

Specification: `docs/tuning-substitutions-spec.md`, section 2. A directive
prefix is a list `sigma_1, ..., sigma_n` of substitutions over one alphabet;
its composite is `sigma_1 o ... o sigma_n` and `apply_directive` evaluates
that composite on a word without forming it. Nothing here asserts a limit,
a primitivity property, or any theorem about the S-adic system.

Reference oracle: `tools/tuning_reference.py`.
"""

from substitution_dynamics.substitution import Substitution


def compose(outer: Substitution, inner: Substitution) raises -> Substitution:
    """`(outer o inner)(a) = outer(inner(a))`; both over one alphabet."""
    if outer.size != inner.size:
        raise Error("composition needs substitutions over one alphabet")
    var images = List[List[Int]]()
    for a in range(inner.size):
        images.append(outer.apply(inner.images[a]))
    return Substitution(images^, inner.size)


def directive_composite(subs: List[Substitution]) raises -> Substitution:
    """`sigma_1 o sigma_2 o ... o sigma_n`."""
    if len(subs) == 0:
        raise Error("directive sequence must be non-empty")
    var acc = subs[0].copy()
    for i in range(1, len(subs)):
        acc = compose(acc, subs[i])
    return acc^


def apply_directive(subs: List[Substitution], w: List[Int]) raises -> List[Int]:
    """`sigma_1(sigma_2(... sigma_n(w)))` without forming the composite."""
    if len(subs) == 0:
        raise Error("directive sequence must be non-empty")
    var out = w.copy()
    for i in range(len(subs) - 1, -1, -1):
        out = subs[i].apply(out)
    return out^
