# Mojo kernel for u32-prime-field-orbit-v1 (see ../CONTRACT.md).
#
# The same prefix-sharing depth-first walk as the Rust baseline: the word tree
# is cut at a fixed depth into independent subtrees, each reduced to a partial
# record, and the partials are merged.
#
# Usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>
# Only threads = 1 is supported: the pinned nightly's std exposes no
# `parallelize` (or other CPU task runtime), so the cpu_all lane reports
# unsupported rather than silently running serially.

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
struct Partial(Copyable, Movable):
    var words: UInt64
    var zero_hits: SIMD[DType.uint64, 4]
    var first_zero: UInt64  # UInt64.MAX when none
    var hash_sum: UInt32
    var hash_xor: UInt32
    var samples: List[UInt64]  # flattened (w, e0, e1, e2, e3)

    @staticmethod
    def empty() -> Partial:
        return Partial(0, SIMD[DType.uint64, 4](0), UInt64.MAX, 0, 0, List[UInt64]())

    def absorb(mut self, o: Partial):
        self.words += o.words
        self.zero_hits += o.zero_hits
        self.first_zero = min(self.first_zero, o.first_zero)
        self.hash_sum += o.hash_sum
        self.hash_xor ^= o.hash_xor
        self.samples.extend(o.samples.copy())


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
    def step(self, v: SIMD[DType.uint32, 4], i: Int) -> SIMD[DType.uint32, 4]:
        var wide = v.cast[DType.uint64]()
        var vi = wide[i]
        var s = (wide.reduce_add() - vi) % self.p
        var out = v
        out[i] = UInt32((2 * s + 2 * self.p - vi) % self.p)
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
        if w % self.stride == 0:
            rec.samples.append(w)
            for k in range(4):
                rec.samples.append(UInt64(e[k]))

    def walk(self, mut rec: Partial, depth: Int, last: Int, w: UInt64, v: SIMD[DType.uint32, 4]):
        if depth == self.length:
            self.leaf(rec, w, v)
            return
        for r in range(3):
            var letter = r + Int(r >= last)
            self.walk(rec, depth + 1, letter, w + UInt64(r) * self.weight[depth], self.step(v, letter))

    def subtree(self, cut: Int, t: UInt64) -> Partial:
        var last = Int(t % 4)
        var v = self.step(self.seed, last)
        var q = t // 4
        for _ in range(1, cut):
            var r = Int(q % 3)
            q //= 3
            last = r + Int(r >= last)
            v = self.step(v, last)
        var rec = Partial.empty()
        self.walk(rec, cut, last, t, v)
        return rec^


def run(c: Census) -> Partial:
    var cut = min(CUT, c.length)
    var rec = Partial.empty()
    for t in range(4 * 3 ** (cut - 1)):
        rec.absorb(c.subtree(cut, UInt64(t)))
    return rec^


def render(c: Census, rec: Partial) -> String:
    var out = String("contract u32-prime-field-orbit-v1\n")
    out += "p " + String(c.p) + "\nlength " + String(c.length) + "\nwords " + String(rec.words) + "\nzero_hits"
    for k in range(4):
        out += " " + String(rec.zero_hits[k])
    out += "\nfirst_zero " + (String("none") if rec.first_zero == UInt64.MAX else String(rec.first_zero))
    out += "\nhash_sum " + String(rec.hash_sum) + "\nhash_xor " + String(rec.hash_xor) + "\n"
    # Subtrees partition by low index digits, so samples arrive unordered: sort the indices.
    var order = List[Int]()
    for i in range(len(rec.samples) // 5):
        order.append(i)
    for i in range(1, len(order)):
        var j = i
        while j > 0 and rec.samples[5 * order[j - 1]] > rec.samples[5 * order[j]]:
            order.swap_elements(j - 1, j)
            j -= 1
    for i in order:
        out += "sample"
        for k in range(5):
            out += " " + String(rec.samples[5 * i + k])
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
    if threads != 1:
        raise Error("unsupported: no CPU task runtime in this Mojo std")
    var seed = SIMD[DType.uint32, 4](0)
    for k in range(4):
        seed[k] = UInt32(UInt64(atol(args[3 + k])) % p)
    var c = Census(p, length, seed, stride)
    var start = perf_counter_ns()
    var rec = run(c)
    var ns = perf_counter_ns() - start
    print(render(c, rec), end="")
    print("kernel_ns", ns, file=stderr)
