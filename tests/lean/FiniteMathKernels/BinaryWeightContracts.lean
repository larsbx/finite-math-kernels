import FiniteMathKernels.BinaryWeight

/-! Explicit public types, independently stated from the implementation proofs.
These wrappers retain every input and the natural-number arithmetic domain. -/

namespace FiniteMathKernels.BinaryWeightContracts

theorem zero : binaryWeight 0 = 0 := binaryWeight_zero

theorem one : binaryWeight 1 = 1 := binaryWeight_one

theorem lowZero (n : ℕ) : binaryWeight (2 * n) = binaryWeight n :=
  binaryWeight_two_mul n

theorem lowOne (n : ℕ) : binaryWeight (2 * n + 1) = binaryWeight n + 1 :=
  binaryWeight_two_mul_add_one n

theorem successor (n : ℕ) : binaryWeight (n + 1) ≤ binaryWeight n + 1 :=
  binaryWeight_succ_le n

theorem addition (m n : ℕ) :
    binaryWeight (m + n) ≤ binaryWeight m + binaryWeight n :=
  binaryWeight_add_le m n

theorem leftShift (k n : ℕ) : binaryWeight (2 ^ k * n) = binaryWeight n :=
  binaryWeight_two_pow_mul k n

theorem rightFactor (n k : ℕ) : binaryWeight (n * 2 ^ k) = binaryWeight n :=
  binaryWeight_mul_two_pow n k

theorem dropBit (n : ℕ) : binaryWeight (n / 2) ≤ binaryWeight n :=
  binaryWeight_div_two_le n

theorem dropBits (n k : ℕ) : binaryWeight (n / 2 ^ k) ≤ binaryWeight n :=
  binaryWeight_div_two_pow_le n k

theorem lowOnes (k : ℕ) : binaryWeight (2 ^ k - 1) = k :=
  binaryWeight_two_pow_sub_one k

theorem square (n : ℕ) :
    2 * binaryWeight (n ^ 2) ≤ binaryWeight n * (binaryWeight n + 1) :=
  binaryWeight_sq_le n

end FiniteMathKernels.BinaryWeightContracts
