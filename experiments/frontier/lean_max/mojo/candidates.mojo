"""Experimental Mojo CPU candidate generator for Lean-MAX unary equality proofs.

CLI: candidates A F N S <kind symbol child>*N <lhs rhs>*S
A: number of atoms; F: number of unary functions.
kind=0 denotes atom (symbol is atom ID, child must be 0).
kind=1 denotes application (symbol is function ID, child is earlier term ID).
The S pairs form the already-established proof frontier. No input file and no
Lean code is evaluated. This program DOES NOT check proof soundness.
Candidate output lines are S/C/T records, as described in CONTRACT.md.

This is intentionally CPU-only. MAX threading or a genuine GPU kernel will be
a separate benchmark lane and must not be inferred from this implementation.
"""

from std.sys import argv


def nat_arg(s: String) raises -> Int:
    var x = atol(s)
    if x < 0 or String(x) != s:
        raise Error("invalid unsigned canonical decimal")
    return x


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) < 5:
        raise Error("usage: candidates A F N S <terms> <steps>")
    var atom_count = nat_arg(args[1])
    var fn_count = nat_arg(args[2])
    var n = nat_arg(args[3])
    var m = nat_arg(args[4])
    if atom_count < 1 or atom_count > 128 or fn_count > 16 or n < 1 or n > 128 or m > 64:
        raise Error("frontier resource cap exceeded")
    if len(args) != 5 + 3 * n + 2 * m:
        raise Error("malformed CLI arity")

    var kinds = List[Int]()
    var symbols = List[Int]()
    var children = List[Int]()
    for i in range(n):
        var k = nat_arg(args[5 + 3 * i])
        var sym = nat_arg(args[6 + 3 * i])
        var child = nat_arg(args[7 + 3 * i])
        if k == 0:
            if sym >= atom_count or child != 0:
                raise Error("bad atom")
        elif k == 1:
            if sym >= fn_count or child >= i:
                raise Error("bad or forward application")
        else:
            raise Error("unsupported term kind")
        for j in range(i):
            if kinds[j] == k and symbols[j] == sym and children[j] == child:
                raise Error("duplicate term")
        kinds.append(k)
        symbols.append(sym)
        children.append(child)

    var lhs = List[Int]()
    var rhs = List[Int]()
    for i in range(m):
        var l = nat_arg(args[5 + 3 * n + 2 * i])
        var r = nat_arg(args[6 + 3 * n + 2 * i])
        if l >= n or r >= n:
            raise Error("proof frontier endpoint outside term table")
        lhs.append(l)
        rhs.append(r)

    # First enumerate symmetry and the unary congruence candidates for every
    # existing equality. The order is a stable part of the interchange format.
    for sid in range(m):
        print("S", rhs[sid], lhs[sid], sid)
        for f in range(fn_count):
            var lapp = -1
            var rapp = -1
            for t in range(n):
                if kinds[t] == 1 and symbols[t] == f:
                    if children[t] == lhs[sid]:
                        lapp = t
                    if children[t] == rhs[sid]:
                        rapp = t
            if lapp != -1 and rapp != -1:
                print("C", lapp, rapp, sid, f)

    # Then enumerate ordered transitivity candidates, including identities.
    # Every ref refers to the input proof frontier, never a fresh result.
    for sid in range(m):
        for tid in range(m):
            if rhs[sid] == lhs[tid]:
                print("T", lhs[sid], rhs[tid], sid, tid)
