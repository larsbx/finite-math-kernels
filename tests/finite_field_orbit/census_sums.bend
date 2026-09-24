# Sums past 2^32 through the Bend 2 challenger's own merge and render.
#
# An honest record with a sum of 2^32 or more costs at least 2^32 steps, so
# the census gate cannot reach one cheaply. This drives the challenger's
# `merge` and `render` directly: a carry out of the low half (2^32), the
# domain's bound p^2 for p = 2^32 - 5, and 2^64 - 1, the largest two-half
# value. The test compares the lines with Python's integers.
import Base
import ../../benchmarks/frontier/census.bend as C

def agg(+s: C.U64, +l: C.U64) -> C.Agg:
  C.Agg{1, 1, s, l, 0, 1, 0, 0, 1, 0}

def line(x: C.Agg, y: C.Agg) -> String:
  C.render(C.Blk{4294967291, 0, 4294967291}, 0, 2, C.merge(x, y))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.write(line(agg(C.U64{0, 4294967295}, C.U64{0, 1}), agg(C.U64{0, 1}, C.U64{0, 4294967295})))
    IO.write(line(agg(C.U64{4294967286, 0}, C.U64{0, 0}), agg(C.U64{0, 25}, C.U64{4294967286, 25})))
    IO.write(line(agg(C.U64{4294967295, 4294967294}, C.U64{0, 0}), agg(C.U64{0, 1}, C.U64{0, 0})))
