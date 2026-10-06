# substitution_dynamics: finite words, substitutions, balanced pairs, the
# balanced-pair automaton, swap-walk discrepancy, tuning patterns, directive
# prefixes, column coincidence, relabelling/reversal normal forms and
# endpoint-map classes over an explicit alphabet.
#
# Named literature objects have their own modules:
#   balanced_pair_algorithm  the balanced pair algorithm (Livshits 1987;
#                            Sirvent & Solomyak 2002) under state-count and
#                            state-length budgets; `automaton` is the
#                            state-capped construction of the same graph
#   barge_class              Barge's class (Barge 2016; Barge & Kwapisz 2006)
#   dumont_thomas            Dumont-Thomas numeration (Dumont & Thomas 1989)
#   strong_coincidence       the strong coincidence condition (Arnoux & Ito
#                            2001) as an automaton over Dumont-Thomas paths
#   return_lattice           return words and their Parikh lattices
#                            (Durand 1998)
#   tuning                   tuning patterns and the star product
#                            (Derrida, Gervois & Pomeau 1978)
#   internal_address         the internal address of a kneading sequence
#                            (Lau & Schleicher 1994)
# Generic helpers stay in generic modules (`symmetry`, `endpoint_maps`).
#
# Extracted from the PSC research kernel (psc/words.mojo, psc/bpa.mojo,
# psc/swap_discrepancy.mojo, psc/symmetry.mojo, psc/endpoint_core.mojo,
# psc/barge_class.mojo, psc/bounded_bpa.mojo, psc/dumont_thomas.mojo,
# psc/return_lattice.mojo and the generic core of psc/coincidence_*.mojo).
# The package knows nothing about the Pisot conjecture: no G1, C3, C4,
# producer, or renewal vocabulary, no fixed alphabet, no number field, and no
# theorem claims. Every symbol is validated once at the boundary
# (`Substitution.checked`, `checked_pair`, `validate_word`); the kernels below
# that boundary trust their inputs. A capped automaton build is inconclusive,
# never evidence. `dumont_thomas` and `strong_coincidence` build on
# `finite_automata` (and through it `finite_exact`); `return_lattice` uses
# `finite_exact.checked_int`. This facade is an index, not a re-export:
# importing it pulls in no module, so a consumer vendoring a subset of the
# package never compiles a dependency it did not vendor.
# See README.md at the repository root.
