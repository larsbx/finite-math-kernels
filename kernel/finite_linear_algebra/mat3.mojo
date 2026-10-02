"""3x3 integer matrices: the incidence matrices M_sigma and the sl_3 seed
matrices A_k both live here. All arithmetic is exact over Z."""


struct Mat3(Copyable, Movable, Writable, Equatable):
    """Row-major 3x3 integer matrix; `e[3*i + j]` is the (i, j) entry."""

    var e: List[Int]

    def __init__(out self, entries: List[Int]):
        self.e = entries.copy()

    def at(self, i: Int, j: Int) -> Int:
        return self.e[3 * i + j]

    def __eq__(self, o: Mat3) -> Bool:
        for i in range(9):
            if self.e[i] != o.e[i]:
                return False
        return True

    def __ne__(self, o: Mat3) -> Bool:
        return not (self == o)

    def __mul__(self, o: Mat3) -> Mat3:
        var out = List[Int]()
        for i in range(3):
            for j in range(3):
                var s = 0
                for k in range(3):
                    s += self.at(i, k) * o.at(k, j)
                out.append(s)
        return Mat3(out)

    def scale(self, c: Int) -> Mat3:
        var out = List[Int]()
        for i in range(9):
            out.append(c * self.e[i])
        return Mat3(out)

    def apply(self, v: List[Int]) -> List[Int]:
        var out = List[Int]()
        for i in range(3):
            var s = 0
            for k in range(3):
                s += self.at(i, k) * v[k]
            out.append(s)
        return out^

    def trace(self) -> Int:
        return self.at(0, 0) + self.at(1, 1) + self.at(2, 2)

    def det(self) -> Int:
        return (
            self.at(0, 0) * (self.at(1, 1) * self.at(2, 2) - self.at(1, 2) * self.at(2, 1))
            - self.at(0, 1) * (self.at(1, 0) * self.at(2, 2) - self.at(1, 2) * self.at(2, 0))
            + self.at(0, 2) * (self.at(1, 0) * self.at(2, 1) - self.at(1, 1) * self.at(2, 0))
        )

    def adjugate(self) -> Mat3:
        """`self * adjugate(self) == det(self) * I`; avoids rational inverses."""
        var out = List[Int]()
        for i in range(3):
            for j in range(3):
                # entry (i, j) of adj is the (j, i) cofactor
                var rows = List[Int]()
                var cols = List[Int]()
                for r in range(3):
                    if r != j:
                        rows.append(r)
                for c in range(3):
                    if c != i:
                        cols.append(c)
                var minor = (
                    self.at(rows[0], cols[0]) * self.at(rows[1], cols[1])
                    - self.at(rows[0], cols[1]) * self.at(rows[1], cols[0])
                )
                var sign = 1 if (i + j) % 2 == 0 else -1
                out.append(sign * minor)
        return Mat3(out)

    def is_zero(self) -> Bool:
        for i in range(9):
            if self.e[i] != 0:
                return False
        return True

    def charpoly(self) -> List[Int]:
        """Coefficients `[c0, c1, c2, 1]` of `det(t I - self)`, low degree first."""
        var t1 = self.trace()
        var t2 = (self * self).trace()
        var c2 = -t1
        var c1 = (t1 * t1 - t2) // 2
        var c0 = -self.det()
        var out: List[Int] = [c0, c1, c2, 1]
        return out^

    def write_to[W: Writer](self, mut w: W):
        for i in range(3):
            w.write("[")
            for j in range(3):
                if j > 0:
                    w.write(" ")
                w.write(self.at(i, j))
            w.write("]")


def identity3() -> Mat3:
    var e: List[Int] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    return Mat3(e)


def has_rational_root(poly: List[Int]) -> Bool:
    """Rational-root test for a monic integer cubic `[c0, c1, c2, 1]`.

    Monic ⟹ every rational root is an integer dividing `c0`; `c0 == 0` gives root 0.
    """
    if poly[0] == 0:
        return True
    var n = abs(poly[0])
    for d in range(1, n + 1):
        if n % d != 0:
            continue
        for s in range(2):
            var r = d if s == 0 else -d
            if poly[0] + poly[1] * r + poly[2] * r * r + r * r * r == 0:
                return True
    return False
