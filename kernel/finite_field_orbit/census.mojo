# census.mojo
#
# Contract `orbit-census-v1` (docs/polyglot-orbit-census-design.md, section 3):
# exact tail and period of x -> x^2 + c on F_p for a block of seeds, folded
# into a commutative monoid, a canonical one-line encoding, and the replay
# predicate that is the contract's only acceptance authority.
#
# The census is a pure fold over owned accumulators. The one mutable object,
# the visited set, is uniquely owned by one census call and never escapes.
# That is the Perceus reading of in-place update: no observer can tell it
# from rebuilding the set for every seed.
#
# The kernel answers the whole contract domain, p < 2^32. x^2 + c then reaches
# 2^64 - 12 * 2^32, past Int, so a step is computed in UInt64; a sum reaches
# p^2 < 2^64, so the sums are UInt64 too.

from certified_records import codec
from certified_records.codec import Schema

comptime TAG = "orbit-census-v1"
comptime CONTRACT_BOUND = 4294967296  # 2^32: every field but the sums, which range to 2^64
comptime TABLE_BOUND = 16777216  # 2^24: below it the visited set is a table of p words


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


struct Agg(Copyable, Movable):
    """The canonical aggregate of section 3.3; `Agg()` is the monoid identity."""

    var n: Int
    var resolved: Int
    var sum_mu: UInt64
    var sum_lambda: UInt64
    var periodic: Int
    var has_w: Int
    var w_seed: Int
    var w_mu: Int
    var w_lambda: Int

    def __init__(out self):
        self = Agg(0, 0, 0, 0, 0, 0, 0, 0, 0)

    def __init__(
        out self, n: Int, resolved: Int, sum_mu: UInt64, sum_lambda: UInt64, periodic: Int,
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


def field_names() -> List[String]:
    return ["p", "c", "cap", "lo", "hi", "n", "resolved", "sum_mu", "sum_lambda", "periodic",
            "has_w", "w_seed", "w_mu", "w_lambda"]


def schema() -> Schema:
    """The record of section 3.4 as a certified_records schema: sums below 2^64, the rest below 2^32."""
    var names = field_names()
    var bits = List[Int]()
    for name in names:
        bits.append(64 if name == "sum_mu" or name == "sum_lambda" else 32)
    return Schema(TAG, names^, bits^)


def fields(b: Block, a: Agg) -> List[UInt64]:
    """The fourteen field values of a record, in field order. Two records are
    equal iff their fields are, so replay compares these and encode writes them."""
    return [UInt64(b.p), UInt64(b.c), UInt64(b.cap), UInt64(b.lo), UInt64(b.hi),
            UInt64(a.n), UInt64(a.resolved), a.sum_mu, a.sum_lambda, UInt64(a.periodic),
            UInt64(a.has_w), UInt64(a.w_seed), UInt64(a.w_mu), UInt64(a.w_lambda)]


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


def step(x: Int, c: Int, p: Int) -> Int:
    """`(x^2 + c) mod p` for residues `x, c < p < 2^32`: exact in UInt64."""
    var y = UInt64(x)
    return Int((y * y + UInt64(c)) % UInt64(p))


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
    """`""` when the block is well-formed (section 3.1), else `malformed:<field>`."""
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
    return ""


struct Visited(Movable):
    """First-seen index plus one of every value the current seed has touched.

    A table of `p` words when `p < 2^24`; above that the table would reach
    16 GB, so the values go in a hash map sized by the trajectory instead.
    """

    var dense: Bool
    var table: List[UInt32]
    var trail: List[Int]
    var hashed: Dict[Int, Int]

    def __init__(out self, p: Int):
        self.dense = p < TABLE_BOUND
        self.table = List[UInt32](length=p if self.dense else 0, fill=0)
        self.trail = List[Int]()
        self.hashed = Dict[Int, Int]()

    def seen(self, x: Int) -> Int:
        if self.dense:
            return Int(self.table[x])
        return self.hashed.get(x, 0)

    def mark(mut self, x: Int, j: Int):
        if self.dense:
            self.table[x] = UInt32(j + 1)
            self.trail.append(x)
        else:
            self.hashed[x] = j + 1

    def clear(mut self):
        for v in self.trail:
            self.table[v] = 0
        self.trail.clear()
        self.hashed = Dict[Int, Int]()

    def leaf(mut self, b: Block, seed: Int) -> Agg:
        """The census of the single seed: resolved iff the first repeat index `j <= cap`."""
        var x = seed
        var j = 0
        var result = Agg(1, 0, 0, 0, 0, 0, 0, 0, 0)
        while True:
            var seen = self.seen(x)
            if seen > 0:
                var mu = seen - 1
                var lam = j - mu
                result = Agg(1, 1, UInt64(mu), UInt64(lam), 1 if mu == 0 else 0, 1, seed, mu, lam)
                break
            if j == b.cap:
                break
            self.mark(x, j)
            x = step(x, b.c, b.p)
            j += 1
        self.clear()
        return result^


def census(b: Block) raises -> Agg:
    """Exact census of a well-formed block; a malformed one raises its verdict."""
    var refusal = request_verdict(b)
    if refusal.byte_length() > 0:
        raise Error(refusal)
    var visited = Visited(b.p)
    var acc = Agg()
    for s in range(b.lo, b.hi):
        acc = merge(acc, visited.leaf(b, s))
    return acc^


def encode(b: Block, a: Agg) -> String:
    return codec.encode(schema(), fields(b, a))


struct Decoded(Movable):
    """A decoded record, or the `malformed:<field>` reason it is not one."""

    var reason: String
    var block: Block
    var agg: Agg

    def __init__(out self, reason: String, var block: Block, var agg: Agg):
        self.reason = reason
        self.block = block^
        self.agg = agg^


def decode(line: String) -> Decoded:
    """Total inverse of `encode`: every other string is `malformed:<field>`."""
    var d = codec.decode(schema(), line)
    if d.reason.byte_length() > 0:
        return Decoded(d.reason, Block(0, 0, 0, 0, 0), Agg())
    var v = d.values.copy()
    return Decoded(
        "",
        Block(Int(v[0]), Int(v[1]), Int(v[2]), Int(v[3]), Int(v[4])),
        Agg(Int(v[5]), Int(v[6]), v[7], v[8], Int(v[9]), Int(v[10]), Int(v[11]), Int(v[12]), Int(v[13])),
    )


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
        xs.append(step(xs[len(xs) - 1], b.c, b.p))
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
        var mismatch = codec.first_mismatch(schema(), fields(d.block, d.agg), fields(d.block, census(d.block)), start=5)
        if mismatch.byte_length() > 0:
            return mismatch
    except e:
        return "infra:" + String(e)
    var w = witness_verdict(d.block, d.agg)
    return w if w.byte_length() > 0 else "accepted"
