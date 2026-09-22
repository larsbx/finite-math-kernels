"""Known-answer transcript for the Julia Oracle Lab BigInt boundary.

The values and byte layout are authoritative here because they are produced by
finite_exact.bigint_z.bigz_canonical_bytes. The Julia repository independently
recomputes the same vectors and may report agreement or disagreement only.
"""

from finite_exact.bigint_z import BigZCanonicalBytes, bigz_canonical_bytes, bigz_from_i64


def octets(encoded: BigZCanonicalBytes) -> String:
    if encoded.rejected:
        return String("rejected")
    var out = String("")
    for index in range(len(encoded.bytes)):
        if index > 0:
            out += "."
        out += String(Int(encoded.bytes[index]))
    return out^


def emit(label: String, value: Int64):
    print(label, octets(bigz_canonical_bytes(bigz_from_i64(value))))


def main():
    print("HEADER julia-oracle-bigint-known-answer 1 shared-finite-kernel")
    emit("zero", 0)
    emit("one", 1)
    emit("negative-billion-plus-one", -1000000001)
    print("END")
