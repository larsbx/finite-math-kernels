import FiniteMathKernels
open FiniteMathKernels
example : CheckedInt.accept64 ((0 : ℕ).choose 3) = some (0 : ℤ) ∧ (0 : ℕ).choose 2 = 0 ∧ 0 = 0 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((1 : ℕ).choose 3) = some (0 : ℤ) ∧ (1 : ℕ).choose 2 = 0 ∧ 1 = 1 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((2 : ℕ).choose 3) = some (0 : ℤ) ∧ (2 : ℕ).choose 2 = 1 ∧ 2 = 2 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((3810778 : ℕ).choose 3) = some (9223364155031292776 : ℤ) ∧ (3810778 : ℕ).choose 2 = 7261012577253 ∧ 3810778 = 3810778 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((3810779 : ℕ).choose 3) = some (9223371416043870029 : ℤ) ∧ (3810779 : ℕ).choose 2 = 7261016388031 ∧ 3810779 = 3810779 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((3810780 : ℕ).choose 3) = none ∧ (3810780 : ℕ).choose 2 = 7261020198810 ∧ 3810780 = 3810780 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((4000000 : ℕ).choose 3) = none ∧ (4000000 : ℕ).choose 2 = 7999998000000 ∧ 4000000 = 4000000 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((3810779 : ℕ).choose 3) = some (9223371416043870029 : ℤ) ∧ (3810779 : ℕ).choose 2 = 7261016388031 ∧ 3810779 = 3810779 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 ((3810780 : ℕ).choose 3) = none ∧ (3810780 : ℕ).choose 2 = 7261020198810 ∧ 3810780 = 3810780 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (9223372036854775805+1) = some (9223372036854775806 : ℤ) := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (9223372036854775806+1) = some (9223372036854775807 : ℤ) := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (9223372036854775807+1) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : ((3810779 : ℕ).choose 3 : ℤ)-1 = 9223371416043870028 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : 1-((3810779 : ℕ).choose 3 : ℤ) = -9223371416043870028 := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (((3810780 : ℕ).choose 3 : ℤ)) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (((3810780 : ℕ).choose 3 : ℤ)) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (((3810780 : ℕ).choose 3 : ℤ)) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (9223372036854775807 * 9223372036854775807) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
example : CheckedInt.accept64 (3000000^3) = none := by
  norm_num [CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64, Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial]
