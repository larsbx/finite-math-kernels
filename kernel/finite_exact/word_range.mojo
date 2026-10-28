"""Closed integer ranges inside a signed w-bit two's-complement word.

A machine word of width `w` holds `[word_min(w), word_max(w)] =
[-2^(w-1), 2^(w-1) - 1]` and computes modulo `2^w`: `wrap_word` is that
reduction, the arithmetic of a homomorphic integer such as TFHE `FheInt32`
or `FheInt64`, which cannot observe an overflow. `WordRange` is the natural interval
extension over Z (Moore, *Interval Analysis*, 1966) of `+`, `-`, `*`,
negation, the hull and clamping, with every result refused unless it lies
inside the word.

What this module decides is finite: an accepted range is an exact enclosure
of every value its operation can take on operands inside its operands'
ranges, and lies inside the word. That wrapped evaluation then equals exact
evaluation (`wrap_word(x, w) == x` on the word, and `wrap_word` is a ring
homomorphism Z -> Z/2^w) is the consumer's theorem, not this module's.

Widths are `1 <= w <= 64`, so every word lies inside the 64-bit `Int`.
Bounds are combined with `checked_int`: a sum, difference or product of
bounds that leaves `Int` leaves every word, so the result it bounds is
refused, and a refusal still means exactly "leaves the word", never "the
enclosure overflowed". Like the rest of `finite_exact` apart from
`checked_int`, nothing here raises: invalid input and refused results carry
a sticky `rejected` flag.
"""

from finite_exact.checked_int import checked_add, checked_mul, checked_neg, checked_sub

comptime WORD_RANGE_MAX_WIDTH = 64


def word_width_ok(width: Int) -> Bool:
    return 1 <= width and width <= WORD_RANGE_MAX_WIDTH


def word_min(width: Int) -> Int:
    """`-2^(width-1)`; meaningful when `word_width_ok(width)`."""
    return Int.MIN if width == 64 else -(1 << (width - 1))


def word_max(width: Int) -> Int:
    """`2^(width-1) - 1`; meaningful when `word_width_ok(width)`."""
    return Int.MAX if width == 64 else (1 << (width - 1)) - 1


def wrap_word(x: Int, width: Int) -> Int:
    """The representative of `x mod 2^width` in the signed word.

    Exact for every 64-bit `x`: the 64-bit word is `Int` itself, and below it
    the residue is taken with a non-negative remainder before re-centring, so
    no intermediate leaves `Int`.
    """
    if width == 64:
        return x
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
        try:
            return Self(
                self.width, checked_add(self.lo, other.lo), checked_add(self.hi, other.hi)
            )
        except:
            return Self.refused(self.width)

    def sub(self, other: Self) -> Self:
        if not self._joint(other):
            return Self.refused(self.width)
        try:
            return Self(
                self.width, checked_sub(self.lo, other.hi), checked_sub(self.hi, other.lo)
            )
        except:
            return Self.refused(self.width)

    def neg(self) -> Self:
        if self.rejected:
            return Self.refused(self.width)
        try:
            return Self(self.width, checked_neg(self.hi), checked_neg(self.lo))
        except:
            return Self.refused(self.width)

    def mul(self, other: Self) -> Self:
        """The hull of the four bound products. Each product is a value the
        result takes, so one that leaves `Int` leaves the word: refused."""
        if not self._joint(other):
            return Self.refused(self.width)
        try:
            var a = checked_mul(self.lo, other.lo)
            var b = checked_mul(self.lo, other.hi)
            var c = checked_mul(self.hi, other.lo)
            var d = checked_mul(self.hi, other.hi)
            return Self(self.width, min(min(a, b), min(c, d)), max(max(a, b), max(c, d)))
        except:
            return Self.refused(self.width)

    def hull(self, other: Self) -> Self:
        """The least range containing both: an oblivious select's result."""
        if not self._joint(other):
            return Self.refused(self.width)
        return Self(self.width, min(self.lo, other.lo), max(self.hi, other.hi))

    def clamp(self, bounds: Self) -> Self:
        """The image of `x -> max(lo, min(x, hi))` for `bounds = [lo, hi]`.

        Clamping is monotone, so the image of `[a, b]` is exactly
        `[clamp(a), clamp(b)]`, and it lies in `bounds` whatever the operand:
        a homomorphic min/max, which cannot overflow, enforces a declared
        range on a value nobody vouches for.
        """
        if not self._joint(bounds):
            return Self.refused(self.width)
        return Self(
            self.width,
            max(bounds.lo, min(self.lo, bounds.hi)),
            max(bounds.lo, min(self.hi, bounds.hi)),
        )

    def write_to(self, mut writer: Some[Writer]):
        if self.rejected:
            writer.write("refused")
        else:
            writer.write(self.lo, " ", self.hi)
