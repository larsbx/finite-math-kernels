"""Native observations only; no binomial formula or expected count here."""
from finite_exact.checked_int import checked_add
from substitution_dynamics.words import n2, n3, parikh, k3, Pair


def constant_case(length: Int, letter: Int, size: Int) raises:
    var word = List[Int]()
    for _ in range(length):
        word.append(letter)
    var value = String("null")
    var error = String("")
    try:
        var counts = n3(word, size)
        var slot = (size * letter + letter) * size + letter
        value = String(counts[slot])
        for i in range(len(counts)):
            if i != slot and counts[i] != 0:
                raise Error("unexpected nonconstant triple slot")
    except e:
        error = String(e)
    var pairs = n2(word, size)
    var letters = parikh(word, size)
    print('{"kind":"constant","length":' + String(length)
          + ',"letter":' + String(letter) + ',"size":' + String(size)
          + ',"value":' + value + ',"error":"' + error
          + '","n2":' + String(pairs[size * letter + letter])
          + ',"parikh":' + String(letters[letter]) + '}')


def addition_case(a: Int, b: Int):
    var value = String("null")
    var error = String("")
    try:
        value = String(checked_add(a, b))
    except e:
        error = String(e)
    print('{"kind":"addition","a":' + String(a) + ',"b":' + String(b)
          + ',"value":' + value + ',"error":"' + error + '"}')


def k3_case(length: Int, mode: Int) raises:
    var word = List[Int]()
    for _ in range(length):
        word.append(0)
    var small: List[Int] = [0, 0, 0]
    var p = Pair(word, word) if mode == 2 else (Pair(small, word) if mode == 1 else Pair(word, small))
    var value = String("null")
    var error = String("")
    try:
        var counts = k3(p, 1)
        value = String(counts[0])
    except e:
        error = String(e)
    print('{"kind":"k3","length":' + String(length)
          + ',"mode":' + String(mode) + ',"value":' + value
          + ',"error":"' + error + '"}')


def dimension_case(order: Int):
    var value = String("null")
    var error = String("")
    try:
        var word = List[Int]()
        var counts = n2(word, Int.MAX) if order == 2 else n3(word, 3000000)
        value = String(len(counts))
    except e:
        error = String(e)
    print('{"kind":"dimension","order":' + String(order) + ',"value":'
          + value + ',"error":"' + error + '"}')


def main() raises:
    constant_case(0, 0, 1)
    constant_case(1, 0, 1)
    constant_case(2, 0, 1)
    constant_case(3810778, 0, 1)
    constant_case(3810779, 0, 1)
    constant_case(3810780, 0, 1)
    constant_case(4000000, 0, 1)
    constant_case(3810779, 1, 2)
    constant_case(3810780, 1, 2)
    addition_case(Int.MAX - 2, 1)
    addition_case(Int.MAX - 1, 1)
    addition_case(Int.MAX, 1)
    k3_case(3810779, 0)
    k3_case(3810779, 1)
    k3_case(3810780, 0)
    k3_case(3810780, 1)
    k3_case(3810780, 2)
    dimension_case(2)
    dimension_case(3)
