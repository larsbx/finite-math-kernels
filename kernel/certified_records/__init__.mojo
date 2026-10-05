# certified_records: canonical one-line records with a total decoder.
#
#   codec     Schema, Decoded; parse_canonical, decode, encode,
#             first_mismatch, vector_cases.
#
# A contract declares its tag and field widths as a Schema and inherits the
# refusal grammar `malformed:arity`, `malformed:<field>`, `mismatch:<field>`.
# finite_field_orbit (contract orbit-census-v1) is built on it. The Python
# half, codec.py, reads the same vectors: conformance/certified_records_v1.txt.
