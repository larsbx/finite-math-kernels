# Canonical encoding of integers and rationals

Status: byte-level contract of `bigz_canonical_bytes` and `q_canonical_bytes`. It fixes one encoding per value so that consumers can hash, compare, and replay exact data without parsing decimal text. It is the only channel trusted between the Mojo probe and the Python oracle (`tools/property_oracle.py`). Composite record schemas (certificates, boxes, ray addresses) are consumer matters; NLAP-JT keeps its own in `docs/canonical-serialization.md`.

## Integer

```text
Z(sign, byte_len, big_endian_magnitude)
```

One sign byte (`0` zero, `1` positive, `2` negative), then an unsigned 8-byte big-endian `byte_len`, then exactly that many magnitude bytes. Zero has an empty magnitude. A nonzero magnitude is the minimal big-endian magnitude with no leading zero byte.

Golden vectors (hexadecimal):

```text
0           -> 00 0000000000000000
1           -> 01 0000000000000001 01
-1000000001 -> 02 0000000000000004 3b9aca01
```

`bigz_is_canonical` decides whether a `BigZ` is in the form that encodes; a non-canonical value has no encoding and `bigz_canonical_bytes` reports it as rejected.

## Rational

```text
Q(num: Z, den: Z)
```

The concatenation of the numerator and denominator encodings. The denominator is strictly positive and the pair is gcd-normalized, so there is exactly one encoding for each rational. A rejected rational has no encoding.

## Properties

- Injective and total on accepted values: equal values have equal bytes, distinct values have distinct bytes.
- Independent of the limb representation: the encoding is the mathematical value, not the storage.
- Rejected values do not encode. A consumer that needs to serialize a failure serializes its own status record, never a placeholder integer.
