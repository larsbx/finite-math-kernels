import Lean.Elab.Tactic.Omega
import Init.Data.Int.Pow

namespace FiniteMathKernels.BigZLimbs

/-- The value of a little-endian magnitude. -/
def magnitude (base : Nat) : List Nat → Nat
  | [] => 0
  | d :: ds => d + base * magnitude base ds

def Digits (base : Nat) (ds : List Nat) : Prop :=
  ds.all (fun d => decide (d < base)) = true

def Canonical (base : Nat) (sign : Int) (ds : List Nat) : Prop :=
  Digits base ds ∧ ds.getLast? ≠ some 0 ∧
    (if ds = [] then sign = 0 else sign = 1 ∨ sign = -1)

instance (base : Nat) (sign : Int) (ds : List Nat) : Decidable (Canonical base sign ds) :=
  by unfold Canonical Digits; infer_instance

def signedValue (base : Nat) (sign : Int) (ds : List Nat) : Int :=
  sign * (magnitude base ds : Int)

def trim : List Nat → List Nat
  | [] => []
  | d :: ds => if trim ds = [] ∧ d = 0 then [] else d :: trim ds

theorem trim_preserves_magnitude (base : Nat) (ds : List Nat) :
    magnitude base (trim ds) = magnitude base ds := by
  induction ds with
  | nil => rfl
  | cons d ds ih =>
    by_cases h : trim ds = [] ∧ d = 0
    · have hz : magnitude base ds = 0 := by simpa [h.1, magnitude] using ih.symm
      simp [trim, h, magnitude, hz]
    · simp [trim, h, magnitude, ih]

theorem trim_preserves_digits (base : Nat) (ds : List Nat) (h : Digits base ds) :
    Digits base (trim ds) := by
  induction ds with
  | nil => exact h
  | cons d ds ih =>
    simp only [Digits, List.all_cons, Bool.and_eq_true, decide_eq_true_eq] at h
    by_cases hz : trim ds = [] ∧ d = 0
    · simp [trim, hz, Digits]
    · simpa [trim, hz, Digits, h.1] using ih h.2

theorem trim_top_nonzero (ds : List Nat) : (trim ds).getLast? ≠ some 0 := by
  induction ds with
  | nil => simp [trim]
  | cons d ds ih =>
    cases ht : trim ds with
    | nil =>
      by_cases hd : d = 0 <;> simp [trim, ht, hd]
    | cons e es =>
      simpa [trim, ht] using ih

theorem trim_normalizes_magnitude (base : Nat) (ds : List Nat) (h : Digits base ds) :
    Canonical base (if trim ds = [] then 0 else 1) (trim ds) := by
  refine ⟨trim_preserves_digits base ds h, trim_top_nonzero ds, ?_⟩
  split <;> simp_all

theorem zero_padding_preserves_magnitude (base : Nat) (ds : List Nat) (n : Nat) :
    magnitude base (ds ++ List.replicate n 0) = magnitude base ds := by
  have zeros : magnitude base (List.replicate n 0) = 0 := by
    induction n with
    | zero => rfl
    | succ n ih => simp [List.replicate_succ, magnitude, ih]
  induction ds with
  | nil => simpa [magnitude] using zeros
  | cons d ds ih => simp [magnitude, ih]

theorem magnitude_pos_of_top_nonzero (base : Nat) (hbase : 0 < base) (ds : List Nat)
    (hne : ds ≠ []) (htop : ds.getLast? ≠ some 0) : 0 < magnitude base ds := by
  induction ds with
  | nil => contradiction
  | cons d ds ih =>
    cases ds with
    | nil =>
      simp [magnitude] at htop ⊢
      omega
    | cons e es =>
      have ht := ih (by simp) (by simpa using htop)
      have hp := Nat.mul_pos hbase ht
      change 0 < d + base * magnitude base (e :: es)
      omega

theorem canonical_magnitude_unique (base : Nat) (hbase : 0 < base) (a b : List Nat)
    (ha : Digits base a) (hb : Digits base b)
    (ta : a.getLast? ≠ some 0) (tb : b.getLast? ≠ some 0)
    (he : magnitude base a = magnitude base b) : a = b := by
  induction a generalizing b with
  | nil =>
    cases b with
    | nil => rfl
    | cons e es =>
      have hp := magnitude_pos_of_top_nonzero base hbase (e :: es) (by simp) tb
      have hz : magnitude base (e :: es) = 0 := he.symm
      omega
  | cons d ds ih =>
    cases b with
    | nil =>
      have hp := magnitude_pos_of_top_nonzero base hbase (d :: ds) (by simp) ta
      have hz : magnitude base (d :: ds) = 0 := he
      omega
    | cons e es =>
      simp only [Digits, List.all_cons, Bool.and_eq_true, decide_eq_true_eq] at ha hb
      have hd := congrArg (fun n : Nat => n % base) he
      simp [magnitude, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt ha.1, Nat.mod_eq_of_lt hb.1] at hd
      have ht : magnitude base ds = magnitude base es := by
        apply Nat.eq_of_mul_eq_mul_left hbase
        simp only [magnitude, hd] at he
        omega
      have hta : ds.getLast? ≠ some 0 := by cases ds <;> simp_all
      have htb : es.getLast? ≠ some 0 := by cases es <;> simp_all
      rw [hd, ih es ha.2 hb.2 hta htb ht]

/-- A list of aligned digit pairs, with missing high digits padded by zero. -/
def addDigits (base : Nat) : List (Nat × Nat) → Nat → List Nat
  | [], carry => if carry = 0 then [] else [carry]
  | (a,b) :: rest, carry =>
    let total := a + b + carry
    total % base :: addDigits base rest (total / base)

theorem add_digit_identity (base total : Nat) :
    total % base + base * (total / base) = total := Nat.mod_add_div total base

theorem add_magnitude_exact (base : Nat) (xs : List (Nat × Nat)) (carry : Nat) :
    magnitude base (addDigits base xs carry) =
      magnitude base (xs.map Prod.fst) + magnitude base (xs.map Prod.snd) + carry := by
  induction xs generalizing carry with
  | nil => by_cases h : carry = 0 <;> simp [addDigits, magnitude, h]
  | cons p xs ih =>
    rcases p with ⟨a,b⟩
    simp only [addDigits, List.map_cons, magnitude, ih]
    have h := add_digit_identity base (a + b + carry)
    simp only [Nat.mul_add]
    omega

theorem add_carry_at_most_one (base a b carry : Nat) (hbase : 0 < base)
    (ha : a < base) (hb : b < base) (hc : carry ≤ 1) :
    (a + b + carry) / base ≤ 1 := by
  apply Nat.lt_succ_iff.mp
  apply (Nat.div_lt_iff_lt_mul hbase).mpr
  omega

theorem add_digits_bounded (base : Nat) (hbase : 1 < base) (xs : List (Nat × Nat))
    (h : ∀ p ∈ xs, p.1 < base ∧ p.2 < base) (carry : Nat) (hc : carry ≤ 1) :
    Digits base (addDigits base xs carry) := by
  induction xs generalizing carry with
  | nil =>
    by_cases hz : carry = 0
    · simp [addDigits, Digits, hz]
    · simp [addDigits, Digits, hz, show carry < base by omega]
  | cons p xs ih =>
    rcases p with ⟨a,b⟩
    obtain ⟨ha,hb⟩ := h (a,b) (by simp)
    have ht := ih (fun p hp => h p (by simp [hp])) ((a+b+carry)/base)
      (add_carry_at_most_one base a b carry (by omega) ha hb hc)
    simpa [addDigits, Digits, Nat.mod_lt _ (show 0 < base by omega)] using ht

/-- Borrow transition matching the two branches of `bigz_abs_sub`. -/
def borrowDigit (base a b borrow : Nat) : Nat × Nat :=
  if b + borrow ≤ a then (a - (b + borrow), 0) else (a + base - (b + borrow), 1)

theorem borrow_digit_bounds (base a b borrow : Nat) (ha : a < base) (hb : b < base)
    (hc : borrow ≤ 1) :
    (borrowDigit base a b borrow).1 < base ∧ (borrowDigit base a b borrow).2 ≤ 1 := by
  unfold borrowDigit
  split <;> simp_all <;> omega

theorem borrow_digit_identity (base a b borrow : Nat) (hb : b < base) (hc : borrow ≤ 1) :
    ((borrowDigit base a b borrow).1 : Int) + b + borrow =
      (a : Int) + base * (borrowDigit base a b borrow).2 := by
  by_cases h : b + borrow ≤ a
  · simp [borrowDigit, h, Int.ofNat_sub h] <;> omega
  · have h' : b + borrow ≤ a + base := by omega
    simp [borrowDigit, h, Int.ofNat_sub h'] <;> omega

/-- The second component retains the outgoing borrow so underflow stays visible. -/
def subDigits (base : Nat) : List (Nat × Nat) → Nat → List Nat × Nat
  | [], borrow => ([], borrow)
  | (a,b) :: rest, borrow =>
    let digit := borrowDigit base a b borrow
    let tail := subDigits base rest digit.2
    (digit.1 :: tail.1, tail.2)

theorem sub_magnitude_balance (base : Nat) (xs : List (Nat × Nat))
    (h : ∀ p ∈ xs, p.1 < base ∧ p.2 < base) (borrow : Nat) (hb : borrow ≤ 1) :
    (magnitude base (subDigits base xs borrow).1 : Int) +
        magnitude base (xs.map Prod.snd) + borrow =
      (magnitude base (xs.map Prod.fst) : Int) + (base : Int)^xs.length * (subDigits base xs borrow).2 := by
  induction xs generalizing borrow with
  | nil => simp [subDigits, magnitude]
  | cons p xs ih =>
    rcases p with ⟨a,b⟩
    obtain ⟨ha,hb'⟩ := h (a,b) (by simp)
    have step := borrow_digit_identity base a b borrow hb' hb
    have tail := ih (fun p hp => h p (by simp [hp])) (borrowDigit base a b borrow).2
      (borrow_digit_bounds base a b borrow ha hb' hb).2
    simp only [subDigits, List.map_cons, magnitude, List.length_cons,
      Int.natCast_add, Int.natCast_mul, Int.pow_succ']
    have scaled := congrArg (fun z : Int => (base : Int) * z) tail
    simp only [Int.mul_add, ← Int.mul_assoc] at scaled
    omega

theorem sub_shape (base : Nat) (xs : List (Nat × Nat))
    (h : ∀ p ∈ xs, p.1 < base ∧ p.2 < base) (borrow : Nat) (hb : borrow ≤ 1) :
    (subDigits base xs borrow).1.length = xs.length ∧
      Digits base (subDigits base xs borrow).1 ∧ (subDigits base xs borrow).2 ≤ 1 := by
  induction xs generalizing borrow with
  | nil => simp [subDigits, Digits, hb]
  | cons p xs ih =>
    rcases p with ⟨a,b⟩
    obtain ⟨ha,hb'⟩ := h (a,b) (by simp)
    have step := borrow_digit_bounds base a b borrow ha hb' hb
    have tail := ih (fun p hp => h p (by simp [hp])) (borrowDigit base a b borrow).2 step.2
    simpa [subDigits, Digits, step.1] using tail

theorem magnitude_lt_width (base : Nat) (ds : List Nat) (h : Digits base ds) :
    magnitude base ds < base^ds.length := by
  induction ds with
  | nil => simp [magnitude]
  | cons d ds ih =>
    simp only [Digits, List.all_cons, Bool.and_eq_true, decide_eq_true_eq] at h
    have ht := ih h.2
    simp only [magnitude, List.length_cons, Nat.pow_succ']
    calc
      d + base * magnitude base ds < base + base * magnitude base ds := by omega
      _ = base * (magnitude base ds + 1) := by rw [Nat.mul_add, Nat.mul_one, Nat.add_comm]
      _ ≤ base * base^ds.length := Nat.mul_le_mul_left base (by omega)

theorem zero_final_borrow_iff (base : Nat) (xs : List (Nat × Nat))
    (h : ∀ p ∈ xs, p.1 < base ∧ p.2 < base) :
    (subDigits base xs 0).2 = 0 ↔ magnitude base (xs.map Prod.snd) ≤ magnitude base (xs.map Prod.fst) := by
  have shape := sub_shape base xs h 0 (by decide)
  have balance := sub_magnitude_balance base xs h 0 (by decide)
  have width := magnitude_lt_width base (subDigits base xs 0).1 shape.2.1
  rw [shape.1] at width
  have widthInt : (magnitude base (subDigits base xs 0).1 : Int) < (base : Int)^xs.length := by
    simpa only [Int.natCast_pow] using (Int.ofNat_lt.mpr width)
  rcases (show (subDigits base xs 0).2 = 0 ∨ (subDigits base xs 0).2 = 1 by omega) with hz | ho
  · simp [hz] at balance ⊢
    omega
  · simp [ho] at balance ⊢
    omega

theorem sub_magnitude_exact (base : Nat) (xs : List (Nat × Nat))
    (h : ∀ p ∈ xs, p.1 < base ∧ p.2 < base) (hz : (subDigits base xs 0).2 = 0) :
    magnitude base (trim (subDigits base xs 0).1) + magnitude base (xs.map Prod.snd) =
      magnitude base (xs.map Prod.fst) := by
  have hb := sub_magnitude_balance base xs h 0 (by decide)
  simp [hz] at hb
  rw [trim_preserves_magnitude]
  omega

/-- Arithmetic intermediates in carry/borrow addition fit the UInt64 carrier. -/
theorem native_addition_bound (a b carry : Nat) (ha : a < 10^9) (hb : b < 10^9)
    (hc : carry ≤ 1) : a + b + carry < 2^64 := by omega

theorem native_borrow_bound (a b borrow : Nat) (ha : a < 10^9) (hb : b < 10^9)
    (hc : borrow ≤ 1) : a + 10^9 < 2^64 ∧ b + borrow < 2^64 := by omega

end FiniteMathKernels.BigZLimbs
