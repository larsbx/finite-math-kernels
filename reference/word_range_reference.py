"""Independent exact reference for signed machine-word ranges.

Python integers are unbounded, so nothing here can wrap by accident. The
word reduction re-centres by offset (`(x + 2^(w-1)) mod 2^w - 2^(w-1)`),
not by the Mojo kernel's conditional subtraction, and on small words every
range is also checked by enumerating its operands. The finite dataset is
conformance evidence, NOT proof of the consumer's wrapped-equals-exact
theorem.
"""
from __future__ import annotations

from itertools import product

MAX_WIDTH = 64
Range = tuple[int, int] | None  # None: refused


def bounds(width: int) -> tuple[int, int]:
    if type(width) is not int or not 1 <= width <= MAX_WIDTH:
        raise ValueError("word width outside 1..64")
    return -(1 << (width - 1)), (1 << (width - 1)) - 1


def wrap(x: int, width: int) -> int:
    half = 1 << (width - 1)
    return (x + half) % (2 * half) - half


def make(width: int, lo: int, hi: int) -> Range:
    wmin, wmax = bounds(width)
    return (lo, hi) if wmin <= lo <= hi <= wmax else None


def _corners(width: int, a: Range, b: Range, op) -> Range:
    if a is None or b is None:
        return None
    values = [op(x, y) for x, y in product(a, b)]
    return make(width, min(values), max(values))


OPS = {
    "add": lambda w, a, b: _corners(w, a, b, lambda x, y: x + y),
    "sub": lambda w, a, b: _corners(w, a, b, lambda x, y: x - y),
    "mul": lambda w, a, b: _corners(w, a, b, lambda x, y: x * y),
    "hull": lambda w, a, b: None if a is None or b is None
    else make(w, min(a[0], b[0]), max(a[1], b[1])),
    "neg": lambda w, a, _b: None if a is None else make(w, -a[1], -a[0]),
    "clamp": lambda w, a, b: None if a is None or b is None
    else make(w, max(b[0], min(a[0], b[1])), max(b[0], min(a[1], b[1]))),
}


def apply(op: str, width: int, a: Range, b: Range = None) -> Range:
    return OPS[op](width, a, b)


def enumerated(op: str, width: int, a: Range, b: Range) -> Range:
    """The exact image by enumeration: the oracle for `apply` on small words."""
    if a is None or (op != "neg" and b is None):
        return None
    xs = range(a[0], a[1] + 1)
    ys = [0] if op == "neg" else range(b[0], b[1] + 1)
    image = {
        "add": lambda x, y: [x + y], "sub": lambda x, y: [x - y],
        "mul": lambda x, y: [x * y], "neg": lambda x, _y: [-x],
        "hull": lambda x, y: [x, y],
        "clamp": lambda x, _y: [max(b[0], min(x, b[1]))],
    }[op]
    if op == "clamp":
        ys = [0]
    values = [v for x in xs for y in ys for v in image(x, y)]
    return make(width, min(values), max(values))
