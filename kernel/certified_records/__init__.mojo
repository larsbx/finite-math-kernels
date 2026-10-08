# certified_records: canonical one-line records with a total decoder.
#
#   codec     Schema, Decoded; parse_canonical, decode, encode,
#             first_mismatch, vector_cases.
#
# A contract declares its tag and field widths as a Schema and inherits the
# refusal grammar `malformed:arity`, `malformed:<field>`, `mismatch:<field>`.
# finite_field_orbit (contract orbit-census-v1) is built on it. Python
# tooling calls this codec through python_binding (an extension module built
# by `pixi run build-certified-records-py`); codec.py only binds it.
