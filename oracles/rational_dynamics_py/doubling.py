"""The doubling map ``t -> 2t`` on ``Q/Z``, exactly.

The type of an angle is read off its denominator, not searched for: for
``t = p/q`` in lowest terms write ``q = 2^l m`` with ``m`` odd; then

    preperiod(t) = l = v_2(q)        period(t) = ord_m(2)   (1 when m = 1)

the same closed forms as the Mojo ``angle_doubling`` package, with no cap on
the denominator and no cap on the order. The multiplicative order is computed
by direct powering for small orders and otherwise from the Carmichael function
of ``m`` by trial-division factorisation; either way it is exact, and the cost
of a huge ``m`` with a huge order is time, never a wrong answer.

The rotation part is ported from larsbx/mandelbrot-bulbs-and-ford-circles-research
kernel/bulbford/wake.py (``rotation_cycle``, ``mechanical``, ``wake``) and
kernel/bulbford/cycles.py (``rotation_number``, ``_orbit``). For
``0 < p/q < 1`` in lowest terms, doubling has a cycle
``x_0 < ... < x_{q-1}`` of angles over ``2^q - 1`` on which it acts as the
rotation ``x_i -> x_{i+p mod q}``; its shortest arc ``(x_{p-1}, x_p)`` has
length ``1/(2^q - 1)`` and is the characteristic arc.

What is claimed: every function computes the stated combinatorial object of
the doubling map exactly. What is not: that the rotation cycle is unique
[Gol92] and that its characteristic arc is the angular width of the
``p/q``-wake [DH, Mil00] are imported theorems a consumer cites; this package
neither proves nor uses them.
"""

from __future__ import annotations

from collections.abc import Iterable
from fractions import Fraction
from math import gcd, lcm

from .farey import Address, as_fraction, require_int

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


def _reduced(p: int, q: int) -> None:
    if not (0 < p < q and gcd(p, q) == 1):
        raise ValueError("need 0 < p < q with gcd(p, q) = 1")


def mechanical_word(p: int, q: int, r: int) -> int:
    """The conjugate ``c(r)`` of the ``p/q`` rotation cycle, as a numerator over ``2^q - 1``.

    Bit ``k`` (most significant first, ``k < q``) is ``[(r + k p) mod q >= q - p]``,
    so the word is ``format(mechanical_word(p, q, r), f"0{q}b")``. ``c(0)`` is the
    word ``rotation_cycle`` starts from, doubling sends ``c(r)`` to ``c(r + p)``,
    and the sorted cycle is ``c(0) < c(1) < ... < c(q - 1)``. Bulbs ``mechanical``.
    """
    require_int(p, q, r)
    _reduced(p, q)
    return int("".join("1" if (r + k * p) % q >= q - p else "0" for k in range(q)), 2)


def rotation_cycle(p: int, q: int) -> tuple[Fraction, ...]:
    """The doubling cycle ``x_0 < ... < x_{q-1}`` of rotation number ``p/q``.

    Every ``x_i`` has denominator dividing ``2^q - 1`` and doubling maps ``x_i``
    to ``x_{i+p mod q}``. Refuses anything but ``0 < p < q`` coprime.
    """
    require_int(p, q)
    _reduced(p, q)
    big = 2**q - 1
    return tuple(Fraction(mechanical_word(p, q, r), big) for r in range(q))


def wake(p: int, q: int) -> tuple[Fraction, Fraction]:
    """``(theta_minus, theta_plus)``: the characteristic arc of the ``p/q`` rotation cycle.

    The consecutive cycle points bounding the shortest arc; that arc is
    ``(x_{p-1}, x_p)`` and has length ``1/(2^q - 1)``. Bulbs ``wake``; the
    Mandelbrot ``rotation_angles`` computes the same pair by enumerating every
    cycle (and returns ``(0, 0)`` at ``r = 0``, which is refused here).
    """
    require_int(p, q)
    cycle = rotation_cycle(p, q)
    return cycle[p - 1], cycle[p]


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


def rotation_number(angles: Iterable[int], modulus: int) -> Fraction | None:
    """``s/k`` if doubling shifts the ``k`` sorted angles cyclically by ``s`` places, else ``None``.

    ``angles`` are numerators over ``M``, taken modulo ``M``; they must be
    distinct and closed under doubling (a union of doubling cycles), and a set
    that is not is refused rather than read. ``None`` is the exact answer
    that doubling does not act on the set as a rotation. A single fixed point
    has rotation number ``0``. Bulbs ``rotation_number``, which raised
    ``KeyError`` on a set not closed under doubling.
    """
    angles = tuple(angles)
    require_int(*angles, modulus)
    if modulus < 1:
        raise ValueError("the modulus must be positive")
    ordered = sorted(a % modulus for a in angles)
    if not ordered:
        raise ValueError("an empty set of angles has no rotation number")
    if len(set(ordered)) != len(ordered):
        raise ValueError("angles must be distinct modulo M")
    k = len(ordered)
    position = {a: i for i, a in enumerate(ordered)}
    if any(2 * a % modulus not in position for a in ordered):
        raise ValueError("angles must be closed under doubling")
    shifts = {(position[2 * a % modulus] - i) % k for i, a in enumerate(ordered)}
    return Fraction(shifts.pop(), k) if len(shifts) == 1 else None
