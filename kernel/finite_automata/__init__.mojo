# finite_automata: total deterministic finite automata over an integer alphabet.
#
#   dfa       Dfa, with_sink, intersection, union, complement, emptiness with
#             a witness word, projection (subset construction), Moore
#             minimisation, language equality, widening and cylinders, and
#             BigZ counts of accepted words of a given length. Re-exports
#             the two named constructions below.
#   subset_construction  project: one track quantified away and determinised
#             (Rabin-Scott 1959).
#   moore_minimisation   minimised: Moore partition refinement (Moore 1956).
#
# The package decides finite facts about finite automata. Which theorem lets a
# consumer read an automaton as a statement about a numeration or a sequence
# is the consumer's import to name and gate.
