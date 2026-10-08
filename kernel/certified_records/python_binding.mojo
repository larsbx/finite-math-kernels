# python_binding.mojo
#
# The Python face of codec.mojo, built as an extension module
# (`pixi run build-certified-records-py` writes .build/certified_records_ext.so)
# and loaded by codec.py. Python holds no codec logic of its own: a schema
# crosses as (tag, names, bits) and values cross as decimal strings, because a
# 64-bit field does not fit a signed Int.

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder

from certified_records.codec import Schema, decode, encode, first_mismatch, parse_canonical, vector_cases


@export
def PyInit_certified_records_ext() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("certified_records_ext")
        m.def_function[py_decode]("decode", docstring="(reason, decimal values) of a line under (tag, names, bits)")
        m.def_function[py_encode]("encode", docstring="the line of decimal values under (tag, names, bits)")
        m.def_function[py_first_mismatch]("first_mismatch", docstring="mismatch:<field> from start on, or ''")
        m.def_function[py_vector_cases]("vector_cases", docstring="the columns after kind, for every row of that kind")
        return m.finalize()
    except e:
        abort(String("certified_records_ext: ", e))


def schema_of(wire: PythonObject) raises -> Schema:
    var names = List[String]()
    var bits = List[Int]()
    for name in wire[1]:
        names.append(String(name))
    for b in wire[2]:
        bits.append(Int(py=b))
    return Schema(String(wire[0]), names^, bits^)


def values_of(xs: PythonObject) raises -> List[UInt64]:
    var out = List[UInt64]()
    for x in xs:
        var v = parse_canonical(String(x), 64)
        if not v:
            raise Error("not an unsigned 64-bit decimal: " + String(x))
        out.append(v.value())
    return out^


def decimals(values: List[UInt64]) raises -> PythonObject:
    var out = Python.list()
    for v in values:
        _ = out.append(PythonObject(String(v)))
    return out


def py_decode(wire: PythonObject, line: PythonObject) raises -> PythonObject:
    var d = decode(schema_of(wire), String(line))
    return Python.tuple(PythonObject(d.reason), decimals(d.values))


def py_encode(wire: PythonObject, values: PythonObject) raises -> PythonObject:
    return PythonObject(encode(schema_of(wire), values_of(values)))


def py_first_mismatch(wire: PythonObject, claimed: PythonObject, actual: PythonObject, start: PythonObject) raises -> PythonObject:
    return PythonObject(first_mismatch(schema_of(wire), values_of(claimed), values_of(actual), Int(py=start)))


def py_vector_cases(text: PythonObject, kind: PythonObject) raises -> PythonObject:
    var out = Python.list()
    for row in vector_cases(String(text), String(kind)):
        var cols = Python.list()
        for col in row:
            _ = cols.append(PythonObject(col))
        _ = out.append(cols)
    return out
