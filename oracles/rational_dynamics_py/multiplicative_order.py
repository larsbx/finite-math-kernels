"""The multiplicative order of two modulo an odd ``m``: ``ord_m(2)``, exactly and uncapped.

C. F. Gauss, *Disquisitiones Arithmeticae* (1801), articles 45-52; standard
reference: Ireland and Rosen, *A Classical Introduction to Modern Number
Theory*, 2nd ed. (1990), chapter 4. The order is found by direct powering for
small orders and otherwise from the Carmichael function (``carmichael``) by
trial-division factorisation; either way it is exact, and the cost of a huge
``m`` with a huge order is time, never a wrong answer. Independent reference
of the Mojo ``rational_dynamics.multiplicative_order``.
"""

from __future__ import annotations

from .carmichael import carmichael_lambda, prime_factors
from .farey import require_int

#: Below this many steps the order of two is found by direct powering.
_DIRECT_STEPS = 1 << 12


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
    order = carmichael_lambda(m)
    for prime in prime_factors(order):
        while order % prime == 0 and pow(2, order // prime, m) == 1:
            order //= prime
    return order
