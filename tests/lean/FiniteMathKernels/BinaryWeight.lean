import Mathlib.Data.Nat.Digits.Lemmas

/-!
# Binary digit weight

The binary weight of a natural number is the sum of its base-two digits.
These are arithmetic statements about unbounded natural numbers; they do not
assert implementation refinement for a native integer representation.

The addition and shift estimates are classical binary carry bounds (see
Bailey, Borwein, Crandall and Pomerance, *On the binary expansions of algebraic
numbers*, Lemma 4.1 and Theorem 4.2).  The square estimate below counts the
diagonal and paired off-diagonal contributions by binary induction.
-/

namespace FiniteMathKernels

/-- The number of one bits in a natural number, with weight zero at zero. -/
def binaryWeight (n : ℕ) : ℕ := (Nat.digits 2 n).sum

@[simp] theorem binaryWeight_zero : binaryWeight 0 = 0 := by
  simp [binaryWeight]

@[simp] theorem binaryWeight_one : binaryWeight 1 = 1 := by
  norm_num [binaryWeight, Nat.digits_of_lt]

/-- Appending a low zero bit preserves the number of one bits. -/
@[simp] theorem binaryWeight_two_mul (n : ℕ) :
    binaryWeight (2 * n) = binaryWeight n := by
  by_cases hn : n = 0
  · simp [hn]
  · unfold binaryWeight
    rw [Nat.digits_def' (by decide : 1 < 2) (by omega : 0 < 2 * n)]
    simp

/-- Appending a low one bit adds exactly one to the weight. -/
@[simp] theorem binaryWeight_two_mul_add_one (n : ℕ) :
    binaryWeight (2 * n + 1) = binaryWeight n + 1 := by
  unfold binaryWeight
  rw [Nat.digits_def' (by decide : 1 < 2) (by omega : 0 < 2 * n + 1)]
  simp [Nat.add_mod, Nat.add_div, Nat.add_comm]

/-- A successor can add at most one one bit; carries may remove others. -/
theorem binaryWeight_succ_le (n : ℕ) :
    binaryWeight (n + 1) ≤ binaryWeight n + 1 := by
  induction n using Nat.binaryRec with
  | zero => simp
  | bit b n ih =>
    cases b
    · simp [Nat.bit]
    · change binaryWeight (2 * n + 1 + 1) ≤ binaryWeight (2 * n + 1) + 1
      rw [show 2 * n + 1 + 1 = 2 * (n + 1) by omega]
      simp only [binaryWeight_two_mul, binaryWeight_two_mul_add_one]
      omega

/-- Carries cannot increase the total number of one bits of two summands. -/
theorem binaryWeight_add_le (m n : ℕ) :
    binaryWeight (m + n) ≤ binaryWeight m + binaryWeight n := by
  induction m using Nat.binaryRec generalizing n with
  | zero => simp
  | bit b m ih =>
    cases n using Nat.bitCasesOn with
    | bit c n =>
      cases b <;> cases c
      · change binaryWeight (2 * m + 2 * n) ≤
          binaryWeight (2 * m) + binaryWeight (2 * n)
        rw [show 2 * m + 2 * n = 2 * (m + n) by omega]
        simpa only [binaryWeight_two_mul] using ih n
      · change binaryWeight (2 * m + (2 * n + 1)) ≤
          binaryWeight (2 * m) + binaryWeight (2 * n + 1)
        rw [show 2 * m + (2 * n + 1) = 2 * (m + n) + 1 by omega]
        simp only [binaryWeight_two_mul, binaryWeight_two_mul_add_one]
        have h := ih n
        omega
      · change binaryWeight (2 * m + 1 + 2 * n) ≤
          binaryWeight (2 * m + 1) + binaryWeight (2 * n)
        rw [show 2 * m + 1 + 2 * n = 2 * (m + n) + 1 by omega]
        simp only [binaryWeight_two_mul, binaryWeight_two_mul_add_one]
        have h := ih n
        omega
      · change binaryWeight (2 * m + 1 + (2 * n + 1)) ≤
          binaryWeight (2 * m + 1) + binaryWeight (2 * n + 1)
        rw [show 2 * m + 1 + (2 * n + 1) = 2 * (m + n + 1) by omega]
        simp only [binaryWeight_two_mul, binaryWeight_two_mul_add_one]
        have h := ih n
        have hs := binaryWeight_succ_le (m + n)
        omega

/-- Multiplication by a power of two shifts the bits without changing weight. -/
@[simp] theorem binaryWeight_two_pow_mul (k n : ℕ) :
    binaryWeight (2 ^ k * n) = binaryWeight n := by
  induction k with
  | zero => simp
  | succ k ih =>
    rw [pow_succ', Nat.mul_assoc, binaryWeight_two_mul, ih]

@[simp] theorem binaryWeight_mul_two_pow (n k : ℕ) :
    binaryWeight (n * 2 ^ k) = binaryWeight n := by
  rw [Nat.mul_comm, binaryWeight_two_pow_mul]

/-- Dropping the lowest bit cannot increase binary weight. -/
theorem binaryWeight_div_two_le (n : ℕ) :
    binaryWeight (n / 2) ≤ binaryWeight n := by
  cases n using Nat.bitCasesOn with
  | bit b n =>
    cases b <;> simp [Nat.bit, Nat.add_div]

/-- Dropping any finite number of low bits cannot increase binary weight. -/
theorem binaryWeight_div_two_pow_le (n k : ℕ) :
    binaryWeight (n / 2 ^ k) ≤ binaryWeight n := by
  induction k with
  | zero => simp
  | succ k ih =>
    rw [pow_succ, ← Nat.div_div_eq_div_mul]
    exact (binaryWeight_div_two_le (n / 2 ^ k)).trans ih

/-- The number with exactly `k` consecutive low one bits has weight `k`. -/
@[simp] theorem binaryWeight_two_pow_sub_one (k : ℕ) :
    binaryWeight (2 ^ k - 1) = k := by
  induction k with
  | zero => simp
  | succ k ih =>
    have hp : 1 ≤ 2 ^ k := Nat.one_le_pow k 2 (by decide)
    have he : 2 ^ (k + 1) - 1 = 2 * (2 ^ k - 1) + 1 := by
      rw [pow_succ]
      omega
    rw [he, binaryWeight_two_mul_add_one, ih]

/-- Squaring uses at most one contribution for each diagonal or unordered pair
of one bits.  The factor two avoids natural-number division in the statement. -/
theorem binaryWeight_sq_le (n : ℕ) :
    2 * binaryWeight (n ^ 2) ≤ binaryWeight n * (binaryWeight n + 1) := by
  induction n using Nat.binaryRec with
  | zero => simp
  | bit b n ih =>
    cases b
    · change 2 * binaryWeight ((2 * n) ^ 2) ≤
        binaryWeight (2 * n) * (binaryWeight (2 * n) + 1)
      rw [show (2 * n) ^ 2 = 2 * (2 * n ^ 2) by ring]
      simpa only [binaryWeight_two_mul] using ih
    · change 2 * binaryWeight ((2 * n + 1) ^ 2) ≤
        binaryWeight (2 * n + 1) * (binaryWeight (2 * n + 1) + 1)
      rw [show (2 * n + 1) ^ 2 = 2 * (2 * (n ^ 2 + n)) + 1 by ring]
      simp only [binaryWeight_two_mul, binaryWeight_two_mul_add_one]
      have h := binaryWeight_add_le (n ^ 2) n
      nlinarith

end FiniteMathKernels
