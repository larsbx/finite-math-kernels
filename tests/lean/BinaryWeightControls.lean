import FiniteMathKernels.BinaryWeightContracts

/-! Closed controls for arithmetic meaning and sharper false variants.
These finite examples are separate from the universally quantified proofs. -/

namespace FiniteMathKernels.BinaryWeightControls

theorem weightZero : binaryWeight 0 = 0 := by decide
theorem weightEight : binaryWeight 8 = 1 := by decide
theorem weightFifteen : binaryWeight 15 = 4 := by decide
theorem carryRemovesOne : binaryWeight (1 + 1) = 1 := by decide
theorem additionNotEquality :
    binaryWeight (1 + 1) ≠ binaryWeight 1 + binaryWeight 1 := by decide
theorem divisionCanLoseBits : binaryWeight (7 / 2 ^ 2) = 1 := by decide
theorem divisionNotEquality :
    binaryWeight (7 / 2 ^ 2) ≠ binaryWeight 7 := by decide
theorem squareHasMoreBits : binaryWeight (5 ^ 2) = 3 := by decide
theorem squareBoundAttained :
    2 * binaryWeight (5 ^ 2) = binaryWeight 5 * (binaryWeight 5 + 1) := by decide
theorem strongerSquareBoundFalse :
    ¬ 2 * binaryWeight (5 ^ 2) ≤ binaryWeight 5 ^ 2 := by decide
theorem shiftedZero (k : ℕ) : binaryWeight (2 ^ k * 0) = 0 := by simp
theorem allOnesAtZero : binaryWeight (2 ^ 0 - 1) = 0 := by decide

end FiniteMathKernels.BinaryWeightControls
