# miller_rabin.mojo
#
# Deterministic Miller-Rabin primality below 2^31. An odd n > 7 is prime iff it
# is a strong probable prime to each of the bases 2, 3, 5, 7: the least strong
# pseudoprime to all four is 3215031751 > 2^31. Residues stay below 2^31, so
# every product is below 2^62 and exact in Int; an n at or past 2^31 raises
# rather than leaving the range the witness set and the products cover.
#
# Sources: G. L. Miller, "Riemann's hypothesis and tests for primality",
# J. Comput. System Sci. 13 (1976), 300-317; M. O. Rabin, "Probabilistic
# algorithm for testing primality", J. Number Theory 12 (1980), 128-138. The
# witness set: C. Pomerance, J. L. Selfridge and S. S. Wagstaff, Jr., "The
# pseudoprimes to 25 * 10^9", Math. Comp. 35 (1980), 1003-1026, and
# G. Jaeschke, "On strong pseudoprimes to several bases", Math. Comp. 61
# (1993), 915-926.

comptime MILLER_RABIN_BOUND = 2147483648  # 2^31


def _strong_probable_prime(n: Int, base: Int, d: Int, s: Int) -> Bool:
    """n - 1 = d 2^s with d odd; base^d = 1 or base^(d 2^r) = -1 for some r < s."""
    var x = 1
    var b = base % n
    var e = d
    while e > 0:
        if e % 2 == 1:
            x = x * b % n
        b = b * b % n
        e //= 2
    if x == 1 or x == n - 1:
        return True
    for _ in range(s - 1):
        x = x * x % n
        if x == n - 1:
            return True
    return False


def is_prime(n: Int) raises -> Bool:
    """Deterministic for every n < 2^31; n >= 2^31 raises."""
    if n >= MILLER_RABIN_BOUND:
        raise Error("Miller-Rabin witness set {2, 3, 5, 7} is certified only below 2^31")
    if n < 2:
        return False
    for base in [2, 3, 5, 7]:
        if n == base:
            return True
        if n % base == 0:
            return False
    var d = n - 1
    var s = 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for base in [2, 3, 5, 7]:
        if not _strong_probable_prime(n, base, d, s):
            return False
    return True
