# census.bend: the Bend 2 challenger for contract orbit-census-v1.
#
#   bend census.bend -o census-bend2
#   census-bend2 --threads T -- P C CAP LO HI
#
# prints one line: the canonical record (docs/polyglot-orbit-census-design.md,
# section 3.4), or `malformed:<field>` / `unsupported:<field>` as the Mojo CLI
# does. It is non-authoritative: the orchestrator hands every record to the
# Mojo replay predicate, and only that predicate accepts.
#
# Declared domain (section 3.6): p < 2^24, the Mojo kernel's. Bend 2 has no
# integer wider than U32. For x < 2^16, x^2 < 2^32 is exact; above that,
# x^2 mod p is double-and-add over the 24 bits of x, reducing each sum
# a + b < 2^25 by one conditional subtraction (no division). The sums are
# Nat: each is at most n p <= p^2 <= (2^24 - 3)^2, below 2^48 - 1, the largest
# immediate Nat. The runtime aborts on a Nat past that rather than wrapping,
# so an overflow cannot become a wrong record.
#
# Each seed runs Brent's cycle detection, which needs no memory. Its result is
# the contract's by definition: j = mu + lambda is the first repeat index,
# however it was found, and the seed is resolved iff j <= cap. Termination is
# by Nat fuel. Brent's hare meets the tortoise by position 2^k - 1 + lambda,
# where 2^k is the first power of two with 2^k >= max(mu + 1, lambda); that is
# below 3 (mu + lambda) + 2 <= 3p + 2. The second phase takes at most
# lambda + mu <= p steps. The fuel covers both, so running out is unreachable.
# If it happens anyway, the program exits with status 3 and no record.
#
# Seeds split in half down a balanced fork-join tree (`a b = f(x) g(y)`), and
# the partial aggregates merge back up it.
import Base

type Blk is Data:
  Blk{p: U32, c: U32, cap: U32}

type Agg is Data:
  Agg{n: U32, resolved: U32, sum_mu: Nat, sum_lambda: Nat, periodic: U32,
      has_w: U32, w_seed: U32, w_mu: U32, w_lambda: U32, fault: U32}

def none() -> U32:
  4294967295

def empty() -> Agg:
  Agg{0, 0, 0n, 0n, 0, 0, 0, 0, 0, 0}

# a + b mod p for residues a, b < p < 2^24: the sum is below 2^25
def madd(+p: U32, +a: U32, +b: U32) -> U32:
  +t = (a + b : U32)
  Bool.pick(U32, U32.is_ge(t, p), (t - p : U32), t)

# a * b mod p: double-and-add over bits n - 1 .. 0 of b, high bit first
def mulmod(+n: Nat, +p: U32, +a: U32, +b: U32, +r: U32) -> U32:
  match n:
    case 0n:
      r
    case 1n+k:
      +d = madd(p, r, r)
      mulmod(k, p, a, b, Bool.pick(U32, U32.is_eq(U32.and(U32.shrn(b, k), 1), 1), madd(p, d, a), d))

# x^2 mod p. Below 2^16, x^2 < 2^32 is exact in U32 for any p, and one
# (software) division is cheaper than 24 doublings; above, double-and-add.
def square(+p: U32, +x: U32, small: Bool) -> U32:
  match small:
    case True{}:
      U32.mod((x * x : U32), p)
    case False{}:
      mulmod(24n, p, x, x, 0)

# f(x) = (x^2 + c) mod p
def f(+b: Blk, +x: U32) -> U32:
  match b:
    case Blk{p, c, cap}:
      madd(p, square(p, x, U32.is_lt(x, 65536)), c)

# f applied n times
def advance(n: Nat, +b: Blk, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+k:
      advance(k, b, f(b, x))

# Brent, phase 1: lambda, or none() if the fuel runs out
def brent(fuel: Nat, +b: Blk, +tort: U32, +hare: U32, +power: U32, +lam: U32, met: Bool) -> U32:
  match fuel met:
    case 0n _:
      none()
    case 1n+k True{}:
      lam
    case 1n+k False{}:
      +reset = U32.is_eq(power, lam)
      +t = Bool.pick(U32, reset, hare, tort)
      +h = f(b, hare)
      +l = (Bool.pick(U32, reset, 0, lam) + 1 : U32)
      brent(k, b, t, h, Bool.pick(U32, reset, (power * 2 : U32), power), l, U32.is_eq(t, h))

# Brent, phase 2: mu, walking two pointers lambda apart until they meet
def meet(fuel: Nat, +b: Blk, +t: U32, +h: U32, +mu: U32, met: Bool) -> U32:
  match fuel met:
    case 0n _:
      none()
    case 1n+k True{}:
      mu
    case 1n+k False{}:
      +t2 = f(b, t)
      +h2 = f(b, h)
      meet(k, b, t2, h2, (mu + 1 : U32), U32.is_eq(t2, h2))

def fuel(+b: Blk, +k: U32) -> Nat:
  match b:
    case Blk{p, c, cap}:
      U32.to_nat((k * p + 3 : U32))

def leaf.of(+b: Blk, +seed: U32, +mu: U32, +lam: U32) -> Agg:
  match b:
    case Blk{p, c, cap}:
      +bad = U32.is_eq(mu, none()) || U32.is_eq(lam, none())
      +ok = Bool.not(bad) && U32.is_le((mu + lam : U32), cap)
      +r = Bool.to_u32(ok)
      Agg{1, r, U32.to_nat(Bool.pick(U32, ok, mu, 0)), U32.to_nat(Bool.pick(U32, ok, lam, 0)), Bool.to_u32(ok && U32.is_eq(mu, 0)),
          r, Bool.pick(U32, ok, seed, 0), Bool.pick(U32, ok, mu, 0), Bool.pick(U32, ok, lam, 0), Bool.to_u32(bad)}

def leaf.mu(+b: Blk, +seed: U32, +lam: U32) -> Agg:
  +h = advance(U32.to_nat(lam), b, seed)
  leaf.of(b, seed, meet(fuel(b, 1), b, seed, h, 0, U32.is_eq(seed, h)), lam)

def leaf(+b: Blk, +seed: U32) -> Agg:
  +h = f(b, seed)
  +lam = brent(fuel(b, 3), b, seed, h, 1, 1, U32.is_eq(seed, h))
  leaf.mu(b, seed, Bool.pick(U32, U32.is_eq(lam, none()), 0, lam))

# is (la, sa) at least as good a witness as (lb, sb): longer rho, then smaller seed
def first(+ha: U32, +la: U32, +sa: U32, +hb: U32, +lb: U32, +sb: U32) -> Bool:
  U32.is_eq(hb, 0) || (U32.is_ne(ha, 0) && (U32.is_gt(la, lb) || (U32.is_eq(la, lb) && U32.is_le(sa, sb))))

def merge(x: Agg, y: Agg) -> Agg:
  match x y:
    case Agg{n, r, sm, sl, pe, +hw, +ws, +wm, +wl, fa} Agg{n2, r2, sm2, sl2, pe2, +hw2, +ws2, +wm2, +wl2, fa2}:
      +a = first(hw, (wm + wl : U32), ws, hw2, (wm2 + wl2 : U32), ws2)
      Agg{(n + n2 : U32), (r + r2 : U32), Nat.add(sm, sm2), Nat.add(sl, sl2), (pe + pe2 : U32),
          Bool.pick(U32, a, hw, hw2), Bool.pick(U32, a, ws, ws2), Bool.pick(U32, a, wm, wm2),
          Bool.pick(U32, a, wl, wl2), U32.or(fa, fa2)}

# seeds s .. s + n - 1, one after another
def seq(n: Nat, +b: Blk, +s: U32, acc: Agg) -> Agg:
  match n:
    case 0n:
      acc
    case 1n+k:
      seq(k, b, (s + 1 : U32), merge(acc, leaf(b, s)))

# seeds lo .. hi - 1, halved d times into balanced parallel calls
def census(+d: Nat, +b: Blk, +lo: U32, +hi: U32) -> Agg:
  match d:
    case 0n:
      seq(U32.to_nat((hi - lo : U32)), b, lo, empty())
    case 1n+k:
      +mid = (lo + ((hi - lo : U32) >> 1n) : U32)
      a z = census(k, b, lo, mid) census(k, b, mid, hi)
      merge(a, z)

def shows(xs: List<&2, U32>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case Con{h, t}:
      U32.show(h) <> shows(t)

# the record line, or "" when a seed ran out of fuel (unreachable; see above)
def render(+b: Blk, +lo: U32, +hi: U32, x: Agg) -> String:
  match b x:
    case Blk{p, c, cap} Agg{n, r, sm, sl, pe, hw, ws, wm, wl, +fa}:
      Bool.pick(String, U32.is_ne(fa, 0), "",
        "orbit-census-v1 " ++ String.join(List.append(&2, String, shows([p, c, cap, lo, hi, n, r]),
          Nat.show(sm) <> Nat.show(sl) <> shows([pe, hw, ws, wm, wl])), " ") ++ "\n")

# trial division by d = 2 .. 65535, enough for every p < 2^32 (65535^2 < 2^32);
# `past` is d^2 > p, `hit` is d | p
def prime.go(n: Nat, +p: U32, +d: U32, past: Bool, hit: Bool) -> Bool:
  match n past hit:
    case 0n _ _:
      True{}
    case 1n+k True{} _:
      True{}
    case 1n+k False{} True{}:
      False{}
    case 1n+k False{} False{}:
      +e = (d + 1 : U32)
      prime.go(k, p, e, U32.is_gt((e * e : U32), p), U32.is_eq(U32.mod(p, e), 0))

def prime(+p: U32) -> Bool:
  U32.is_ge(p, 2) && prime.go(65534n, p, 2, U32.is_gt(4, p), U32.is_eq(U32.mod(p, 2), 0))

# the first refusal in the contract's order (section 3.1, then this domain), or ""
def refusal(+p: U32, +c: U32, +lo: U32, +hi: U32) -> String:
  Bool.pick(String, Bool.not(prime(p)), "malformed:p",
  Bool.pick(String, U32.is_ge(c, p), "malformed:c",
  Bool.pick(String, U32.is_gt(lo, hi), "malformed:lo",
  Bool.pick(String, U32.is_gt(hi, p), "malformed:hi",
  Bool.pick(String, U32.is_ge(p, 16777216), "unsupported:p", "")))))

def canonical.if(+s: String, m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{+v}:
      Bool.pick(Maybe<&2, U32>, String.eq(U32.show(v), s), Some{v}, None{})

# a canonical unsigned decimal below 2^32: it must print back as itself
def canonical(t: String) -> Maybe<&2, U32>:
  +s = t
  canonical.if(s, U32.read(s))

def names() -> List<&2, String>:
  ["p", "c", "cap", "lo", "hi"]

def parse.if(m: Maybe<&2, U32>, +name: String, rest: Result<&2, &2, String, List<&2, U32>>) -> Result<&2, &2, String, List<&2, U32>>:
  match m rest:
    case None{} _:
      Fail{name}
    case Some{v} Done{vs}:
      Done{v <> vs}
    case Some{v} Fail{e}:
      Fail{e}

# the arguments as numbers, or the first field that is not a canonical decimal
def parse(xs: List<String>, ns: List<&2, String>) -> Result<&2, &2, String, List<&2, U32>>:
  match xs ns:
    case Nil{} Nil{}:
      Done{[]}
    case Con{h, t} Con{+name, u}:
      parse.if(canonical(h), name, parse(t, u))
    case _ _:
      Fail{"arity"}

def answer.if(+p: U32, +c: U32, +cap: U32, +lo: U32, +hi: U32, why: String, ok: Bool) -> String:
  match ok:
    case True{}:
      render(Blk{p, c, cap}, lo, hi, census(10n, Blk{p, c, cap}, lo, hi))
    case False{}:
      why ++ "\n"

def answer(+p: U32, +c: U32, +cap: U32, +lo: U32, +hi: U32, +why: String) -> String:
  answer.if(p, c, cap, lo, hi, why, String.eq(why, ""))

def reply(r: Result<&2, &2, String, List<&2, U32>>) -> String:
  match r:
    case Fail{e}:
      "malformed:" ++ e ++ "\n"
    case Done{[+p, +c, +cap, +lo, +hi]}:
      answer(p, c, cap, lo, hi, refusal(p, c, lo, hi))
    case Done{_}:
      "malformed:arity\n"

def emit(+out: String, fault: Bool) -> IO(Unit):
  match fault:
    case True{}:
      IO.die(Unit, 3, "fuel exhausted: no record")
    case False{}:
      IO.write(out)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +out : String = reply(parse(args, names()))
    emit(out, String.eq(out, ""))
