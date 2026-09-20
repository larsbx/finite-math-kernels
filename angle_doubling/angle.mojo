# angle.mojo
#
# Rational angles modulo one under doubling, exactly.
#
# Specification: docs/rational-interval-arithmetic-spec.md, section 1.
#
# The backend is checked fixed width, which specification section 1 admits as
# long as it fails closed: an angle whose denominator would overflow doubling
# is rejected rather than wrapped, and a rejected angle stays rejected.
#
# The two facts the package exists for are closed forms, proved in the
# consumer's notes and checked here:
#
#   preperiod(p/q) = v_2(q)              the exponent of two in the denominator
#   period(p/q)    = ord_m(2)            m the odd part of q
#
# so no search decides a type; the type is read off the denominator.

def denominator_limit() -> Int64:
    """Past this a doubling step would overflow the checked backend."""
    return 1073741824


def order_limit() -> Int:
    """The largest period this package will search for before refusing."""
    return 64


def gcd_i64(a: Int64, b: Int64) -> Int64:
    """The non-negative greatest common divisor."""
    var x = a if a >= 0 else -a
    var y = b if b >= 0 else -b
    while y != 0:
        var r = x % y
        x = y
        y = r
    return x


struct Angle(Copyable, Movable):
    """`num / den` in lowest terms with `0 <= num < den`, or a refusal."""

    var num: Int64
    var den: Int64
    var rejected: Bool

    def __init__(out self, num: Int64, den: Int64, rejected: Bool):
        self.num = num
        self.den = den
        self.rejected = rejected

    @staticmethod
    def of(num: Int64, den: Int64) -> Angle:
        """Reduce `num/den` modulo one, or refuse.

        A non-positive denominator is malformed, and one past the limit would
        overflow the doubling step. Both are values, not aborts.
        """
        if den <= 0 or den > denominator_limit():
            return Angle(0, 1, True)
        var residue = num % den
        if residue < 0:
            residue += den
        var divisor = gcd_i64(residue, den)
        if divisor == 0:
            return Angle(0, 1, False)
        return Angle(residue // divisor, den // divisor, False)

    @staticmethod
    def refused() -> Angle:
        return Angle(0, 1, True)

    def accepted(self) -> Bool:
        return not self.rejected

    def eq(self, other: Angle) -> Bool:
        """Equality of accepted angles; a refusal equals nothing, itself
        included, because two refusals are not evidence of agreement."""
        if self.rejected or other.rejected:
            return False
        return self.num == other.num and self.den == other.den

    def is_zero(self) -> Bool:
        return self.accepted() and self.num == 0


def double(t: Angle) -> Angle:
    """`2t` modulo one."""
    if t.rejected:
        return Angle.refused()
    return Angle.of(2 * t.num, t.den)


def orbit_term(t: Angle, steps: Int) -> Angle:
    """The `steps`-th term of the doubling orbit, recomputed from the seed."""
    if steps < 0 or t.rejected:
        return Angle.refused()
    var current = t.copy()
    for _ in range(steps):
        current = double(current)
    return current.copy()


def preperiod(t: Angle) -> Int:
    """`v_2(den)`: the exact number of steps before the orbit is periodic."""
    if t.rejected:
        return -1
    var den = t.den
    var count = 0
    while den % 2 == 0:
        den //= 2
        count += 1
    return count


def period(t: Angle) -> Int:
    """`ord_m(2)` for `m` the odd part of the denominator: the exact period.

    A budget that runs out returns `-1`, which is not a period and must not
    be read as one.
    """
    if t.rejected:
        return -1
    var odd = t.den
    while odd % 2 == 0:
        odd //= 2
    if odd == 1:
        return 1
    var power: Int64 = 2 % odd
    var order = 1
    while power != 1:
        if order >= order_limit():
            return -1
        power = (power * 2) % odd
        order += 1
    return order


def has_type(t: Angle, l: Int, k: Int) -> Bool:
    """Does `2^(l+k) t = 2^l t`, that is `l >= preperiod` and `period | k`?"""
    if t.rejected or l < 0 or k < 1:
        return False
    var p = period(t)
    if p < 1:
        return False
    return l >= preperiod(t) and k % p == 0


def type_count(l: Int, k: Int) -> Int64:
    """`2^l (2^k - 1)`, the number of angles satisfying `2^(l+k) t = 2^l t`.

    Refuses as `-1` where the count would not fit the checked backend.
    """
    if l < 0 or k < 1 or l + k > 60:
        return -1
    return (Int64(1) << Int64(l)) * ((Int64(1) << Int64(k)) - 1)


def angle_smoke() -> Bool:
    """The closed forms against hand values, and the refusals."""
    # 1/3 is periodic of period two: 1/3 -> 2/3 -> 1/3.
    var third = Angle.of(1, 3)
    if not (preperiod(third) == 0 and period(third) == 2):
        return False
    if not orbit_term(third, 2).eq(third):
        return False
    if not double(third).eq(Angle.of(2, 3)):
        return False
    # 1/6 has preperiod one and period two: 1/6 -> 1/3 -> 2/3 -> 1/3.
    var sixth = Angle.of(1, 6)
    if not (preperiod(sixth) == 1 and period(sixth) == 2):
        return False
    if not orbit_term(sixth, 3).eq(orbit_term(sixth, 1)):
        return False
    # A dyadic angle falls onto zero and stays: 3/8 has preperiod three.
    var dyadic = Angle.of(3, 8)
    if not (preperiod(dyadic) == 3 and period(dyadic) == 1):
        return False
    if not orbit_term(dyadic, 3).is_zero():
        return False
    # Reduction and wrapping: 5/4 is 1/4, and -1/4 is 3/4.
    if not Angle.of(5, 4).eq(Angle.of(1, 4)):
        return False
    if not Angle.of(-1, 4).eq(Angle.of(3, 4)):
        return False
    # The type predicate follows the closed forms rather than a search.
    if not (has_type(sixth, 1, 2) and has_type(sixth, 2, 4)):
        return False
    if has_type(sixth, 0, 2) or has_type(sixth, 1, 3):
        return False
    # Counting.
    if type_count(0, 2) != 3 or type_count(1, 2) != 6 or type_count(0, 1) != 1:
        return False
    # Refusals are values.
    if Angle.of(1, 0).accepted() or Angle.of(1, -3).accepted():
        return False
    if Angle.refused().eq(Angle.refused()):
        return False
    return type_count(0, 0) == -1 and preperiod(Angle.refused()) == -1
