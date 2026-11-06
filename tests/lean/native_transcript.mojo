"""Finite native outputs for independent Lean checking; no expected values here."""
from finite_exact.checked_int import checked_abs, checked_add, checked_mul, checked_neg, checked_sub
from finite_exact.fp import Fp
from substitution_dynamics.words import parikh, n2, n3
from substitution_dynamics.substitution import Substitution
from substitution_dynamics.balanced_pairs import coincidence_boundaries


def ints(xs: List[Int]) -> String:
    var out = String("[")
    for i in range(len(xs)):
        if i != 0:
            out += ","
        out += String(xs[i])
    return out + "]"


def word_case(w: List[Int], size: Int):
    print('{"kind":"word","size":' + String(size) + ',"input":' + ints(w)
          + ',"parikh":' + ints(parikh(w, size)) + ',"pairs":' + ints(n2(w, size))
          + ',"triples":' + ints(n3(w, size)) + '}')


def substitution_case(images: List[List[Int]], w: List[Int], n: Int) raises:
    var sigma = Substitution.checked(images)
    var source = String("[")
    for i in range(len(images)):
        if i != 0:
            source += ","
        source += ints(images[i])
    source += "]"
    print('{"kind":"substitution","images":' + source + ',"input":' + ints(w)
          + ',"n":' + String(n) + ',"output":' + ints(sigma.apply_n(w, n))
          + ',"incidence":' + ints(sigma.incidence())
          + ',"prefix_lengths":' + ints(sigma.image_prefix_lengths(w)) + '}')


def integer_case(op: Int, a: Int, b: Int):
    var value = String("null")
    try:
        var result = 0
        if op == 0:
            result = checked_add(a, b)
        elif op == 1:
            result = checked_sub(a, b)
        elif op == 2:
            result = checked_mul(a, b)
        elif op == 3:
            result = checked_neg(a)
        else:
            result = checked_abs(a)
        value = String(result)
    except:
        pass
    print('{"kind":"integer","op":' + String(op) + ',"a":' + String(a)
          + ',"b":' + String(b) + ',"output":' + value + '}')


def field_case[p: Int64](a: Int64, b: Int64, op: Int, reject: Bool):
    var x = Fp[p](a)
    var y = Fp[p](b)
    if reject:
        y = Fp[p].rejected_value()
    var result = x + y
    if op == 1:
        result = x * y
    elif op == 2:
        result = x / y
    var value = String("null")
    if result.accepted():
        value = String(result.v)
    print('{"kind":"field","p":' + String(p) + ',"a":' + String(a)
          + ',"b":' + String(b) + ',"op":' + String(op)
          + ',"reject":' + ("true" if reject else "false") + ',"output":' + value
          + ',"refusal_eq":' + ("true" if Fp[p].rejected_value() == Fp[p].rejected_value() else "false") + '}')


def main() raises:
    for size in range(1, 5):
        var total = 1
        for length in range(4):
            for code in range(total):
                var word = List[Int]()
                var remainder = code
                for _ in range(length):
                    word.append(remainder % size)
                    remainder //= size
                word_case(word, size)
            total *= size
    word_case([0, 12, 0], 13)
    for n in range(5):
        var fib: List[List[Int]] = [[0, 1], [0]]
        substitution_case(fib, [0, 1, 0], n)
        var tri: List[List[Int]] = [[0, 1], [0, 2], [0]]
        substitution_case(tri, [0, 1, 2], n)
        var four: List[List[Int]] = [[0, 1], [0, 2], [0, 3], [0]]
        substitution_case(four, [3, 0, 1], n)
    var bounds: List[Int] = [0, 1, -1, Int.MIN, Int.MAX, 3037000499, 3037000500]
    for i in range(len(bounds)):
        for j in range(len(bounds)):
            for op in range(3):
                integer_case(op, bounds[i], bounds[j])
        integer_case(3, bounds[i], 0)
        integer_case(4, bounds[i], 0)
    for a in range(-1, 3):
        for b in range(-1, 3):
            for op in range(3):
                field_case[7](Int64(a), Int64(b), op, False)
    for op in range(3):
        field_case[7](Int64(0), Int64(1), op, True)
    var u: List[Int] = [0, 1, 1, 0]
    var v: List[Int] = [1, 0, 0, 1]
    print('{"kind":"cuts","size":2,"u":' + ints(u) + ',"v":' + ints(v)
          + ',"output":' + ints(coincidence_boundaries(u, v, 2)) + '}')
