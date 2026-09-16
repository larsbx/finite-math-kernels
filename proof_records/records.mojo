"""Finite proof records: classification, identity, canonical serialization, closure.

Specification: docs/proof-records-specification.md. This is the canonical
implementation; the Python reference model in `proof_records/records.py` is
the independent oracle, and `fixtures/vectors.json` is the replay set both
must agree on (`tests/proof_records/replay_vectors.mojo`, driven by
`tools/replay_mojo.py`).

The package states no theorem. It classifies records, validates their finite
evidence, verifies each identifier against the record's preimage, encodes
records canonically, and decides whether a dependency closure is complete,
naming every missing link otherwise. Each dependency is an identity-bearing
edge that names the claim, use site, scope relation, and validation outcome
it requires, and the closure checks the referenced record against all four.
Repository policy enters only as a `TagPolicy` supplied by the caller; the
package ships none.
"""

from proof_records.sha256 import hex, sha256

comptime KIND_VERIFIED = "verified_finite_computation"
comptime KIND_IMPORTED = "imported_theorem"
comptime KIND_PENDING = "pending_dependency"
comptime KIND_BOUNDED = "bounded_experiment"
comptime KIND_REJECTED = "rejected"
comptime TRUE = "true"
comptime FORMAT = "finite_proof_record"
comptime VERSION = "2"
comptime ID_SUITE = "sha256:"
comptime SAME_SCOPE = "same"
comptime SCOPE_LITERAL = "scope="
comptime ACCEPTED = "accepted"
comptime BOUNDED = "bounded"
comptime OPEN = "open"


struct Pair(Copyable, Movable):
    """One evidence entry `(key, value)`."""

    var key: String
    var value: String

    def __init__(out self, key: String, value: String):
        self.key = key
        self.value = value


struct Edge(Copyable, Movable):
    """An identity-bearing dependency: which record, what it must claim, where
    it is used, how its scope must relate to the user's, and which validation
    outcome the use requires (`accepted` or `bounded`)."""

    var record_id: String
    var expected_claim: String
    var use_site: String
    var scope_relation: String
    var required_outcome: String

    def __init__(out self, record_id: String, expected_claim: String, use_site: String, scope_relation: String, required_outcome: String):
        self.record_id = record_id
        self.expected_claim = expected_claim
        self.use_site = use_site
        self.scope_relation = scope_relation
        self.required_outcome = required_outcome

    def relation_known(self) -> Bool:
        return self.scope_relation == SAME_SCOPE or self.scope_relation.startswith(SCOPE_LITERAL)

    def required_scope(self, own_scope: String) -> String:
        """The scope the dependency must declare (caller checks `relation_known`)."""
        if self.scope_relation == SAME_SCOPE:
            return own_scope
        return String(self.scope_relation[byte=6:])


struct Record(Copyable, Movable):
    var id: String
    var kind: String
    var statement: String
    var scope: String
    var depends_on: List[Edge]
    var evidence: List[Pair]
    var tags: List[String]

    def __init__(
        out self,
        id: String,
        kind: String,
        statement: String,
        scope: String,
        depends_on: List[Edge],
        evidence: List[Pair],
        tags: List[String],
    ):
        self.id = id
        self.kind = kind
        self.statement = statement
        self.scope = scope
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
    return Record(record.id, KIND_REJECTED, record.statement, record.scope, record.depends_on, evidence, record.tags)


def outcome(record: Record) -> String:
    """The validation outcome of a validated record: `rejected`, `open`,
    `bounded`, or `accepted` (policy is reported separately)."""
    if record.kind == KIND_REJECTED:
        return String(KIND_REJECTED)
    if record.kind == KIND_PENDING:
        return String(OPEN)
    if record.kind == KIND_BOUNDED:
        return String(BOUNDED)
    return String(ACCEPTED)


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


def _edge_rejection(record: Record) -> String:
    """Rejection reason for malformed dependency edges, or the empty string."""
    var ids = List[String]()
    for i in range(len(record.depends_on)):
        ids.append(record.depends_on[i].record_id)
    if _has_duplicate(ids) or _contains(ids, record.id):
        return String("duplicate or self dependency")
    for i in range(len(record.depends_on)):
        ref e = record.depends_on[i]
        if not e.relation_known():
            return "unknown scope relation: " + e.scope_relation
        if e.required_outcome != ACCEPTED and e.required_outcome != BOUNDED:
            return "unknown required outcome: " + e.required_outcome
        if e.required_outcome == BOUNDED and e.scope_relation != SAME_SCOPE:
            return String("bounded dependency outside its own scope")
    return String("")


def validate(record: Record) -> Record:
    """The record unchanged if well-formed, else its REJECTED form.

    Fail closed, in the order of docs/proof-records-specification.md
    section 3: unknown kind; rejected without reason; empty statement or
    scope; duplicate evidence key; missing required evidence; malformed
    dependency edges; imported theorem whose hypotheses are not marked
    checked; an identifier that is not the digest of the record's preimage.
    """
    if not kind_known(record.kind):
        return rejected(record, "unknown record kind")
    if record.kind == KIND_REJECTED:
        if record.field("reason").byte_length() > 0:
            return record.copy()
        return rejected(record, "rejected without reason")
    if record.statement.byte_length() == 0 or record.scope.byte_length() == 0:
        return rejected(record, "empty statement or scope")
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
    var edge_reason = _edge_rejection(record)
    if edge_reason.byte_length() > 0:
        return rejected(record, edge_reason)
    if record.kind == KIND_IMPORTED and record.field("hypotheses_checked") != TRUE:
        return rejected(record, "imported theorem with unchecked hypotheses")
    if record.id != identity(record):
        return rejected(record, "identifier does not match preimage")
    return record.copy()


def _count(n: Int, mut out: List[UInt8]):
    for i in range(8):
        out.append(UInt8((n >> (8 * (7 - i))) & 255))


def _chunk(text: String, mut out: List[UInt8]):
    var bytes = text.as_bytes()
    _count(len(bytes), out)
    for i in range(len(bytes)):
        out.append(bytes[i])


def preimage_bytes(record: Record) -> List[UInt8]:
    """The record-ID preimage (docs/proof-records-specification.md section
    4): every identity-bearing field except the identifier itself. Fixed
    field order, length-prefixed UTF-8, dependency order significant,
    evidence sorted by key, tags sorted."""
    var out = List[UInt8]()
    _chunk(FORMAT, out)
    _chunk(VERSION, out)
    _chunk(record.kind, out)
    _chunk(record.statement, out)
    _chunk(record.scope, out)
    _count(len(record.depends_on), out)
    for i in range(len(record.depends_on)):
        ref e = record.depends_on[i]
        _chunk(e.record_id, out)
        _chunk(e.expected_claim, out)
        _chunk(e.use_site, out)
        _chunk(e.scope_relation, out)
        _chunk(e.required_outcome, out)
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


def identity(record: Record) -> String:
    """The identifier the record must carry: the SHA-256 suite over its preimage."""
    return ID_SUITE + hex(sha256(preimage_bytes(record)))


def canonical_bytes(record: Record) -> List[UInt8]:
    """The authoritative encoding: the preimage followed by the identifier."""
    var out = preimage_bytes(record)
    _chunk(record.id, out)
    return out^


struct _Walk(Copyable, Movable):
    var reached: List[String]
    var links: List[MissingLink]
    var stack: List[String]

    def __init__(out self):
        self.reached = List[String]()
        self.links = List[MissingLink]()
        self.stack = List[String]()

    def visit(mut self, ledger: Ledger, policy: TagPolicy, record_id: String, via: Edge, has_edge: Bool, own_scope: String):
        """Links about the record itself are reported on its first visit and
        its dependencies walked once; links about the edge that reached it
        (claim, scope, outcome) are reported for every incoming edge."""
        if _contains(self.stack, record_id):
            self.links.append(MissingLink(record_id, "dependency cycle"))
            return
        var first = not _contains(self.reached, record_id)
        if first:
            self.reached.append(record_id)
        var index = ledger.index_of(record_id)
        if index < 0:
            if first:
                self.links.append(MissingLink(record_id, "unknown record"))
            return
        var record = validate(ledger.records[index])
        if record.id != record_id:
            if first:
                self.links.append(MissingLink(record_id, "ledger key differs from record identifier"))
            return
        if record.kind == KIND_REJECTED:
            if first:
                self.links.append(MissingLink(record_id, "rejected: " + record.field("reason")))
            return
        var required = via.required_outcome if has_edge else String(ACCEPTED)
        if has_edge:
            if record.statement != via.expected_claim:
                self.links.append(MissingLink(record_id, "claim mismatch: " + via.use_site))
            if record.scope != via.required_scope(own_scope):
                self.links.append(MissingLink(record_id, "scope mismatch: " + via.use_site))
        var found = outcome(record)
        if found == OPEN:
            if first:
                self.links.append(MissingLink(record_id, "pending: " + record.field("reason")))
        elif found == BOUNDED and required != BOUNDED:
            self.links.append(MissingLink(record_id, "bounded experiment is evidence, not a theorem"))
        elif found == ACCEPTED and required != ACCEPTED:
            self.links.append(MissingLink(record_id, "outcome mismatch: " + via.use_site + " requires " + required + ", found " + found))
        if not first:
            return
        var verdict = policy.verdict(record)
        if verdict.byte_length() > 0:
            self.links.append(MissingLink(record_id, "policy: " + verdict))
        self.stack.append(record_id)
        for i in range(len(record.depends_on)):
            self.visit(ledger, policy, record.depends_on[i].record_id, record.depends_on[i], True, record.scope)
        _ = self.stack.pop()


def close(ledger: Ledger, root: String, policy: TagPolicy) -> Closure:
    """Dependency closure of `root` (docs/proof-records-specification.md
    section 5): complete iff every reached record is validated, matches the
    edge that reached it in claim, scope, and outcome, is accepted by
    `policy`, and the graph below is acyclic."""
    var walk = _Walk()
    walk.visit(ledger, policy, root, Edge("", "", "", SAME_SCOPE, ACCEPTED), False, "")
    var reached = walk.reached.copy()
    sort(reached)
    return Closure(root, len(walk.links) == 0, reached, walk.links)
