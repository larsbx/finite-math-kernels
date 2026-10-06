"""The Carmichael function ``lambda(n)``: the exponent of the unit group ``(Z/nZ)^*``.

R. D. Carmichael, "Note on a new number theory function", Bull. Amer. Math. Soc.
16 (1910) 232-238. For an odd ``n = prod p^k`` it is the lcm of
``phi(p^k) = (p - 1) p^(k-1)``; the even case is not needed here and is
refused. Independent reference of the Mojo ``rational_dynamics.carmichael``.
"""

from __future__ import annotations

from math import lcm

from .addresses import require_int


def prime_factors(n: int) -> dict[int, int]:
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


def carmichael_lambda(n: int) -> int:
    """``lambda(n)`` for odd ``n >= 1`` (``lambda(1) = 1``); even or non-positive ``n`` is refused."""
    require_int(n)
    if n < 1 or n % 2 == 0:
        raise ValueError("the Carmichael function is taken here at odd positive n only")
    out = 1
    for p, k in prime_factors(n).items():
        out = lcm(out, (p - 1) * p ** (k - 1))
    return out
