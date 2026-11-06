import FiniteMathKernels.Words
import FiniteMathKernels.CheckedInt

namespace FiniteMathKernels.MachineWords
open Words

/- A partial, bounded semantic model. This is not a refinement theorem for
Mojo memory, loops or the compiler. Dimensions and valid indices are separate
native preconditions. Every counter is a natural number in this model. -/
def FitsSummary {α : Type*} (s : Summary α) : Prop :=
  (∀ i, (s.letters i : ℤ) ≤ CheckedInt.upper64) ∧
  (∀ i j, (s.pairs i j : ℤ) ≤ CheckedInt.upper64) ∧
  (∀ i j k, (s.triples i j k : ℤ) ≤ CheckedInt.upper64)

noncomputable def run {α : Type*} [DecidableEq α]
    (s : Summary α) : Word α → Option (Summary α)
  | [] => some s
  | c :: w => by
      classical
      exact if FitsSummary (step s c) then run (step s c) w else none

def Within {α : Type*} [DecidableEq α] (s : Summary α) : Word α → Prop
  | [] => True
  | c :: w => FitsSummary (step s c) ∧ Within (step s c) w

theorem run_success_exact {α : Type*} [DecidableEq α]
    (w : Word α) (s t : Summary α) (h : run s w = some t) :
    t = w.foldl step s := by
  induction w generalizing s with
  | nil => simpa [run] using h.symm
  | cons c w ih =>
    classical
    simp only [run] at h
    split_ifs at h with hf
    · exact ih (step s c) h

theorem run_complete_iff {α : Type*} [DecidableEq α]
    (w : Word α) (s : Summary α) :
    run s w = some (w.foldl step s) ↔ Within s w := by
  induction w generalizing s with
  | nil => simp [run, Within]
  | cons c w ih =>
    classical
    by_cases hf : FitsSummary (step s c)
    · simpa [run, Within, hf] using ih (step s c)
    · simp [run, Within, hf]

theorem stream_success_exact {α : Type*} [DecidableEq α]
    (w : Word α) (t : Summary α) (h : run (summary []) w = some t) :
    t = summary w := by
  have he := run_success_exact w (summary []) t h
  change t = stream w at he
  exact he.trans (stream_correct w)

theorem run_refuses_iff {α : Type*} [DecidableEq α]
    (w : Word α) (s : Summary α) : run s w = none ↔ ¬ Within s w := by
  constructor
  · intro h hn
    have hc := (run_complete_iff w s).mpr hn
    rw [h] at hc
    contradiction
  · intro hn
    cases h : run s w with
    | none => rfl
    | some t =>
      have he := run_success_exact w s t h
      rw [he] at h
      exact False.elim (hn ((run_complete_iff w s).mp h))

theorem difference_fits (a b : ℤ) (ha : 0 ≤ a) (hb : 0 ≤ b)
    (ha' : a ≤ CheckedInt.upper64) (hb' : b ≤ CheckedInt.upper64) :
    CheckedInt.Fits CheckedInt.lower64 CheckedInt.upper64 (a-b) := by
  norm_num [CheckedInt.Fits, CheckedInt.lower64, CheckedInt.upper64] at *
  omega

end FiniteMathKernels.MachineWords
