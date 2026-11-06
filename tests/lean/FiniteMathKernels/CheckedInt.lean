import Mathlib.Tactic

namespace FiniteMathKernels.CheckedInt
def Fits (lo hi x : ℤ) : Prop := lo ≤ x ∧ x ≤ hi
def accept (lo hi x : ℤ) : Option ℤ := if lo ≤ x ∧ x ≤ hi then some x else none
def lower64 : ℤ := -(2^63)
def upper64 : ℤ := 2^63-1
def accept64 (x : ℤ) : Option ℤ := accept lower64 upper64 x

theorem accept_exact (lo hi x y : ℤ) (h : accept lo hi x = some y) :
    x = y ∧ Fits lo hi y := by
  unfold accept at h
  split at h
  · simp_all [Fits]
  · contradiction
theorem accept_complete (lo hi x : ℤ) (h : Fits lo hi x) : accept lo hi x = some x := by
  simp [accept,Fits] at *
theorem accept_refuses_iff (lo hi x : ℤ) : accept lo hi x = none ↔ ¬ Fits lo hi x := by
  simp [accept,Fits]

/- These guards follow the source branch structure, interpreted in integers.
The input-fit hypotheses are essential: callers supply actual machine Ints. -/
def addGuard (lo hi a b : ℤ) : Prop := (0 < b ∧ hi-b < a) ∨ (b < 0 ∧ a < lo-b)
def subGuard (lo hi a b : ℤ) : Prop := (0 < b ∧ a < lo+b) ∨ (b < 0 ∧ hi+b < a)
theorem add_guard_exact (lo hi a b : ℤ) (ha : Fits lo hi a) (hb : Fits lo hi b) :
    addGuard lo hi a b ↔ ¬ Fits lo hi (a+b) := by
  unfold addGuard Fits at *
  omega
theorem sub_guard_exact (lo hi a b : ℤ) (ha : Fits lo hi a) (hb : Fits lo hi b) :
    subGuard lo hi a b ↔ ¬ Fits lo hi (a-b) := by
  unfold subGuard Fits at *
  omega
theorem add_success_exact (a b y : ℤ) (h : accept64 (a+b) = some y) :
    y = a+b ∧ Fits lower64 upper64 y := by
  obtain ⟨he,hf⟩ := accept_exact lower64 upper64 (a+b) y h
  exact ⟨he.symm,hf⟩
theorem sub_success_exact (a b y : ℤ) (h : accept64 (a-b) = some y) :
    y = a-b ∧ Fits lower64 upper64 y := by
  obtain ⟨he,hf⟩ := accept_exact lower64 upper64 (a-b) y h
  exact ⟨he.symm,hf⟩
theorem mul_success_exact (a b y : ℤ) (h : accept64 (a*b) = some y) :
    y = a*b ∧ Fits lower64 upper64 y := by
  obtain ⟨he,hf⟩ := accept_exact lower64 upper64 (a*b) y h
  exact ⟨he.symm,hf⟩
theorem neg_guard_exact (a : ℤ) (h : Fits lower64 upper64 a) :
    a = lower64 ↔ ¬ Fits lower64 upper64 (-a) := by
  norm_num [Fits,lower64,upper64] at *
  omega
theorem abs_guard_exact (a : ℤ) (h : Fits lower64 upper64 a) :
    a = lower64 ↔ ¬ Fits lower64 upper64 |a| := by
  by_cases ha : 0 ≤ a
  · rw [abs_of_nonneg ha]
    norm_num [Fits,lower64,upper64] at *
    omega
  · rw [abs_of_neg (by omega : a < 0)]
    exact neg_guard_exact a h

/- The unsigned-magnitude division test used by checked_mul is proved without
machine arithmetic. Its binding to signed magnitudes remains a separate duty. -/
theorem magnitude_guard_exact (a b limit : ℕ) (hb : 0 < b) :
    limit / b < a ↔ limit < a*b := by
  exact Nat.div_lt_iff_lt_mul hb

theorem negative_minimum_times_one : accept64 (lower64 * 1) = some lower64 := by
  norm_num [accept64,accept,Fits,lower64,upper64]
theorem reject_negative_minimum_negation : accept64 (-lower64) = none := by
  norm_num [accept64,accept,lower64,upper64]
theorem reject_wrapped_maximum : accept64 (upper64+1) ≠ some lower64 := by
  norm_num [accept64,accept,lower64,upper64]

end FiniteMathKernels.CheckedInt
