import FiniteMathKernels.Words
import FiniteMathKernels.CheckedInt

namespace FiniteMathKernels.CounterBounds
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
