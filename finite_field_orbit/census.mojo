# census.mojo
#
# Contract `orbit-census-v1` (docs/polyglot-orbit-census-design.md, section 3):
# exact tail and period of x -> x^2 + c on F_p for a block of seeds, folded
# into a commutative monoid, a canonical one-line encoding, and the replay
# predicate that is the contract's only acceptance authority.
#
# The census is a pure fold over owned accumulators. The one mutable object,
# the visited table, is uniquely owned by one census call and never escapes.
# That is the Perceus reading of in-place update: no observer can tell it
# from rebuilding the table for every seed.

comptime TAG = "orbit-census-v1"
comptime ARITY = 15
comptime CONTRACT_BOUND = 4294967296  # 2^32: every field but the sums, which range to 2^64
comptime TABLE_BOUND = 16777216  # 2^24: this kernel's declared domain for p


struct Block(Copyable, Movable):
    """The question `(p, c, cap, lo, hi)`: seeds `lo <= s < hi` of `x^2 + c` over F_p."""

    var p: Int
    var c: Int
    var cap: Int
    var lo: Int
    var hi: Int

    def __init__(out self, p: Int, c: Int, cap: Int, lo: Int, hi: Int):
        self.p = p
        self.c = c
        self.cap = cap
        self.lo = lo
        self.hi = hi

    def values(self) -> List[Int]:
        return [self.p, self.c, self.cap, self.lo, self.hi]


struct Agg(Copyable, Movable):
    """The canonical aggregate of section 3.3; `Agg()` is the monoid identity."""

    var n: Int
    var resolved: Int
    var sum_mu: Int
    var sum_lambda: Int
    var periodic: Int
    var has_w: Int
    var w_seed: Int
    var w_mu: Int
    var w_lambda: Int

    def __init__(out self):
        self = Agg(0, 0, 0, 0, 0, 0, 0, 0, 0)

    def __init__(
        out self, n: Int, resolved: Int, sum_mu: Int, sum_lambda: Int, periodic: Int,
        has_w: Int, w_seed: Int, w_mu: Int, w_lambda: Int,
    ):
        self.n = n
        self.resolved = resolved
        self.sum_mu = sum_mu
        self.sum_lambda = sum_lambda
        self.periodic = periodic
        self.has_w = has_w
        self.w_seed = w_seed
        self.w_mu = w_mu
        self.w_lambda = w_lambda

    def values(self) -> List[Int]:
        return [self.n, self.resolved, self.sum_mu, self.sum_lambda, self.periodic,
                self.has_w, self.w_seed, self.w_mu, self.w_lambda]


def field_names() -> List[String]:
    return ["p", "c", "cap", "lo", "hi", "n", "resolved", "sum_mu", "sum_lambda", "periodic",
            "has_w", "w_seed", "w_mu", "w_lambda"]


def witness_first(a: Agg, b: Agg) -> Bool:
    """Is `a`'s witness at least as good as `b`'s: longer rho, then smaller seed."""
    if b.has_w == 0:
        return True
    if a.has_w == 0:
        return False
    var la = a.w_mu + a.w_lambda
    var lb = b.w_mu + b.w_lambda
    return la > lb or (la == lb and a.w_seed <= b.w_seed)


def merge(a: Agg, b: Agg) -> Agg:
    """Sums, and the better witness; associative and commutative."""
    var w = a.copy() if witness_first(a, b) else b.copy()
    return Agg(a.n + b.n, a.resolved + b.resolved, a.sum_mu + b.sum_mu, a.sum_lambda + b.sum_lambda,
               a.periodic + b.periodic, w.has_w, w.w_seed, w.w_mu, w.w_lambda)


def is_prime(p: Int) -> Bool:
    if p < 2:
        return False
    var d = 2
    while d * d <= p:
        if p % d == 0:
            return False
        d += 1
    return True


def request_verdict(b: Block) -> String:
    """`""` when the kernel will answer `b`; else `malformed:<field>` or `unsupported:<field>`."""
    if b.p >= CONTRACT_BOUND or not is_prime(b.p):
        return "malformed:p"
    if b.c < 0 or b.c >= b.p:
        return "malformed:c"
    if b.cap < 0 or b.cap >= CONTRACT_BOUND:
        return "malformed:cap"
    if b.lo < 0 or b.lo > b.hi:
        return "malformed:lo"
    if b.hi > b.p:
        return "malformed:hi"
    if b.p >= TABLE_BOUND:
        return "unsupported:p"
    return ""


struct Visited(Movable):
    """First-seen index plus one for every value touched by the current seed; zero elsewhere."""

    var first: List[UInt32]
    var trail: List[Int]

    def __init__(out self, p: Int):
        self.first = List[UInt32](length=p, fill=0)
        self.trail = List[Int]()

    def leaf(mut self, b: Block, seed: Int) -> Agg:
        """The census of the single seed: resolved iff the first repeat index `j <= cap`."""
        var x = seed
        var j = 0
        var result = Agg(1, 0, 0, 0, 0, 0, 0, 0, 0)
        while True:
            var seen = Int(self.first[x])
            if seen > 0:
                var mu = seen - 1
                var lam = j - mu
                result = Agg(1, 1, mu, lam, 1 if mu == 0 else 0, 1, seed, mu, lam)
                break
            if j == b.cap:
                break
            self.first[x] = UInt32(j + 1)
            self.trail.append(x)
            x = (x * x + b.c) % b.p
            j += 1
        for v in self.trail:
            self.first[v] = 0
        self.trail.clear()
        return result^


def census(b: Block) raises -> Agg:
    """Exact census of a block this kernel supports; anything else raises its verdict."""
    var refusal = request_verdict(b)
    if refusal.byte_length() > 0:
        raise Error(refusal)
    var visited = Visited(b.p)
    var acc = Agg()
    for s in range(b.lo, b.hi):
        acc = merge(acc, visited.leaf(b, s))
    return acc^


def encode(b: Block, a: Agg) -> String:
    var parts: List[String] = [String(TAG)]
    for v in b.values():
        parts.append(String(v))
    for v in a.values():
        parts.append(String(v))
    return String(" ").join(parts)


struct Decoded(Movable):
    """A decoded record, or the `malformed:<field>` reason it is not one."""

    var reason: String
    var block: Block
    var agg: Agg

    def __init__(out self, reason: String, var block: Block, var agg: Agg):
        self.reason = reason
        self.block = block^
        self.agg = agg^


comptime MALFORMED = -1
comptime UNREPRESENTABLE = -2  # a valid wide value at or above 2^63, beyond Int


def parse_canonical(token: String, wide: Bool = False) -> Int:
    """An unsigned decimal with no leading zero, below 2^32 (or 2^64 when `wide`).

    Returns the value, `MALFORMED`, or `UNREPRESENTABLE` for a wide value in
    `[2^63, 2^64)`: valid in the contract, but not an `Int`. Such a sum cannot
    belong to a block inside this kernel's domain, where sums stay below 2^48.
    """
    var bytes = token.as_bytes()
    var n = len(bytes)
    if n == 0 or n > (20 if wide else 10) or (n > 1 and Int(bytes[0]) == ord("0")):
        return MALFORMED
    var value: UInt64 = 0
    for i in range(n):
        var digit = Int(bytes[i]) - ord("0")
        if digit < 0 or digit > 9:
            return MALFORMED
        if value > (UInt64.MAX - UInt64(digit)) // 10:
            return MALFORMED  # 2^64 or more
        value = value * 10 + UInt64(digit)
    if not wide and value >= UInt64(CONTRACT_BOUND):
        return MALFORMED
    if value > UInt64(Int.MAX):
        return UNREPRESENTABLE
    return Int(value)


def decode(line: String) -> Decoded:
    """Total inverse of `encode`: every other string is `malformed:<field>`.

    The one exception is a sum in `[2^63, 2^64)`: a valid record this kernel
    cannot hold, answered `unsupported:<field>` (section 3.6).
    """
    var tokens = List[String]()
    for part in line.split(" "):
        tokens.append(String(part))
    if len(tokens) != ARITY or tokens[0] != TAG:
        return Decoded("malformed:arity", Block(0, 0, 0, 0, 0), Agg())
    var names = field_names()
    var v = List[Int]()
    for i in range(1, ARITY):
        var name = names[i - 1]
        var value = parse_canonical(tokens[i], wide=name == "sum_mu" or name == "sum_lambda")
        if value == MALFORMED:
            return Decoded("malformed:" + name, Block(0, 0, 0, 0, 0), Agg())
        if value == UNREPRESENTABLE:
            return Decoded("unsupported:" + name, Block(0, 0, 0, 0, 0), Agg())
        v.append(value)
    return Decoded("", Block(v[0], v[1], v[2], v[3], v[4]), Agg(v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12], v[13]))


def witness_verdict(b: Block, a: Agg) -> String:
    """Replay the witness from its own trajectory, sharing no code with `Visited`."""
    if a.has_w == 0:
        return "" if a.w_seed == 0 and a.w_mu == 0 and a.w_lambda == 0 else "witness:canonical"
    if a.has_w != 1:
        return "witness:canonical"
    if a.w_seed < b.lo or a.w_seed >= b.hi:
        return "witness:range"
    var j = a.w_mu + a.w_lambda
    if j > b.cap:
        return "witness:cap"
    if j > b.p:
        return "witness:distinct"  # pigeonhole: j + 1 terms in p values
    var xs: List[Int] = [a.w_seed]
    for _ in range(j):
        xs.append((xs[len(xs) - 1] * xs[len(xs) - 1] + b.c) % b.p)
    if a.w_lambda < 1 or xs[j] != xs[a.w_mu]:
        return "witness:cycle"
    var prefix = xs[0:j]
    sort(prefix)
    for i in range(1, len(prefix)):
        if prefix[i] == prefix[i - 1]:
            return "witness:distinct"
    return ""


def replay(line: String) -> String:
    """The acceptance authority of section 4: `accepted` or the first reason not to."""
    var d = decode(line)
    if d.reason.byte_length() > 0:
        return d.reason
    var refusal = request_verdict(d.block)
    if refusal.byte_length() > 0:
        return refusal
    try:
        var claimed = d.agg.values()
        var actual = census(d.block).values()
        var names = field_names()
        for i in range(len(claimed)):
            if claimed[i] != actual[i]:
                return "mismatch:" + names[i + 5]
    except e:
        return "infra:" + String(e)
    var w = witness_verdict(d.block, d.agg)
    return w if w.byte_length() > 0 else "accepted"
