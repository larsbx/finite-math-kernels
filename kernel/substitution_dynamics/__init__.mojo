# substitution_dynamics: finite words, substitutions, balanced pairs, the
# balanced-pair automaton, swap-walk discrepancy, tuning patterns, directive
# prefixes, and column coincidence over an explicit alphabet.
#
# Extracted from the PSC research kernel (psc/words.mojo, psc/bpa.mojo,
# psc/swap_discrepancy.mojo). The package knows nothing about the Pisot
# conjecture: no G1, C3, C4, producer, or renewal vocabulary, no fixed
# alphabet, and no theorem claims. Every symbol is validated once at the
# boundary (`Substitution.checked`, `checked_pair`, `validate_word`); the
# kernels below that boundary trust their inputs. A capped automaton build is
# inconclusive, never evidence. See README.md at the repository root.
