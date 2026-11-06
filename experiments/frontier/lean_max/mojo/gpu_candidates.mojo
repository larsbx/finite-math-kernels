"""Bounded, opt-in device candidate generation; NOT a proof checker.

Authored against the repository's pinned Mojo GPU API. Compilation and actual
device execution require independent validation. No MAX CPU-thread fallback.
CLI: gpu_candidates --gpu A F N S <kind symbol child>*N <lhs rhs>*S
"""
from std.gpu import block_dim, block_idx, thread_idx
from std.gpu.host import DeviceContext
from std.sys import argv, has_accelerator
from std.time import perf_counter_ns


def nat_arg(s: String) raises -> Int:
    # Bound the decimal before machine conversion, including atol overflow.
    if len(s) == 0 or len(s) > 5:
        raise Error("unsigned index overflow")
    var x = atol(s)
    if x < 0 or x > 65535 or String(x) != s:
        raise Error("noncanonical unsigned index")
    return x


def candidates_kernel(
    inp: UnsafePointer[Int32, MutAnyOrigin],
    outp: UnsafePointer[Int32, MutAnyOrigin],
    n: Int, m: Int, f: Int, slots: Int,
):
    var slot = Int(block_idx.x * block_dim.x + thread_idx.x)
    if slot >= slots:
        return
    var base = slot * 6
    # Every field written by exactly one thread, including absent candidates.
    for j in range(6):
        outp[base + j] = -1
    var unary_end = m * (1 + f)
    if slot < unary_end:
        var sid = slot // (1 + f)
        var kind = slot % (1 + f)
        var left = Int(inp[3 * n + 2 * sid])
        var right = Int(inp[3 * n + 2 * sid + 1])
        if kind == 0:
            outp[base] = 2
            outp[base + 1] = Int32(right)
            outp[base + 2] = Int32(left)
            outp[base + 3] = Int32(sid)
        else:
            var fn_id = kind - 1
            var lapp = -1
            var rapp = -1
            for t in range(n):
                if inp[3 * t] == 1 and Int(inp[3 * t + 1]) == fn_id:
                    if Int(inp[3 * t + 2]) == left:
                        lapp = t
                    if Int(inp[3 * t + 2]) == right:
                        rapp = t
            if lapp >= 0 and rapp >= 0:
                outp[base] = 3
                outp[base + 1] = Int32(lapp)
                outp[base + 2] = Int32(rapp)
                outp[base + 3] = Int32(sid)
                outp[base + 5] = Int32(fn_id)
    else:
        # This branch is unreachable at m=0, so division is well-defined.
        var offset = slot - unary_end
        var sid = offset // m
        var tid = offset % m
        if inp[3 * n + 2 * sid + 1] == inp[3 * n + 2 * tid]:
            outp[base] = 4
            outp[base + 1] = inp[3 * n + 2 * sid]
            outp[base + 2] = inp[3 * n + 2 * tid + 1]
            outp[base + 3] = Int32(sid)
            outp[base + 4] = Int32(tid)


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) < 6 or args[1] != "--gpu":
        raise Error("explicit --gpu required")
    var a = nat_arg(args[2])
    var f = nat_arg(args[3])
    var n = nat_arg(args[4])
    var m = nat_arg(args[5])
    if a < 1 or a > 128 or f > 16 or n < 1 or n > 128 or m > 64:
        raise Error("GPU frontier cap exceeded")
    if len(args) != 6 + 3 * n + 2 * m:
        raise Error("malformed CLI arity")
    var data = List[Int32]()
    for t in range(n):
        var k = nat_arg(args[6 + 3 * t])
        var sym = nat_arg(args[7 + 3 * t])
        var child = nat_arg(args[8 + 3 * t])
        if k == 0:
            if sym >= a or child != 0:
                raise Error("invalid atom index or padding")
        elif k == 1:
            if sym >= f or child >= t:
                raise Error("invalid or forward application")
        else:
            raise Error("invalid term kind")
        for j in range(t):
            if data[3 * j] == Int32(k) and data[3 * j + 1] == Int32(sym) and data[3 * j + 2] == Int32(child):
                raise Error("duplicate term")
        data.append(Int32(k))
        data.append(Int32(sym))
        data.append(Int32(child))
    for i in range(2 * m):
        var endpoint = nat_arg(args[6 + 3 * n + i])
        if endpoint >= n:
            raise Error("frontier endpoint outside term table")
        data.append(Int32(endpoint))
    if not has_accelerator():
        raise Error("GPU unavailable; no CPU fallback")
    var slots = m * (1 + f) + m * m
    # Maximum: 5,184 slots, 124,416 output bytes, 2,048 input bytes.
    # Allocate at least one element for an empty frontier; report actual bytes.
    var output_size = max(1, slots * 6)
    var start = perf_counter_ns()
    var ctx = DeviceContext()
    var in_dev = ctx.enqueue_create_buffer[DType.int32](len(data))
    var out_dev = ctx.enqueue_create_buffer[DType.int32](output_size)
    var in_host = ctx.enqueue_create_host_buffer[DType.int32](len(data))
    var out_host = ctx.enqueue_create_host_buffer[DType.int32](output_size)
    ctx.synchronize()
    var allocation_ns = perf_counter_ns() - start
    for i in range(len(data)):
        in_host[i] = data[i]
    start = perf_counter_ns()
    ctx.enqueue_copy(in_dev, in_host)
    ctx.synchronize()
    var h2d_ns = perf_counter_ns() - start
    start = perf_counter_ns()
    var compiled = ctx.compile_function[candidates_kernel, candidates_kernel]()
    var compile_ns = perf_counter_ns() - start
    start = perf_counter_ns()
    if slots > 0:
        ctx.enqueue_function(compiled, in_dev.unsafe_ptr(), out_dev.unsafe_ptr(),
                             n, m, f, slots, grid_dim=(slots + 127) // 128, block_dim=128)
        ctx.synchronize()
    var launch_sync_ns = perf_counter_ns() - start
    start = perf_counter_ns()
    if slots > 0:
        ctx.enqueue_copy(out_host, out_dev)
        ctx.synchronize()
    var d2h_ns = perf_counter_ns() - start
    print("LMGPU1", slots)
    print("DEVICE", ctx.name())
    print("METRICS", allocation_ns, h2d_ns, compile_ns, launch_sync_ns, d2h_ns,
          4 * (len(data) + output_size), 4 * len(data), 24 * slots, 1 if slots > 0 else 0)
    for slot in range(slots):
        var b = slot * 6
        print(out_host[b], out_host[b + 1], out_host[b + 2], out_host[b + 3], out_host[b + 4], out_host[b + 5])
