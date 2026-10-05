"""Canonical one-line records with a total decoder. See `kernel/certified_records/codec.py`."""

from certified_records.codec import Schema, decode, encode, first_mismatch, parse_canonical, vector_cases

__all__ = ["Schema", "decode", "encode", "first_mismatch", "parse_canonical", "vector_cases"]
