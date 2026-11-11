module BigZLimbs {
  type Columns = { sum: List[int], difference: List[int], carry: int, borrow: int }

  pure val zero: Columns = { sum: List(), difference: List(), carry: 0, borrow: 0 }

  pure def step(base: int, a: int, b: int, s: Columns): Columns = {
    val total = a + b + s.carry
    val delta = a - b - s.borrow
    {
      sum: s.sum.append(total % base),
      difference: s.difference.append(if (delta < 0) delta + base else delta),
      carry: total / base,
      borrow: if (delta < 0) 1 else 0,
    }
  }

  pure def magnitude(base: int, digits: List[int]): int =
    digits.foldl({ value: 0, place: 1 }, (acc, d) =>
      { value: acc.value + acc.place * d, place: acc.place * base }).value

  pure def trim(digits: List[int]): List[int] =
    digits.foldl({ seen: List(), significant: List() }, (acc, d) => {
      val seen = acc.seen.append(d)
      { seen: seen, significant: if (d == 0) acc.significant else seen }
    }).significant

  pure def bounded(base: int, digits: List[int]): bool =
    digits.indices().forall(i => 0 <= digits[i] and digits[i] < base)

  pure def canonical(base: int, digits: List[int]): bool =
    bounded(base, digits) and (if (digits.length() == 0) true else digits[digits.length() - 1] != 0)

  pure def prefixInvariant(base: int, width: int, x: int, y: int, s: Columns): bool = {
    val place = range(0, width).foldl(1, (p, _) => p * base)
    val a = x % place
    val b = y % place
    and {
      s.sum.length() == width,
      s.difference.length() == width,
      bounded(base, s.sum),
      bounded(base, s.difference),
      Set(0, 1).contains(s.carry),
      Set(0, 1).contains(s.borrow),
      magnitude(base, s.sum) + place * s.carry == a + b,
      magnitude(base, s.difference) - place * s.borrow == a - b,
    }
  }

  pure def threeDigits(base: int, value: int): List[int] =
    List(value % base, (value / base) % base, value / (base * base))

  pure def checkPair(base: int, x: int, y: int): bool = {
    val a = threeDigits(base, x)
    val b = threeDigits(base, y)
    val trace = range(0, 3).foldl(List(zero), (states, i) =>
      states.append(step(base, a[i], b[i], states[i])))
    val final = trace[3]
    val sum = trim(final.sum.append(final.carry))
    val trimmedDifference = trim(final.difference)
    and {
      trace.indices().forall(i => prefixInvariant(base, i, x, y, trace[i])),
      canonical(base, sum),
      magnitude(base, sum) == x + y,
      (final.borrow == 0) == (x >= y),
      (final.borrow != 0) or (canonical(base, trimmedDifference) and magnitude(base, trimmedDifference) == x - y),
    }
  }

  pure def allPairs(base: int): bool = {
    val inputs = 0.to(base * base * base - 1)
    inputs.forall(x => inputs.forall(y => checkPair(base, x, y)))
  }

  run baseTwoTest = assert(allPairs(2))
  run baseThreeTest = assert(allPairs(3))
  run baseFourTest = assert(allPairs(4))

  run lostCarryTest = {
    val good = step(4, 3, 1, zero)
    val lost = { ...good, carry: 0 }
    assert(prefixInvariant(4, 1, 3, 1, good) and not(prefixInvariant(4, 1, 3, 1, lost)))
  }

  run lostBorrowTest = {
    val good = step(4, 0, 1, zero)
    val lost = { ...good, borrow: 0 }
    assert(prefixInvariant(4, 1, 0, 1, good) and not(prefixInvariant(4, 1, 0, 1, lost)))
  }

  run normalizationTest = assert(and {
    trim(List(0, 0, 0)) == List(),
    trim(List(1, 0, 2, 0)) == List(1, 0, 2),
    not(canonical(4, List(1, 0, 2, 0))),
  })
}
