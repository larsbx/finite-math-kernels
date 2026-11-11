import FiniteMathKernels.Words
import FiniteMathKernels.CheckedInt

namespace FiniteMathKernels.CounterBounds
theorem last_constant_count_fits :
    (3810779 : ℕ).choose 3 = 9223371416043870029 ∧
    CheckedInt.accept64 9223371416043870029 = some 9223371416043870029 := by
  norm_num [Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial,
    CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64]
theorem next_constant_count_refused :
    (3810780 : ℕ).choose 3 = 9223378677060258060 ∧
    CheckedInt.accept64 9223378677060258060 = none := by
  norm_num [Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial,
    CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64]
theorem n2_constant_boundary :
    (4294967296 : ℕ).choose 2 = 9223372034707292160 ∧
    (4294967297 : ℕ).choose 2 = 9223372039002259456 ∧
    CheckedInt.accept64 9223372034707292160 = some 9223372034707292160 ∧
    CheckedInt.accept64 9223372039002259456 = none := by
  norm_num [Nat.choose_eq_descFactorial_div_factorial, Nat.descFactorial, Nat.factorial,
    CheckedInt.accept64, CheckedInt.accept, CheckedInt.lower64, CheckedInt.upper64]
theorem stress_model_count {α : Type*} [DecidableEq α] (a : α) :
    Words.triples (List.replicate 4000000 a) a a a = 10666658666668000000 := by
  rw [Words.triples_replicate_self,Nat.choose_eq_descFactorial_div_factorial]
  norm_num [Nat.descFactorial,Nat.factorial]
theorem stress_count_does_not_fit :
    ¬ CheckedInt.Fits CheckedInt.lower64 CheckedInt.upper64 10666658666668000000 := by
  norm_num [CheckedInt.Fits,CheckedInt.lower64,CheckedInt.upper64]
theorem observed_negative_cannot_be_count (w : List ℕ) :
    (Words.triples w 0 0 0 : ℤ) ≠ -7780085407041551616 := by
  have h := Int.natCast_nonneg (Words.triples w 0 0 0)
  omega
end FiniteMathKernels.CounterBounds
