# codec.mojo
#
# Canonical one-line records: a tag and unsigned decimal fields of 32 or 64
# bits. Mojo half of kernel/certified_records/codec.py; both read the
# vectors in conformance/certified_records_v1.txt.
#
# A record line is the tag and one canonical decimal per field, single-space
# separated. A canonical decimal is ASCII digits with no sign and no leading
# zero, below 2^bits. `decode` is total: every line either decodes or is
# refused as `malformed:arity` (wrong tag or token count) or
# `malformed:<field>` (the first field that is not canonical). Two records are
# equal iff their fields are, so replay compares fields with `first_mismatch`
# and reports `mismatch:<field>`.


struct Schema(Copyable, Movable):
    var tag: String
    var names: List[String]
    var bits: List[Int]

    def __init__(out self, tag: String, var names: List[String], var bits: List[Int]):
        """Every width is 32 or 64; `parse_canonical` refuses any other."""
        self.tag = tag
        self.names = names^
        self.bits = bits^


struct Decoded(Movable):
    """The field values of a line, or the `malformed:<field>` reason it has none."""

    var reason: String
    var values: List[UInt64]

    def __init__(out self, reason: String, var values: List[UInt64]):
        self.reason = reason
        self.values = values^


def parse_canonical(token: String, bits: Int) -> Optional[UInt64]:
    """An unsigned decimal with no leading zero, below 2^bits for bits in {32, 64}."""
    var bytes = token.as_bytes()
    var n = len(bytes)
    if (bits != 32 and bits != 64) or n == 0 or n > 20 or (n > 1 and Int(bytes[0]) == ord("0")):
        return None
    var value: UInt64 = 0
    for i in range(n):
        var digit = Int(bytes[i]) - ord("0")
        if digit < 0 or digit > 9:
            return None
        if value > (UInt64.MAX - UInt64(digit)) // 10:
            return None  # 2^64 or more
        value = value * 10 + UInt64(digit)
    if bits == 32 and value >= UInt64(4294967296):
        return None
    return value


def decode(schema: Schema, line: String) -> Decoded:
    var tokens = List[String]()
    for part in line.split(" "):
        tokens.append(String(part))
    if len(tokens) != 1 + len(schema.names) or tokens[0] != schema.tag:
        return Decoded("malformed:arity", List[UInt64]())
    var values = List[UInt64]()
    for i in range(len(schema.names)):
        var value = parse_canonical(tokens[i + 1], schema.bits[i])
        if not value:
            return Decoded("malformed:" + schema.names[i], List[UInt64]())
        values.append(value.value())
    return Decoded("", values^)


def encode(schema: Schema, values: List[UInt64]) -> String:
    var out = schema.tag
    for v in values:
        out += " " + String(v)
    return out


def first_mismatch(schema: Schema, claimed: List[UInt64], actual: List[UInt64], start: Int = 0) -> String:
    """`mismatch:<field>` for the first field from `start` on where they differ, else ""."""
    for i in range(start, len(schema.names)):
        if claimed[i] != actual[i]:
            return "mismatch:" + schema.names[i]
    return ""


def vector_cases(text: String, kind: String) -> List[List[String]]:
    """The tab-separated columns after the kind, for every row of that kind; `#` lines are comments."""
    var out = List[List[String]]()
    for raw in text.split("\n"):
        var line = String(raw)
        if line.startswith("#"):
            continue
        var cols = List[String]()
        for part in line.split("\t"):
            cols.append(String(part))
        if cols[0] == kind:
            var rest = List[String]()
            for i in range(1, len(cols)):
                rest.append(cols[i])
            out.append(rest^)
    return out^
