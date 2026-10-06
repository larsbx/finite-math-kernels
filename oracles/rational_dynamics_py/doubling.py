"""The doubling map ``t -> 2t`` on ``Q/Z``, exactly.

The type of an angle is read off its denominator, not searched for: for
``t = p/q`` in lowest terms write ``q = 2^l m`` with ``m`` odd; then

    preperiod(t) = l = v_2(q)        period(t) = ord_m(2)   (1 when m = 1)

the same closed forms as the Mojo ``angle_doubling`` package, with no cap on
the denominator and no cap on the order. The multiplicative order is computed
by direct powering for small orders and otherwise from the Carmichael function
of ``m`` by trial-division factorisation; either way it is exact, and the cost
of a huge ``m`` with a huge order is time, never a wrong answer.

``doubling_orbit`` is ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
kernel/bulbford/cycles.py (``_orbit``). The rotation part ported with it now
lives in the modules named after the objects it computes, and is re-exported
here unchanged so ``from rational_dynamics_py.doubling import ...`` keeps
working: ``mechanical_words`` (Morse-Hedlund mechanical words),
``rotation_sets`` (``rotation_cycle`` and ``rotation_number``, Goldberg's
rotation sets) and ``wakes`` (the characteristic arc, Douady-Hubbard wakes).

What is claimed: every function computes the stated combinatorial object of
the doubling map exactly. What is not: any dynamical statement about the
angles; the theorems the rotation part's consumers import are named in its
modules.
"""

from __future__ import annotations

from fractions import Fraction
from math import lcm

from .addresses import Address, as_fraction, require_int
from .mechanical_words import mechanical_word
from .rotation_sets import rotation_cycle, rotation_number
from .wakes import wake

__all__ = [
    "binary_block",
    "binary_digits",
    "binary_expansion",
    "doubling_orbit",
    "exact_type",
    "mechanical_word",
    "order_of_two",
    "period",
    "preperiod",
    "rotation_cycle",
    "rotation_number",
    "wake",
]

#: Below this many steps the order of two is found by direct powering.
_DIRECT_STEPS = 1 << 12


def _angle(value: Fraction | int | Address) -> Fraction:
    """The representative of ``value`` modulo one in ``[0, 1)``."""
    return as_fraction(value) % 1


def _two_adic_split(q: int) -> tuple[int, int]:
    """``(l, m)`` with ``q = 2^l m`` and ``m`` odd, for ``q >= 1``."""
    l = (q & -q).bit_length() - 1
    return l, q >> l


def _factor(n: int) -> dict[int, int]:
    """The prime factorisation of ``n >= 1`` by trial division."""
    out: dict[int, int] = {}
    d = 2
    while d * d <= n:
        while n % d == 0:
            out[d] = out.get(d, 0) + 1
            n //= d
        d += 1 if d == 2 else 2
    if n > 1:
        out[n] = out.get(n, 0) + 1
    return out


def _carmichael(factors: dict[int, int]) -> int:
    """``lambda(n)`` from the factorisation of an odd ``n``."""
    out = 1
    for p, k in factors.items():
        out = lcm(out, (p - 1) * p ** (k - 1))
    return out


def order_of_two(m: int) -> int:
    """``ord_m(2)``, the least ``k >= 1`` with ``2^k = 1 (mod m)``, for odd ``m >= 1``.

    ``m == 1`` gives ``1``. An even or non-positive ``m`` is refused: two is
    not a unit there.
    """
    require_int(m)
    if m < 1 or m % 2 == 0:
        raise ValueError("the order of two needs an odd positive modulus")
    if m == 1:
        return 1
    power = 2 % m
    for k in range(1, _DIRECT_STEPS + 1):
        if power == 1:
            return k
        power = power * 2 % m
    order = _carmichael(_factor(m))
    for prime in _factor(order):
        while order % prime == 0 and pow(2, order // prime, m) == 1:
            order //= prime
    return order


def preperiod(value: Fraction | int | Address) -> int:
    """``v_2`` of the reduced denominator of ``value mod 1``."""
    return _two_adic_split(_angle(value).denominator)[0]


def period(value: Fraction | int | Address) -> int:
    """The length of the cycle ``value mod 1`` falls into under doubling.

    ``ord_m(2)`` for ``m`` the odd part of the reduced denominator; ``1`` when
    ``m = 1``, because zero is fixed. This is the eventual period: an angle
    that is preperiodic (``preperiod > 0``) still has one. The math-vizops
    ``period_of`` returned ``None`` for an even denominator and for any period
    past its cap (``cap=32`` admits 33); here the first is
    ``preperiod(value) > 0`` and the second does not exist.
    """
    return order_of_two(_two_adic_split(_angle(value).denominator)[1])


def exact_type(value: Fraction | int | Address) -> tuple[int, int]:
    """``(preperiod, period)`` of ``value mod 1``."""
    return preperiod(value), period(value)


def binary_digits(value: Fraction | int | Address, n: int) -> str:
    """The first ``n`` binary digits of ``value mod 1`` after the point.

    For a dyadic rational the terminating expansion is used (``1/2 = 0.1000...``),
    which is the orbit of doubling: digit ``i`` is ``1`` exactly when
    ``2^i t mod 1 >= 1/2``.
    """
    require_int(n)
    if n < 0:
        raise ValueError("a digit count cannot be negative")
    t = _angle(value)
    out = []
    for _ in range(n):
        t *= 2
        out.append("1" if t >= 1 else "0")
        t %= 1
    return "".join(out)


def binary_expansion(value: Fraction | int | Address) -> tuple[str, str]:
    """``(prefix, block)`` with ``value mod 1 = 0.prefix (block)^infinity``.

    ``len(prefix) == preperiod(value)`` and ``len(block) == period(value)``, so
    both are minimal. ``0`` is ``("", "0")`` and ``1/2`` is ``("1", "0")``.
    """
    l, k = exact_type(value)
    digits = binary_digits(value, l + k)
    return digits[:l], digits[l:]


def binary_block(value: Fraction | int | Address) -> str:
    """The repeating block of ``binary_expansion(value)``.

    For a periodic angle ``j / (2^k - 1)`` it is ``j`` written in ``k`` bits.
    """
    return binary_expansion(value)[1]


def doubling_orbit(j: int, modulus: int) -> tuple[int, ...]:
    """The cycle of ``j mod M`` under ``j -> 2 j mod M``, starting at ``j mod M``.

    ``M`` must be odd and positive, which makes doubling a bijection of
    ``Z/MZ`` and every residue periodic; an even ``M`` is refused rather than
    looped on. With ``M = 2^q - 1`` these are the numerators of the angles
    ``j / (2^q - 1)`` of period dividing ``q``. Bulbs ``_orbit``.
    """
    require_int(j, modulus)
    if modulus < 1 or modulus % 2 == 0:
        raise ValueError("the modulus must be odd and positive")
    start = j % modulus
    orbit = [start]
    while (nxt := 2 * orbit[-1] % modulus) != start:
        orbit.append(nxt)
    return tuple(orbit)
