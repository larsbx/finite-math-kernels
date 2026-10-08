# Julia kernel for u32-prime-field-orbit-v1 (see ../CONTRACT.md).
#
# The same prefix-sharing depth-first walk as the Rust and Mojo kernels: the
# word tree is cut at depth CUT into 4 * 3^(CUT-1) independent subtrees, which
# worker tasks claim from an atomic counter; every aggregate is commutative, so
# the record does not depend on the schedule. Residues are reduced by
# conditional subtraction, as in the other kernels.
#
# This is a performance kernel, not the Julia oracle: the oracle is the
# separately pinned larsbx/julia-oracle-lab, and the two share no code.
#
# Usage: julia --threads <t> census.jl <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>
# Julia compiles on first call, so the kernel is warmed on a short word before
# the timed region; kernel_ns is the warm run, and the harness's wall time
# still carries the compilation.

const V4 = NTuple{4,UInt32}
const H0 = 0x9e3779b9
const CUT = 6
const NONE = typemax(UInt64)

struct Record
    words::UInt64
    zero_hits::NTuple{4,UInt64}
    first_zero::UInt64  # NONE when no endpoint has a zero coordinate
    hash_sum::UInt32    # UInt32 arithmetic wraps, as the contract requires
    hash_xor::UInt32
end

const EMPTY = Record(0, (0, 0, 0, 0), NONE, 0, 0)

merge(a::Record, b::Record) = Record(a.words + b.words, a.zero_hits .+ b.zero_hits,
    min(a.first_zero, b.first_zero), a.hash_sum + b.hash_sum, a.hash_xor ⊻ b.hash_xor)

struct Census
    p::UInt64
    length::Int
    seed::V4
    stride::UInt64
end

@inline function mix32(x::UInt32)
    x ⊻= x >> 16
    x *= 0x7feb352d
    x ⊻= x >> 15
    x *= 0x846ca68b
    x ⊻ (x >> 16)
end

"`x mod p` for `x < 2p`, by one conditional subtraction."
@inline fold(c::Census, x::UInt64) = x >= c.p ? x - c.p : x

"Generator `S_letter` (letters 0..3): `(2s - v_i) mod p`, every operand below `4p < 2^34`."
@inline function step(c::Census, v::V4, letter::Int)
    vi = UInt64(v[letter+1])
    s = fold(c, fold(c, sum(UInt64, v) - vi))
    d = fold(c, 2s)
    Base.setindex(v, fold(c, d + c.p - vi) % UInt32, letter + 1)
end

@inline function leaf(w::UInt64, e::V4)
    h = foldl((h, x) -> mix32(h ⊻ x), e; init=H0)
    Record(1, map(x -> UInt64(iszero(x)), e), any(iszero, e) ? w : NONE, h, h)
end

"The first `n` letters of word `w` (the contract's word indexing) applied to the seed: the last letter and the vector."
function descend(c::Census, n::Int, w::UInt64)
    last, q = Int(w % 4), w ÷ 4
    v = step(c, c.seed, last)
    for _ in 2:n
        r = Int(q % 3)
        q ÷= 3
        last = r + (r >= last)
        v = step(c, v, last)
    end
    (last, v)
end

"Depth-first below one node: `n` levels left, `wt` the index weight of the next level."
function walk(c::Census, n::Int, last::Int, w::UInt64, wt::UInt64, v::V4)::Record
    n == 0 && return leaf(w, v)
    acc = EMPTY
    for r in 0:2
        letter = r + (r >= last)
        acc = merge(acc, walk(c, n - 1, letter, w + UInt64(r) * wt, 3wt, step(c, v, letter)))
    end
    acc
end

"The subtree below prefix `t` of the `4 * 3^(cut-1)` prefixes of length `cut`."
function subtree(c::Census, cut::Int, t::UInt64)
    last, v = descend(c, cut, t)
    walk(c, c.length - cut, last, t, UInt64(4 * 3^(cut - 1)), v)
end

function census(c::Census, threads::Int)
    cut = min(CUT, c.length)
    tasks = 4 * 3^(cut - 1)
    next = Threads.Atomic{Int}(0)
    worker() = begin
        acc = EMPTY
        while (t = Threads.atomic_add!(next, 1)) < tasks
            acc = merge(acc, subtree(c, cut, UInt64(t)))
        end
        acc
    end
    rec = reduce(merge, fetch.([Threads.@spawn worker() for _ in 1:threads]); init=EMPTY)
    # Samples are recomputed from their indices rather than tested for at every leaf.
    samples = [(w, descend(c, c.length, w)[2]) for w in UInt64(0):c.stride:rec.words-1]
    (rec, samples)
end

function render(io::IO, c::Census, r::Record, samples)
    println(io, "contract u32-prime-field-orbit-v1")
    println(io, "p ", c.p)
    println(io, "length ", c.length)
    println(io, "words ", r.words)
    println(io, "zero_hits ", join(r.zero_hits, ' '))
    println(io, "first_zero ", r.first_zero == NONE ? "none" : r.first_zero)
    println(io, "hash_sum ", r.hash_sum)
    println(io, "hash_xor ", r.hash_xor)
    for (w, e) in samples
        println(io, "sample ", w, ' ', join(e, ' '))
    end
end

function main(args::Vector{String})
    a = tryparse.(UInt64, args)
    if length(a) != 8 || any(isnothing, a) || !(2 < a[1] < UInt64(1) << 32 && isodd(a[1]) && 1 <= a[2] <= 40 && a[7] >= 1 && a[8] >= 1)
        println(stderr, "usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>; arguments outside the contract")
        exit(2)
    end
    p, len, stride, threads = a[1], Int(a[2]), a[7], Int(a[8])
    threads > Threads.nthreads() && (println(stderr, "unsupported: ", threads, " threads requested, julia started with ", Threads.nthreads()); exit(3))
    c = Census(p, len, ntuple(k -> UInt32(a[2+k] % p), 4), stride)
    census(Census(p, min(len, CUT + 1), c.seed, stride), threads)  # compile every method outside the timed region
    start = time_ns()
    rec, samples = census(c, threads)
    elapsed = time_ns() - start
    buf = IOBuffer()
    render(buf, c, rec, samples)
    write(stdout, take!(buf))
    println(stderr, "kernel_ns ", elapsed)
end

main(ARGS)
