"""Finite proof records: classification, canonical serialization, closure.

Specification: docs/specification.md. This is the canonical implementation;
the Python reference model in `finite_proof_records/records.py` is the
independent oracle, and `fixtures/vectors.json` is the replay set both must
agree on (`tests/replay_vectors.mojo`, driven by `tools/replay_mojo.py`).

The package states no theorem. It classifies records, validates their finite
evidence, encodes them canonically, and decides whether a dependency closure
is complete, naming every missing link otherwise. Repository policy enters
only as a `TagPolicy` supplied by the caller; the package ships none.
"""

comptime KIND_VERIFIED = "verified_finite_computation"
comptime KIND_IMPORTED = "imported_theorem"
comptime KIND_PENDING = "pending_dependency"
comptime KIND_BOUNDED = "bounded_experiment"
comptime KIND_REJECTED = "rejected"
comptime TRUE = "true"


struct Pair(Copyable, Movable):
    """One evidence entry `(key, value)`."""

    var key: String
    var value: String

    def __init__(out self, key: String, value: String):
        self.key = key
        self.value = value


struct Record(Copyable, Movable):
    var id: String
    var kind: String
    var statement: String
    var depends_on: List[String]
    var evidence: List[Pair]
    var tags: List[String]

    def __init__(
        out self,
        id: String,
        kind: String,
        statement: String,
        depends_on: List[String],
        evidence: List[Pair],
        tags: List[String],
    ):
        self.id = id
        self.kind = kind
        self.statement = statement
        self.depends_on = depends_on.copy()
        self.evidence = evidence.copy()
        self.tags = tags.copy()

    def field(self, key: String) -> String:
        """The evidence value under `key`, or the empty string when absent
        (an empty value counts as absent, as in the reference model)."""
        for i in range(len(self.evidence)):
            if self.evidence[i].key == key:
                return self.evidence[i].value
        return String("")


struct MissingLink(Copyable, Movable):
    var record_id: String
    var reason: String

    def __init__(out self, record_id: String, reason: String):
        self.record_id = record_id
        self.reason = reason


struct Closure(Copyable, Movable):
    var root: String
    var complete: Bool
    var reached: List[String]
    var missing_links: List[MissingLink]

    def __init__(out self, root: String, complete: Bool, reached: List[String], missing_links: List[MissingLink]):
        self.root = root
        self.complete = complete
        self.reached = reached.copy()
        self.missing_links = missing_links.copy()


struct Ledger(Copyable, Movable):
    """Records addressed by ledger key. The key is normally the record id;
    the closure reports a mismatch as a missing link."""

    var keys: List[String]
    var records: List[Record]

    def __init__(out self):
        self.keys = List[String]()
        self.records = List[Record]()

    def add(mut self, key: String, record: Record):
        self.keys.append(key)
        self.records.append(record.copy())

    def index_of(self, key: String) -> Int:
        for i in range(len(self.keys)):
            if self.keys[i] == key:
                return i
        return -1


struct TagPolicy(Copyable, Movable):
    """Refuses any record carrying a forbidden tag, with the consumer's
    reason. An empty policy accepts everything (`no_policy`)."""

    var tags: List[String]
    var reasons: List[String]

    def __init__(out self):
        self.tags = List[String]()
        self.reasons = List[String]()

    def forbid(mut self, tag: String, reason: String):
        self.tags.append(tag)
        self.reasons.append(reason)

    def verdict(self, record: Record) -> String:
        """Rejection reason, or the empty string when the record is accepted."""
        var hits = List[String]()
        for i in range(len(record.tags)):
            for j in range(len(self.tags)):
                if record.tags[i] == self.tags[j]:
                    hits.append(record.tags[i] + ": " + self.reasons[j])
        sort(hits)
        return String("; ").join(hits)


def no_policy() -> TagPolicy:
    return TagPolicy()


def kind_known(kind: String) -> Bool:
    return kind == KIND_VERIFIED or kind == KIND_IMPORTED or kind == KIND_PENDING or kind == KIND_BOUNDED or kind == KIND_REJECTED


def required_evidence(kind: String) -> List[String]:
    var out = List[String]()
    if kind == KIND_VERIFIED:
        out.append("digest")
        out.append("replay")
    elif kind == KIND_IMPORTED:
        out.append("hypotheses_checked")
        out.append("source")
    elif kind == KIND_PENDING or kind == KIND_REJECTED:
        out.append("reason")
    elif kind == KIND_BOUNDED:
        out.append("domain")
    return out^


def rejected(record: Record, reason: String) -> Record:
    var evidence = List[Pair]()
    evidence.append(Pair("reason", reason))
    return Record(record.id, KIND_REJECTED, record.statement, record.depends_on, evidence, record.tags)


def _contains(xs: List[String], x: String) -> Bool:
    for i in range(len(xs)):
        if xs[i] == x:
            return True
    return False


def _has_duplicate(xs: List[String]) -> Bool:
    for i in range(len(xs)):
        for j in range(i + 1, len(xs)):
            if xs[i] == xs[j]:
                return True
    return False


def validate(record: Record) -> Record:
    """The record unchanged if well-formed, else its REJECTED form.

    Fail closed, in the order of docs/specification.md section 3: unknown
    kind; rejected without reason; empty identifier or statement; duplicate
    evidence key; missing required evidence; duplicate or self dependency;
    imported theorem whose hypotheses are not marked checked.
    """
    if not kind_known(record.kind):
        return rejected(record, "unknown record kind")
    if record.kind == KIND_REJECTED:
        if record.field("reason").byte_length() > 0:
            return record.copy()
        return rejected(record, "rejected without reason")
    if record.id.byte_length() == 0 or record.statement.byte_length() == 0:
        return rejected(record, "empty identifier or statement")
    var keys = List[String]()
    for i in range(len(record.evidence)):
        keys.append(record.evidence[i].key)
    if _has_duplicate(keys):
        return rejected(record, "duplicate evidence key")
    var missing = List[String]()
    var required = required_evidence(record.kind)
    for i in range(len(required)):
        if not _contains(keys, required[i]):
            missing.append(required[i])
    if len(missing) > 0:
        return rejected(record, "missing evidence: " + String(", ").join(missing))
    if _has_duplicate(record.depends_on) or _contains(record.depends_on, record.id):
        return rejected(record, "duplicate or self dependency")
    if record.kind == KIND_IMPORTED and record.field("hypotheses_checked") != TRUE:
        return rejected(record, "imported theorem with unchecked hypotheses")
    return record.copy()


def _count(n: Int, mut out: List[UInt8]):
    for i in range(8):
        out.append(UInt8((n >> (8 * (7 - i))) & 255))


def _chunk(text: String, mut out: List[UInt8]):
    var bytes = text.as_bytes()
    _count(len(bytes), out)
    for i in range(len(bytes)):
        out.append(bytes[i])


def canonical_bytes(record: Record) -> List[UInt8]:
    """Deterministic encoding of docs/specification.md section 4: fixed field
    order, length-prefixed UTF-8, evidence sorted by key, tags sorted,
    dependency order significant."""
    var out = List[UInt8]()
    _chunk("finite_proof_record", out)
    _chunk("1", out)
    _chunk(record.id, out)
    _chunk(record.kind, out)
    _chunk(record.statement, out)
    _count(len(record.depends_on), out)
    for i in range(len(record.depends_on)):
        _chunk(record.depends_on[i], out)
    var keys = List[String]()
    for i in range(len(record.evidence)):
        keys.append(record.evidence[i].key)
    sort(keys)
    _count(len(keys), out)
    for i in range(len(keys)):
        _chunk(keys[i], out)
        _chunk(record.field(keys[i]), out)
    var tags = record.tags.copy()
    sort(tags)
    _count(len(tags), out)
    for i in range(len(tags)):
        _chunk(tags[i], out)
    return out^


struct _Walk(Copyable, Movable):
    var reached: List[String]
    var links: List[MissingLink]
    var stack: List[String]

    def __init__(out self):
        self.reached = List[String]()
        self.links = List[MissingLink]()
        self.stack = List[String]()

    def visit(mut self, ledger: Ledger, policy: TagPolicy, record_id: String):
        if _contains(self.stack, record_id):
            self.links.append(MissingLink(record_id, "dependency cycle"))
            return
        if _contains(self.reached, record_id):
            return
        self.reached.append(record_id)
        var index = ledger.index_of(record_id)
        if index < 0:
            self.links.append(MissingLink(record_id, "unknown record"))
            return
        var record = validate(ledger.records[index])
        if record.id != record_id:
            self.links.append(MissingLink(record_id, "ledger key differs from record identifier"))
            return
        if record.kind == KIND_REJECTED:
            self.links.append(MissingLink(record_id, "rejected: " + record.field("reason")))
            return
        if record.kind == KIND_PENDING:
            self.links.append(MissingLink(record_id, "pending: " + record.field("reason")))
        elif record.kind == KIND_BOUNDED:
            self.links.append(MissingLink(record_id, "bounded experiment is evidence, not a theorem"))
        var verdict = policy.verdict(record)
        if verdict.byte_length() > 0:
            self.links.append(MissingLink(record_id, "policy: " + verdict))
        self.stack.append(record_id)
        for i in range(len(record.depends_on)):
            self.visit(ledger, policy, record.depends_on[i])
        _ = self.stack.pop()


def close(ledger: Ledger, root: String, policy: TagPolicy) -> Closure:
    """Dependency closure of `root` (docs/specification.md section 5):
    complete iff every reached record is a validated verified computation or
    imported theorem accepted by `policy` and the graph below is acyclic."""
    var walk = _Walk()
    walk.visit(ledger, policy, root)
    var reached = walk.reached.copy()
    sort(reached)
    return Closure(root, len(walk.links) == 0, reached, walk.links)
