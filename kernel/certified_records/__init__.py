"""Canonical one-line records. The codec is Mojo (`kernel/certified_records/codec.mojo`);
`codec.py` binds it for Python tooling."""

from certified_records.codec import Schema, decode, encode, first_mismatch, vector_cases

__all__ = ["Schema", "decode", "encode", "first_mismatch", "vector_cases"]
