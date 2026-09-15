"""A substitution on the alphabet `{0, ..., size-1}`, validated once.

`Substitution.checked(images)` is the typed boundary: it rejects a letter
outside the alphabet or an erasing image with an `Error`. The plain
constructor performs no validation and exists for callers that have already
validated (documented as such); the kernels index images without checks.
"""


def validate_word(w: List[Int], size: Int) raises:
    """Reject any letter of `w` outside `0 .. size-1`."""
    for i in range(len(w)):
        if w[i] < 0 or w[i] >= size:
            raise Error("letter " + String(w[i]) + " lies outside the alphabet 0.." + String(size - 1))


struct Substitution(Copyable, Movable):
    """Images `images[a]` of each letter `a`; `size == len(images)`."""

    var images: List[List[Int]]
    var size: Int

    def __init__(out self, var images: List[List[Int]], size: Int):
        # Trusted constructor: no validation. Prefer `Substitution.checked`.
        self.images = images^
        self.size = size

    @staticmethod
    def checked(images: List[List[Int]]) raises -> Substitution:
        """Validate and construct: non-empty alphabet, every image non-erasing,
        every letter inside the alphabet."""
        var size = len(images)
        if size == 0:
            raise Error("substitution needs a non-empty alphabet")
        for a in range(size):
            if len(images[a]) == 0:
                raise Error("substitution image of letter " + String(a) + " is erasing")
            validate_word(images[a], size)
        return Substitution(images.copy(), size)

    def image(self, a: Int) -> List[Int]:
        return self.images[a].copy()

    def apply(self, w: List[Int]) -> List[Int]:
        """`sigma(w)`, concatenating images left to right."""
        var out = List[Int]()
        for i in range(len(w)):
            ref img = self.images[w[i]]
            for j in range(len(img)):
                out.append(img[j])
        return out^

    def apply_n(self, w: List[Int], n: Int) -> List[Int]:
        """`sigma^n(w)`."""
        var out = w.copy()
        for _ in range(n):
            out = self.apply(out)
        return out^

    def image_prefix_lengths(self, w: List[Int]) -> List[Int]:
        """Image length of every prefix `w[:k]`, for `0 <= k <= |w|`."""
        var out: List[Int] = [0]
        for i in range(len(w)):
            out.append(out[len(out) - 1] + len(self.images[w[i]]))
        return out^

    def prefix_endpoint_map(self) -> List[Int]:
        """`sigma_+(a)`: first letter of `sigma(a)` (images are non-erasing)."""
        var out = List[Int]()
        for a in range(self.size):
            out.append(self.images[a][0])
        return out^

    def suffix_endpoint_map(self) -> List[Int]:
        """`sigma_-(a)`: last letter of `sigma(a)`."""
        var out = List[Int]()
        for a in range(self.size):
            out.append(self.images[a][len(self.images[a]) - 1])
        return out^

    def incidence(self) -> List[Int]:
        """`M[i][j]` = occurrences of letter `i` in `sigma(j)`, row-major, size x size."""
        var e = List[Int]()
        for i in range(self.size):
            for j in range(self.size):
                var c = 0
                ref img = self.images[j]
                for p in range(len(img)):
                    if img[p] == i:
                        c += 1
                e.append(c)
        return e^
