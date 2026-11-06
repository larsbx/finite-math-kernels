"""Known native counterexample: this is not a successful exact-count test."""
from substitution_dynamics.words import n3


def main():
    var word = List[Int]()
    for _ in range(4000000):
        word.append(0)
    var counts = n3(word, 1)
    print(counts[0])
