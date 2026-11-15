# fibonacci_hamiltonian: the trace polynomials of the Fibonacci substitution
# and certified band edges of their sublevel sets.
#
# Specification: docs/fibonacci-hamiltonian-band-edges-spec.md.
#
#   trace_polynomial  t_k in Q[E] by Suto's recurrence (Suto 1987), its scalar
#                     form, and the Fricke-Vogt invariant of three traces.
#   band_edges        brackets for every real root of t_k - 2 and t_k + 2,
#                     the bands of {E : |t_k(E)| <= 2} between them, two-sided
#                     enclosures of bands and gaps, and the cover by two
#                     consecutive levels.
#
# The package computes finite facts about polynomials with rational
# coefficients. That the brackets are every edge is Sturm's theorem; that the
# sublevel set is the spectrum of a periodic Schrodinger operator is Floquet
# theory; that two consecutive levels cover the spectrum of the Fibonacci
# Hamiltonian is Suto's theorem. None is proved here and no function is named
# as though it were: naming and gating those imports is the consumer's
# decision (specification section 6). A refusal is a rejected value.
#
# Vendored with `finite_linear_algebra` and `finite_exact`.

from .band_edges import (
    Approximant,
    Band,
    Edge,
    approximant,
    closed_gaps,
    cover,
    gap_bounds,
    inner_bands,
    outer_bands,
    rejected_approximant,
)
from .trace_polynomial import invariant, trace_polynomial, trace_polynomials, trace_value
