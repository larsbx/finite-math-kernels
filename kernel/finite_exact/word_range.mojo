"""Closed integer ranges inside a signed w-bit two's-complement word.

A machine word of width `w` holds `[word_min(w), word_max(w)] =
[-2^(w-1), 2^(w-1) - 1]` and computes modulo `2^w`: `wrap_word` is that
reduction, the arithmetic of a homomorphic integer such as TFHE `FheInt32`,
which cannot observe an overflow. `WordRange` is the natural interval
extension over Z (Moore, *Interval Analysis*, 1966) of `+`, `-`, `*`,
negation and the hull, with every result refused unless it lies inside the
word.

What this module decides is finite: an accepted range is an exact enclosure
of every value its operation can take on operands inside its operands'
ranges, and lies inside the word. That wrapped evaluation then equals exact
evaluation (`wrap_word(x, w) == x` on the word, and `wrap_word` is a ring
homomorphism Z -> Z/2^w) is the consumer's theorem, not this module's.

Widths are `1 <= w <= 32`, so every bound product fits a 64-bit `Int` and
a refusal means exactly "leaves the word", never "the enclosure overflowed".
Like the rest of `finite_exact` apart from `checked_int`, nothing here
raises: invalid input and refused results carry a sticky `rejected` flag.
"""

comptime WORD_RANGE_MAX_WIDTH = 32


def word_width_ok(width: Int) -> Bool:
    return 1 <= width and width <= WORD_RANGE_MAX_WIDTH


def word_min(width: Int) -> Int:
    """`-2^(width-1)`; meaningful when `word_width_ok(width)`."""
    return -(1 << (width - 1))


def word_max(width: Int) -> Int:
    """`2^(width-1) - 1`; meaningful when `word_width_ok(width)`."""
    return (1 << (width - 1)) - 1


def wrap_word(x: Int, width: Int) -> Int:
    """The representative of `x mod 2^width` in the signed word.

    Exact for every 64-bit `x`: the residue is taken with a non-negative
    remainder before re-centring, so no intermediate leaves `Int`.
    """
    var modulus = 1 << width
    var r = x % modulus
    if r < 0:
        r += modulus
    return r - modulus if r > word_max(width) else r


struct WordRange(Copyable, Writable):
    """`[lo, hi]` inside the signed `width`-bit word, or rejected."""

    var width: Int
    var lo: Int
    var hi: Int
    var rejected: Bool

    def __init__(out self, width: Int, lo: Int, hi: Int):
        self.width = width
        self.lo = lo
        self.hi = hi
        self.rejected = not (
            word_width_ok(width)
            and lo <= hi
            and word_min(width) <= lo
            and hi <= word_max(width)
        )

    @staticmethod
    def point(width: Int, x: Int) -> Self:
        return Self(width, x, x)

    @staticmethod
    def word(width: Int) -> Self:
        """Every value of the word: what a range-free input may hold."""
        return Self(width, word_min(width), word_max(width))

    @staticmethod
    def refused(width: Int) -> Self:
        var r = Self(width, 0, 0)
        r.rejected = True
        return r^

    def accepted(self) -> Bool:
        return not self.rejected

    def contains(self, x: Int) -> Bool:
        return self.accepted() and self.lo <= x and x <= self.hi

    def _joint(self, other: Self) -> Bool:
        return self.accepted() and other.accepted() and self.width == other.width

    def add(self, other: Self) -> Self:
        if not self._joint(other):
            return Self.refused(self.width)
        return Self(self.width, self.lo + other.lo, self.hi + other.hi)

    def sub(self, other: Self) -> Self:
        if not self._joint(other):
            return Self.refused(self.width)
        return Self(self.width, self.lo - other.hi, self.hi - other.lo)

    def neg(self) -> Self:
        if self.rejected:
            return Self.refused(self.width)
        return Self(self.width, -self.hi, -self.lo)

    def mul(self, other: Self) -> Self:
        """The four bound products; each fits `Int` since `|bound| <= 2^31`."""
        if not self._joint(other):
            return Self.refused(self.width)
        var a = self.lo * other.lo
        var b = self.lo * other.hi
        var c = self.hi * other.lo
        var d = self.hi * other.hi
        return Self(self.width, min(min(a, b), min(c, d)), max(max(a, b), max(c, d)))

    def hull(self, other: Self) -> Self:
        """The least range containing both: an oblivious select's result."""
        if not self._joint(other):
            return Self.refused(self.width)
        return Self(self.width, min(self.lo, other.lo), max(self.hi, other.hi))

    def write_to(self, mut writer: Some[Writer]):
        if self.rejected:
            writer.write("refused")
        else:
            writer.write(self.lo, " ", self.hi)
