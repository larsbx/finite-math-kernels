# Sums past 2^32 through the Bend 2 challenger's own merge and render.
#
# An honest record with a sum of 2^32 or more costs at least 2^32 steps, so
# the census gate cannot reach one cheaply. This drives the challenger's
# `merge` and `render` directly with sums that cross 2^32 and reach the
# domain's bound p^2 for p = 2^24 - 3, and prints the rendered lines; the test
# compares them with the reference's arithmetic.
import Base
import ../../benchmarks/frontier/census.bend as C

def agg(+s: Nat, +l: Nat) -> C.Agg:
  C.Agg{1, 1, s, l, 0, 1, 0, 0, 1, 0}

def main() -> IO(Unit):
  do IO<Unit>:
    +big : Nat = U32.to_nat(4294967295)
    +p : Nat = U32.to_nat(16777213)
    IO.write(C.render(C.Blk{16777213, 0, 16777213}, 0, 2, C.merge(agg(big, 1n), agg(1n, big))))
    IO.write(C.render(C.Blk{16777213, 0, 16777213}, 0, 2, C.merge(agg(Nat.mul(p, p), 0n), agg(0n, Nat.mul(p, p)))))
