# Mojo kernel for u32-prime-field-orbit-v1 (see ../CONTRACT.md).
#
# The same prefix-sharing depth-first walk as the Rust baseline: the word tree
# is cut at a fixed depth into independent subtrees, each reduced to a partial
# record in its own slot, and the slots are merged in task order.
#
# Usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>
# threads = 1 walks the subtrees in a plain loop; otherwise MAX's CPU runtime
# (`max.algorithm.parallelize`) spreads them over that many workers.

from max.algorithm import parallelize
from std.sys import argv, stderr
from std.time import perf_counter_ns

comptime H0 = UInt32(0x9E3779B9)
comptime CUT = 6


@always_inline
def mix32(x0: UInt32) -> UInt32:
    var x = x0
    x ^= x >> 16
    x *= 0x7FEB352D
    x ^= x >> 15
    x *= 0x846CA68B
    return x ^ (x >> 16)


@fieldwise_init
struct Vec4(Copyable, ImplicitlyCopyable):
    var a: SIMD[DType.uint32, 4]


@fieldwise_init
struct Partial(Copyable, ImplicitlyCopyable):
    var words: UInt64
    var zero_hits: SIMD[DType.uint64, 4]
    var first_zero: UInt64  # UInt64.MAX when none
    var hash_sum: UInt32
    var hash_xor: UInt32

    @staticmethod
    def empty() -> Partial:
        return Partial(0, SIMD[DType.uint64, 4](0), UInt64.MAX, 0, 0)

    def absorb(mut self, o: Partial):
        self.words += o.words
        self.zero_hits += o.zero_hits
        self.first_zero = min(self.first_zero, o.first_zero)
        self.hash_sum += o.hash_sum
        self.hash_xor ^= o.hash_xor


struct Census(Copyable):
    var p: UInt64
    var length: Int
    var seed: SIMD[DType.uint32, 4]
    var stride: UInt64
    var weight: List[UInt64]

    def __init__(out self, p: UInt64, length: Int, seed: SIMD[DType.uint32, 4], stride: UInt64):
        self.p = p
        self.length = length
        self.seed = seed
        self.stride = stride
        self.weight = List[UInt64]()
        var w = UInt64(1)
        for k in range(length):
            self.weight.append(w)
            w = UInt64(4) if k == 0 else w * 3

    @always_inline
    def fold(self, x: UInt64) -> UInt64:
        """`x mod p` for `x < 2p`, by one conditional subtraction."""
        return x - self.p if x >= self.p else x

    @always_inline
    def step(self, v: SIMD[DType.uint32, 4], i: Int) -> SIMD[DType.uint32, 4]:
        """`(2 * s - v_i) mod p` without division: every operand stays below `4p < 2^34`."""
        var wide = v.cast[DType.uint64]()
        var vi = wide[i]
        var s = self.fold(self.fold(wide.reduce_add() - vi))
        var d = self.fold(2 * s)
        var out = v
        out[i] = UInt32(self.fold(d + self.p - vi))
        return out

    def leaf(self, mut rec: Partial, w: UInt64, e: SIMD[DType.uint32, 4]):
        var h = H0
        for k in range(4):
            h = mix32(h ^ e[k])
        var zeros = e.eq(0)
        rec.words += 1
        rec.zero_hits += zeros.cast[DType.uint64]()
        if zeros.reduce_or() and w < rec.first_zero:
            rec.first_zero = w
        rec.hash_sum += h
        rec.hash_xor ^= h

    def descend(self, n: Int, w: UInt64, mut last: Int) -> SIMD[DType.uint32, 4]:
        """The first `n` letters of word `w` (the contract's word indexing) applied
        to the seed; `last` receives the last letter."""
        last = Int(w % 4)
        var v = self.step(self.seed, last)
        var q = w // 4
        for _ in range(1, n):
            var r = Int(q % 3)
            q //= 3
            last = r + Int(r >= last)
            v = self.step(v, last)
        return v

    def walk(self, mut rec: Partial, depth: Int, last: Int, w: UInt64, v: SIMD[DType.uint32, 4]):
        if depth == self.length:
            self.leaf(rec, w, v)
            return
        for r in range(3):
            var letter = r + Int(r >= last)
            self.walk(rec, depth + 1, letter, w + UInt64(r) * self.weight[depth], self.step(v, letter))

    def subtree(self, cut: Int, t: UInt64) -> Partial:
        var last = 0
        var v = self.descend(cut, t, last)
        var rec = Partial.empty()
        self.walk(rec, cut, last, t, v)
        return rec^


def run(c: Census, threads: Int) -> Partial:
    var cut = min(CUT, c.length)
    var tasks = 4 * 3 ** (cut - 1)
    var parts = List[Partial](length=tasks, fill=Partial.empty())
    var slots = parts.unsafe_ptr()

    def task(t: Int) {slots, c, cut}:
        slots[unsafe_offset=t] = c.subtree(cut, UInt64(t))

    if threads == 1:
        for t in range(tasks):
            task(t)
    else:
        parallelize(task, tasks, threads)
    var rec = Partial.empty()
    for t in range(tasks):
        rec.absorb(parts[t])
    return rec^


def render(c: Census, rec: Partial) -> String:
    var out = String("contract u32-prime-field-orbit-v1\n")
    out += "p " + String(c.p) + "\nlength " + String(c.length) + "\nwords " + String(rec.words) + "\nzero_hits"
    for k in range(4):
        out += " " + String(rec.zero_hits[k])
    out += "\nfirst_zero " + (String("none") if rec.first_zero == UInt64.MAX else String(rec.first_zero))
    out += "\nhash_sum " + String(rec.hash_sum) + "\nhash_xor " + String(rec.hash_xor) + "\n"
    # Samples are recomputed from their indices rather than tested for at every leaf.
    var last = 0
    for w in range(0, Int(rec.words), Int(c.stride)):
        var e = c.descend(c.length, UInt64(w), last)
        out += "sample " + String(w)
        for k in range(4):
            out += " " + String(e[k])
        out += "\n"
    return out


def main() raises:
    var args = argv()
    if len(args) != 9:
        raise Error("usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>")
    var p = UInt64(atol(args[1]))
    var length = atol(args[2])
    var stride = UInt64(atol(args[7]))
    var threads = atol(args[8])
    if not (p > 2 and p < (UInt64(1) << 32) and p % 2 == 1 and length >= 1 and stride >= 1):
        raise Error("arguments outside the contract")
    if threads < 1:
        raise Error("arguments outside the contract")
    var seed = SIMD[DType.uint32, 4](0)
    for k in range(4):
        seed[k] = UInt32(UInt64(atol(args[3 + k])) % p)
    var c = Census(p, length, seed, stride)
    var start = perf_counter_ns()
    var rec = run(c, threads)
    var ns = perf_counter_ns() - start
    print(render(c, rec), end="")
    print("kernel_ns", ns, file=stderr)
