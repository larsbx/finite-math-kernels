"""Transcript of `rational_dynamics.doubling`, `.multiplicative_order`,
`.carmichael` and `.moebius` on a fixed
corpus, for the Python twin.

`tests/rational_dynamics/test_doubling_twin.py` runs this program and
recomputes every line with `oracles/rational_dynamics_py`. Each line prints its
inputs with its results, so a corpus that drifted between the two sides fails
as loudly as a value that disagrees. Integers print in base ten, digit lists
as 0/1 strings, and a refusal as `R`.
"""

from finite_exact.bigint_z import BigZ, bigz_from_i64, bigz_mul, bigz_sub
from finite_exact.exact_decimal import bigz_decimal
from rational_dynamics.doubling import (
    DigitsResult,
    binary_block,
    binary_digits,
    exact_type,
    exact_type_count,
)
from rational_dynamics.carmichael import carmichael_lambda
from rational_dynamics.moebius import moebius
from rational_dynamics.multiplicative_order import order_of_two
from rational_dynamics.rational import BigZResult, ReducedFraction, fraction_from_i64, reduce_fraction


def power(base: Int64, exponent: Int) -> BigZ:
    var out = bigz_from_i64(1)
    for _ in range(exponent):
        out = bigz_mul(out, bigz_from_i64(base))
    return out^


def big_token(result: BigZResult) -> String:
    return String("R") if result.rejected else bigz_decimal(result.value)


def digits_token(result: DigitsResult) -> String:
    if result.rejected:
        return String("R")
    var out = String("")
    for i in range(len(result.digits)):
        out += String(result.digits[i])
    return out^


def type_line(t: ReducedFraction):
    var found = exact_type(t)
    var kind = String("R R") if found.rejected else String(found.preperiod) + " " + bigz_decimal(found.period)
    print("T", bigz_decimal(t.num), bigz_decimal(t.den), kind, digits_token(binary_block(t)),
          digits_token(binary_digits(t, 12)))


def main():
    print("HEADER rational-dynamics-doubling-twin 1")
    for den in range(1, 65):
        for num in range(den):
            type_line(fraction_from_i64(Int64(num), Int64(den)))
    # Ordinary fractions are read modulo one; the large ones pass the old caps.
    var mersenne_127 = bigz_sub(power(2, 127), bigz_from_i64(1))
    type_line(fraction_from_i64(9, 7))
    type_line(fraction_from_i64(5, 128 * 10007))
    type_line(fraction_from_i64(1, 58))
    type_line(fraction_from_i64(1, 50))
    type_line(reduce_fraction(bigz_from_i64(3), mersenne_127))
    type_line(reduce_fraction(bigz_from_i64(7), bigz_mul(bigz_from_i64(4), power(3, 9))))

    var moduli = List[BigZ]()
    for m in range(-3, 200):
        moduli.append(bigz_from_i64(Int64(m)))
    for m in [4097, 8191, 10007, 24573, 59049, 65535, 1048575]:
        moduli.append(bigz_from_i64(Int64(m)))
    moduli.append(mersenne_127.copy())
    moduli.append(power(3, 50))
    for i in range(len(moduli)):
        print("O", bigz_decimal(moduli[i]), big_token(order_of_two(moduli[i])))
        # Trial division cannot factor the Mersenne prime 2^127 - 1 in time.
        if i < len(moduli) - 2:
            print("L", bigz_decimal(moduli[i]), big_token(carmichael_lambda(moduli[i])))

    for l in range(-1, 6):
        for k in range(0, 13):
            print("C", l, k, big_token(exact_type_count(l, k)))
    print("C", 0, 64, big_token(exact_type_count(0, 64)))

    for n in range(0, 121):
        var mu: String
        try:
            mu = String(moebius(n))
        except:
            mu = String("R")
        print("M", n, mu)
    print("END")
