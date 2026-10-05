# Minimal reproduction: "use of uninitialized value" on a fully initialised struct.
#
# Toolchain: Mojo 1.1.0.dev2026090805 (34562fa1), linux-64, pinned in pixi.toml.
# Expected:  compiles and prints True.
# Actual:    error: use of uninitialized value 's.x'
#
# Necessary, each removed in turn by evidence.py:
#   1. the field's type is a trait's associated type (S[K: Field], x: K.Element);
#   2. the field is compared with a named local (v), not a temporary;
#   3. the element is a struct with at least as many fields as S (an Int element,
#      or S with more fields than V, compiles). evidence.py tabulates the counts.

trait Field:
    comptime Element: Copyable & Deinitable


struct V(Copyable):
    var a: Int
    var b: Int

    def __init__(out self, a: Int):
        self.a = a
        self.b = 0

    def __eq__(self, other: Self) -> Bool:
        return self.a == other.a


struct VField(Field):
    comptime Element = V


struct S[K: Field](Copyable):
    var x: Self.K.Element

    def __init__(out self, x: Self.K.Element):
        self.x = x.copy()


def main():
    var v = V(0)
    var s = S[VField](V(0))
    print(s.x == v)
