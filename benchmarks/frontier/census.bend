# census.bend: the Bend challenger for contract orbit-census-v1.
#
#   bend --hvm-bin HVM run-c census.bend P C CAP LO HI      (Bend 1: bend-lang 0.2.38)
#
# prints one canonical record line (docs/polyglot-orbit-census-design.md,
# section 3.4). It is non-authoritative: the orchestrator hands every line to
# the Mojo replay predicate, and only that predicate accepts.
#
# Declared domain (section 3.6): p <= 4093. HVM2 arithmetic is u24 and wraps
# silently, so (p - 1)^2 must stay below 2^24; the CLI refuses arguments of
# 2^24 or more, but a product that overflows gives a wrong answer with no
# error. The orchestrator refuses out-of-domain blocks before dispatch and
# rejects any line whose echoed block differs from the request.
#
# The census splits the seed range in half and recurses on both halves; HVM2
# evaluates the two calls in parallel without any explicit thread.

type Agg:
  Agg { n, resolved, sum_mu, sum_lambda, periodic, has_w, w_seed, w_mu, w_lambda }

# Seed `seed` at index j with value x: resolved iff the first repeat index j <= cap.
def rho(p, c, cap, seed, seen, x, j):
  (got, seen) = Map/get_check(seen, x)
  match got:
    case Maybe/Some:
      mu = got.value - 1
      return Agg/Agg(1, 1, mu, j - mu, mu == 0, 1, seed, mu, j - mu)
    case Maybe/None:
      if j == cap:
        return Agg/Agg(1, 0, 0, 0, 0, 0, 0, 0, 0)
      else:
        return rho(p, c, cap, seed, Map/set(seen, x, j + 1), (x * x % p + c) % p, j + 1)

# Is a's witness at least as good as b's: longer rho, then smaller seed.
def witness_first(a_has, a_len, a_seed, b_has, b_len, b_seed):
  if b_has == 0:
    return 1
  elif a_has == 0:
    return 0
  else:
    return (a_len > b_len) | ((a_len == b_len) & (a_seed <= b_seed))

def merge(a, b):
  open Agg: a
  open Agg: b
  if witness_first(a.has_w, a.w_mu + a.w_lambda, a.w_seed, b.has_w, b.w_mu + b.w_lambda, b.w_seed):
    w = (a.has_w, a.w_seed, a.w_mu, a.w_lambda)
  else:
    w = (b.has_w, b.w_seed, b.w_mu, b.w_lambda)
  (has_w, w_seed, w_mu, w_lambda) = w
  return Agg/Agg(a.n + b.n, a.resolved + b.resolved, a.sum_mu + b.sum_mu, a.sum_lambda + b.sum_lambda,
                 a.periodic + b.periodic, has_w, w_seed, w_mu, w_lambda)

def census(p, c, cap, lo, hi):
  n = hi - lo
  if n == 0:
    return Agg/Agg(0, 0, 0, 0, 0, 0, 0, 0, 0)
  elif n == 1:
    return rho(p, c, cap, lo, Map/empty, lo, 0)
  else:
    mid = lo + n / 2
    return merge(census(p, c, cap, lo, mid), census(p, c, cap, mid, hi))

def append(a, b):
  match a:
    case String/Nil:
      return b
    case String/Cons:
      return String/Cons(a.head, append(a.tail, b))

# Decimal fields separated by single spaces: the canonical encoding.
def join(xs):
  match xs:
    case List/Nil:
      return ""
    case List/Cons:
      match rest = xs.tail:
        case List/Nil:
          return u24/to_string(xs.head)
        case List/Cons:
          return append(u24/to_string(xs.head), String/Cons(' ', join(rest)))

def main(p, c, cap, lo, hi):
  a = census(p, c, cap, lo, hi)
  open Agg: a
  fields = [p, c, cap, lo, hi, a.n, a.resolved, a.sum_mu, a.sum_lambda, a.periodic, a.has_w, a.w_seed, a.w_mu, a.w_lambda]
  return IO/print(append("orbit-census-v1 ", append(join(fields), "\n")))
