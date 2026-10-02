# Bend kernel for u32-prime-field-orbit-v1 (see ../CONTRACT.md).
#
# The word tree is cut at depth CUT into 4 * 3^(CUT-1) prefixes; a balanced
# fork-join bisection over the prefix range (padded to a power of two) hands
# each prefix's subtree to a sequential depth-first walk that shares prefixes,
# and the partial records merge back up the fork tree. Samples are recomputed
# afterwards from their indices. Bend has no type wider than U32, so residues
# stay in U32 by conditional subtraction: the same residues as the contract's
# u64 formula, with no division on the hot path.
#
# Usage: census --threads <t> -- <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>
# (the runtime owns --threads; the trailing threads argument is ignored here).
import Base

type V is Data:
  V{a: U32, b: U32, c: U32, d: U32}

type R is Data:
  R{n: U32, z0: U32, z1: U32, z2: U32, z3: U32, first: U32, hs: U32, hx: U32}

type Lt is Data:
  L0{}
  L1{}
  L2{}
  L3{}

type Cfg is Data:
  Cfg{p: U32, len: Nat, seed: V, stride: U32}

# prefix depth of the parallel cut: at most 6 (972 subtrees), never past the word
def cut(+len: Nat) -> Nat:
  Nat.min(6n, len)

def Cfg.len(+c: Cfg) -> Nat:
  match c:
    case Cfg{p, len, seed, stride}:
      len

def none() -> U32:
  4294967295

def empty() -> R:
  R{0, 0, 0, 0, 0, none(), 0, 0}

# a + b mod p for residues a, b < p < 2^32: the wrapped sum t overflowed iff
# t < a, and then the true sum t + 2^32 exceeds p, so t - p (wrapping) is exact
def madd(+p: U32, +a: U32, +b: U32) -> U32:
  +t = (a + b : U32)
  Bool.pick(U32, Bool.or(U32.is_lt(t, a), U32.is_ge(t, p)), (t - p : U32), t)

def msub(+p: U32, +a: U32, +b: U32) -> U32:
  +t = (a - b : U32)
  Bool.pick(U32, U32.is_ge(a, b), t, (t + p : U32))

# the reflected coordinate 2 * s - x mod p, s the sum of the other three
def refl(+p: U32, +s: U32, x: U32) -> U32:
  msub(p, madd(p, s, s), x)

def step(+p: U32, l: Lt, +v: V) -> V:
  match l v:
    case L0{} V{a, b, c, d}:
      V{refl(p, madd(p, madd(p, b, c), d), a), b, c, d}
    case L1{} V{a, b, c, d}:
      V{a, refl(p, madd(p, madd(p, a, c), d), b), c, d}
    case L2{} V{a, b, c, d}:
      V{a, b, refl(p, madd(p, madd(p, a, b), d), c), d}
    case L3{} V{a, b, c, d}:
      V{a, b, c, refl(p, madd(p, madd(p, a, b), c), d)}

def mix(+x0: U32) -> U32:
  +x1 = U32.xor(x0, U32.shrn(x0, 16n))
  +x2 = (x1 * 2146121005 : U32)
  +x3 = U32.xor(x2, U32.shrn(x2, 15n))
  +x4 = (x3 * 2221713035 : U32)
  U32.xor(x4, U32.shrn(x4, 16n))

def zero(x: U32) -> U32:
  Bool.to_u32(U32.is_zero(x))

def leaf(+w: U32, +v: V) -> R:
  match v:
    case V{a, b, c, d}:
      +h = mix(U32.xor(mix(U32.xor(mix(U32.xor(mix(U32.xor(2654435769, a)), b)), c)), d))
      +hit = Bool.or(Bool.or(U32.is_zero(a), U32.is_zero(b)), Bool.or(U32.is_zero(c), U32.is_zero(d)))
      R{1, zero(a), zero(b), zero(c), zero(d), Bool.pick(U32, hit, w, none()), h, h}

def merge(x: R, y: R) -> R:
  match x y:
    case R{n, z0, z1, z2, z3, f, hs, hx} R{m, y0, y1, y2, y3, g, gs, gx}:
      R{(n + m : U32), (z0 + y0 : U32), (z1 + y1 : U32), (z2 + y2 : U32), (z3 + y3 : U32),
        U32.min(f, g), (hs + gs : U32), U32.xor(hx, gx)}

def merge3(x: R, y: R, z: R) -> R:
  merge(merge(x, y), z)

# depth-first below one node: n levels left, wt the index weight of the next
# level; the children follow the three letters other than `last`, ascending
def walk(+p: U32, +n: Nat, last: Lt, +w: U32, +wt: U32, +v: V) -> R:
  match n last:
    case 0n _:
      leaf(w, v)
    case 1n+k L0{}:
      +w1 = (w + wt : U32)
      +wt3 = (wt * 3 : U32)
      merge3(walk(p, k, L1{}, w, wt3, step(p, L1{}, v)), walk(p, k, L2{}, w1, wt3, step(p, L2{}, v)),
             walk(p, k, L3{}, (w1 + wt : U32), wt3, step(p, L3{}, v)))
    case 1n+k L1{}:
      +w1 = (w + wt : U32)
      +wt3 = (wt * 3 : U32)
      merge3(walk(p, k, L0{}, w, wt3, step(p, L0{}, v)), walk(p, k, L2{}, w1, wt3, step(p, L2{}, v)),
             walk(p, k, L3{}, (w1 + wt : U32), wt3, step(p, L3{}, v)))
    case 1n+k L2{}:
      +w1 = (w + wt : U32)
      +wt3 = (wt * 3 : U32)
      merge3(walk(p, k, L0{}, w, wt3, step(p, L0{}, v)), walk(p, k, L1{}, w1, wt3, step(p, L1{}, v)),
             walk(p, k, L3{}, (w1 + wt : U32), wt3, step(p, L3{}, v)))
    case 1n+k L3{}:
      +w1 = (w + wt : U32)
      +wt3 = (wt * 3 : U32)
      merge3(walk(p, k, L0{}, w, wt3, step(p, L0{}, v)), walk(p, k, L1{}, w1, wt3, step(p, L1{}, v)),
             walk(p, k, L2{}, (w1 + wt : U32), wt3, step(p, L2{}, v)))

def letter(+u: U32) -> Lt:
  Bool.pick(Lt, U32.is_eq(u, 0), L0{}, Bool.pick(Lt, U32.is_eq(u, 1), L1{}, Bool.pick(Lt, U32.is_eq(u, 2), L2{}, L3{})))

def code(l: Lt) -> U32:
  match l:
    case L0{}:
      0
    case L1{}:
      1
    case L2{}:
      2
    case L3{}:
      3

# the letter after `last` for base-3 digit r: r, skipping last
def next(+r: U32, last: Lt) -> Lt:
  letter((r + Bool.to_u32(U32.is_ge(r, code(last))) : U32))

# follow n more base-3 digits of q from (last, v); answers the last letter and vector
def descend(+p: U32, n: Nat, +q: U32, last: Lt, +v: V) -> Lt & V:
  match n:
    case 0n:
      (last, v)
    case 1n+k:
      +l = next(U32.mod(q, 3), last)
      descend(p, k, U32.div(q, 3), l, step(p, l, v))

# the first n letters of word w applied to the seed
def prefix(+c: Cfg, n: Nat, +w: U32) -> Lt & V:
  match c:
    case Cfg{p, len, seed, stride}:
      +l = letter(U32.mod(w, 4))
      descend(p, Nat.sub(n, 1n), U32.div(w, 4), l, step(p, l, seed))

def weight(n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+k:
      (4 * U32.pow(3, k) : U32)

def subtree.go(+c: Cfg, +t: U32, lv: Lt & V) -> R:
  match c:
    case Cfg{p, len, seed, stride}:
      (l, v) = lv
      walk(p, Nat.sub(len, cut(len)), l, t, weight(cut(len)), v)

def subtree.if(+c: Cfg, +t: U32, real: Bool) -> R:
  match real:
    case False{}:
      empty()
    case True{}:
      subtree.go(c, t, prefix(c, cut(Cfg.len(c)), t))

def subtree(+c: Cfg, +t: U32) -> R:
  subtree.if(c, t, U32.is_lt(t, weight(cut(Cfg.len(c)))))

# prefixes lo .. lo + 2^d - 1, split in two balanced parallel calls
def par(+c: Cfg, +d: Nat, +lo: U32) -> R:
  match d:
    case 0n:
      subtree(c, lo)
    case 1n+k:
      a b = par(c, k, lo) par(c, k, (lo + U32.shln(1, k) : U32))
      merge(a, b)

def show_v(v: V) -> String:
  match v:
    case V{a, b, c, d}:
      String.join([U32.show(a), U32.show(b), U32.show(c), U32.show(d)], " ")

def sample.fin(lv: Lt & V) -> V:
  (l, v) = lv
  v

def sample(+c: Cfg, +w: U32) -> String:
  match c:
    case Cfg{p, len, seed, stride}:
      "sample " ++ U32.show(w) ++ " " ++ show_v(sample.fin(prefix(c, len, w)))

def samples(+c: Cfg, n: Nat, +w: U32) -> List<&2, String>:
  match c n:
    case Cfg{p, len, seed, stride} 0n:
      []
    case Cfg{p, len, seed, stride} 1n+k:
      sample(c, w) <> samples(c, k, (w + stride : U32))

def show_first(+f: U32) -> String:
  Bool.pick(String, U32.is_eq(f, none()), "none", U32.show(f))

def render(+c: Cfg, +words: U32, r: R) -> String:
  match c r:
    case Cfg{p, len, seed, stride} R{n, z0, z1, z2, z3, f, hs, hx}:
      String.join(List.append(&2, String,
        ["contract u32-prime-field-orbit-v1",
         "p " ++ U32.show(p),
         "length " ++ Nat.show(len),
         "words " ++ U32.show(n),
         "zero_hits " ++ String.join([U32.show(z0), U32.show(z1), U32.show(z2), U32.show(z3)], " "),
         "first_zero " ++ show_first(f),
         "hash_sum " ++ U32.show(hs),
         "hash_xor " ++ U32.show(hx)],
        samples(c, U32.to_nat(((words - 1 : U32) / stride + 1 : U32)), 0)), "\n") ++ "\n"

# the command line as numbers; an unreadable argument reads as 0, which the
# contract's p and stride bounds reject downstream
def nums(xs: List<String>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case Con{h, t}:
      Maybe.default(&2, U32, U32.read(h), 0) <> nums(t)

def num(+xs: List<&2, U32>, n: Nat) -> U32:
  Maybe.default(&2, U32, List.get(&2, U32, xs, n), 0)

def total(n: Nat) -> U32:
  (4 * U32.pow(3, Nat.sub(n, 1n)) : U32)

def census(+c: Cfg) -> R:
  par(c, 10n, 0)

# the contract's bounds, plus the U32 word index (length <= 19)
def valid(+c: Cfg) -> Bool:
  match c:
    case Cfg{p, len, seed, stride}:
      U32.is_gt(p, 2) && U32.is_eq(U32.and(p, 1), 1) && Nat.is_lt(0n, len) && Nat.is_le(len, 19n) && U32.is_gt(stride, 0)

def run(+c: Cfg, +len: Nat, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 2, "arguments outside the contract")
    case True{}:
      do IO<Unit>:
        t0 : Nat <- IO.now()
        +r : R = census(c)
        t1 : Nat <- IO.now()
        IO.write(render(c, total(len), r))
        IO.print_err("kernel_ns " ++ Nat.show(Nat.mul(Nat.sub(t1, t0), 1000000n)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +xs : List<&2, U32> = nums(args)
    +c : Cfg = Cfg{num(xs, 0n), U32.to_nat(num(xs, 1n)), V{num(xs, 2n), num(xs, 3n), num(xs, 4n), num(xs, 5n)}, num(xs, 6n)}
    run(c, U32.to_nat(num(xs, 1n)), valid(c))
