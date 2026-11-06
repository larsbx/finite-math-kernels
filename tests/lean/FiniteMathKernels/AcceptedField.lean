import Mathlib.Data.ZMod.Basic
import Mathlib.Tactic

/-! Accepted-only field semantics, including sticky rejection. Option equality
is deliberately NOT the runtime equality: two refusals must compare false. -/
namespace FiniteMathKernels.AcceptedField
variable {K : Type*} [Field K] [DecidableEq K]
def add (a b : Option K) : Option K := do return (← a) + (← b)
def mul (a b : Option K) : Option K := do return (← a) * (← b)
def inv (a : Option K) : Option K := do
  let x ← a
  if x = 0 then none else some x⁻¹
def div (a b : Option K) : Option K := mul a (inv b)
def eqAccepted (a b : Option K) : Bool :=
  match a,b with | some x,some y => decide (x=y) | _,_ => false

@[simp] theorem add_rejected_left (b : Option K) : add none b = none := rfl
@[simp] theorem mul_rejected_left (b : Option K) : mul none b = none := rfl
@[simp] theorem add_rejected_right (a : Option K) : add a none = none := by cases a <;> rfl
@[simp] theorem mul_rejected_right (a : Option K) : mul a none = none := by cases a <;> rfl
@[simp] theorem inverse_rejected : inv (none : Option K) = none := rfl
@[simp] theorem inverse_zero : inv (some (0 : K)) = none := by simp [inv]
theorem inverse_nonzero (a : K) (ha : a ≠ 0) : inv (some a) = some a⁻¹ := by simp [inv,ha]
theorem inverse_sound (a : K) (ha : a ≠ 0) : mul (some a) (inv (some a)) = some 1 := by
  simp [mul,inverse_nonzero a ha,ha]
theorem division_zero (a : Option K) : div a (some 0) = none := by simp [div]
theorem division_cancel (a b : K) (hb : b ≠ 0) :
    mul (div (some a) (some b)) (some b) = some a := by
  simp [div,mul,inverse_nonzero b hb,mul_assoc,hb]
theorem rejection_compares_false : eqAccepted (none : Option K) none = false := rfl
theorem rejected_not_runtime_reflexive : eqAccepted (none : Option K) none ≠ true := by simp [eqAccepted]
theorem accepted_equality (a b : K) : eqAccepted (some a) (some b) = true ↔ a = b := by
  simp [eqAccepted]
theorem zero_does_not_mask_rejection : mul (some (0 : K)) none = none := rfl

/- Mathematical field instances; primality and Euclidean-loop refinement of
fp.mojo and limb/normalisation refinement of rat_q.mojo are not supplied here. -/
theorem rational_inverse (a : ℚ) (ha : a ≠ 0) : mul (some a) (inv (some a)) = some 1 :=
  inverse_sound a ha
theorem prime_field_inverse (p : ℕ) [Fact p.Prime] (a : ZMod p) (ha : a ≠ 0) :
    mul (some a) (inv (some a)) = some 1 := inverse_sound a ha

end FiniteMathKernels.AcceptedField
