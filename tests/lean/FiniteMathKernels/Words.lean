import Mathlib.Data.List.Perm.Basic
import Mathlib.Tactic

/-! Alphabet-generic mathematical semantics. Native Mojo conformance is a
separate, finite gate; this file does not assert a compiler refinement. -/
namespace FiniteMathKernels.Words
variable {α : Type*} [DecidableEq α]
abbrev Word (α : Type*) := List α
abbrev Substitution (α : Type*) := α → Word α

def parikh (w : Word α) (c : α) : ℕ := w.count c
def Balanced (u v : Word α) : Prop := ∀ c, parikh u c = parikh v c
def inflate (σ : Substitution α) (w : Word α) : Word α := w.flatMap σ
def iterate (σ : Substitution α) : ℕ → Word α → Word α
  | 0, w => w
  | n+1, w => inflate σ (iterate σ n w)

@[simp] theorem parikh_nil (c : α) : parikh [] c = 0 := rfl
@[simp] theorem parikh_append (u v : Word α) (c : α) :
    parikh (u ++ v) c = parikh u c + parikh v c := List.count_append
theorem parikh_cons (a c : α) (w : Word α) :
    parikh (a :: w) c = parikh w c + if a = c then 1 else 0 := by
  by_cases h : a = c <;> simp [parikh,List.count_cons,h]
@[simp] theorem parikh_singleton (a c : α) : parikh [a] c = if a = c then 1 else 0 := by
  simp [parikh_cons]
@[simp] theorem inflate_nil (σ : Substitution α) : inflate σ [] = [] := rfl
@[simp] theorem inflate_cons (σ : Substitution α) (c : α) (w : Word α) :
    inflate σ (c :: w) = σ c ++ inflate σ w := rfl
@[simp] theorem inflate_singleton (σ : Substitution α) (c : α) : inflate σ [c] = σ c := by
  simp
@[simp] theorem inflate_append (σ : Substitution α) (u v : Word α) :
    inflate σ (u ++ v) = inflate σ u ++ inflate σ v := List.flatMap_append
@[simp] theorem iterate_nil (σ : Substitution α) (n : ℕ) : iterate σ n [] = [] := by
  induction n <;> simp_all [iterate]
@[simp] theorem iterate_append (σ : Substitution α) (n : ℕ) (u v : Word α) :
    iterate σ n (u ++ v) = iterate σ n u ++ iterate σ n v := by
  induction n <;> simp_all [iterate]
theorem iterate_add (σ : Substitution α) (n k : ℕ) (w : Word α) :
    iterate σ (n+k) w = iterate σ k (iterate σ n w) := by
  induction k with
  | zero => rfl
  | succ k ih =>
    change inflate σ (iterate σ (n+k) w) = inflate σ (iterate σ k (iterate σ n w))
    rw [ih]

theorem balanced_iff_perm (u v : Word α) : Balanced u v ↔ u.Perm v := by
  simp only [Balanced,parikh,List.perm_iff_count]
theorem balanced_length {u v : Word α} (h : Balanced u v) : u.length = v.length :=
  ((balanced_iff_perm _ _).1 h).length_eq
theorem balanced_inflate (σ : Substitution α) {u v : Word α} (h : Balanced u v) :
    Balanced (inflate σ u) (inflate σ v) :=
  (balanced_iff_perm _ _).2 (((balanced_iff_perm _ _).1 h).flatMap_right σ)
theorem balanced_iterate (σ : Substitution α) (n : ℕ) {u v : Word α} (h : Balanced u v) :
    Balanced (iterate σ n u) (iterate σ n v) := by
  induction n with
  | zero => exact h
  | succ n ih => exact balanced_inflate σ ih
theorem balanced_image_length (σ : Substitution α) {u v : Word α} (h : Balanced u v) :
    (inflate σ u).length = (inflate σ v).length := balanced_length (balanced_inflate σ h)

/- Incidence orientation is output row, input column, as in substitution.mojo. -/
def incidence (σ : Substitution α) (row col : α) : ℕ := parikh (σ col) row
theorem parikh_inflate [Fintype α] (σ : Substitution α) (w : Word α) (c : α) :
    parikh (inflate σ w) c = ∑ a, parikh w a * incidence σ c a := by
  induction w with
  | nil => simp
  | cons a w ih =>
    simp only [inflate_cons,parikh_append,ih,parikh_cons,Nat.add_mul,Finset.sum_add_distrib]
    simp [incidence,Nat.add_comm]

/- Reference scattered-subword counts choose strictly increasing positions.
For a head position, either skip it or use it as the first selected letter. -/
def pairs : Word α → α → α → ℕ
  | [], _, _ => 0
  | a :: w, i, j => pairs w i j + if a = i then parikh w j else 0
def triples : Word α → α → α → α → ℕ
  | [], _, _, _ => 0
  | a :: w, i, j, k => triples w i j k + if a = i then pairs w j k else 0
theorem pairs_snoc (w : Word α) (c i j : α) :
    pairs (w ++ [c]) i j = pairs w i j + if c = j then parikh w i else 0 := by
  induction w with
  | nil => simp [pairs]
  | cons a w ih =>
    by_cases ha : a = i <;> by_cases hc : c = j <;>
      simp [pairs,ih,parikh_append,parikh_cons,ha,hc] <;> omega
theorem triples_snoc (w : Word α) (c i j k : α) :
    triples (w ++ [c]) i j k = triples w i j k + if c = k then pairs w i j else 0 := by
  induction w with
  | nil => simp [triples,pairs]
  | cons a w ih =>
    by_cases ha : a = i <;> by_cases hc : c = k <;>
      simp [triples,pairs_snoc,pairs,ih,ha,hc] <;> omega

@[ext] structure Summary (α : Type*) where
  letters : α → ℕ
  pairs : α → α → ℕ
  triples : α → α → α → ℕ
def summary (w : Word α) : Summary α := ⟨parikh w,pairs w,triples w⟩
def step (s : Summary α) (c : α) : Summary α :=
  ⟨fun i => s.letters i + if c = i then 1 else 0,
   fun i j => s.pairs i j + if c = j then s.letters i else 0,
   fun i j k => s.triples i j k + if c = k then s.pairs i j else 0⟩
theorem summary_snoc (w : Word α) (c : α) : summary (w ++ [c]) = step (summary w) c := by
  apply Summary.ext
  · funext i; simp [summary,step]
  · funext i j; exact pairs_snoc w c i j
  · funext i j k; exact triples_snoc w c i j k
theorem fold_summary (u v : Word α) : v.foldl step (summary u) = summary (u ++ v) := by
  induction v generalizing u with
  | nil => simp
  | cons a v ih =>
    rw [List.foldl_cons,← summary_snoc,ih]
    simp [List.append_assoc]
def stream (w : Word α) : Summary α := w.foldl step (summary [])
theorem stream_correct (w : Word α) : stream w = summary w := by
  simpa [stream] using fold_summary ([] : Word α) w

def Nonerasing (σ : Substitution α) : Prop := ∀ c, σ c ≠ []
def Witness (u v : Word α) : Prop :=
  ∃ p q : Word α, ∃ c : α,
    Balanced p q ∧ (p ++ [c]).IsPrefix u ∧ (q ++ [c]).IsPrefix v
theorem prefix_inflate (σ : Substitution α) {u v : Word α} (h : u.IsPrefix v) :
    (inflate σ u).IsPrefix (inflate σ v) := by
  rcases h with ⟨r,hr⟩
  exact ⟨inflate σ r,by simpa only [← inflate_append] using congrArg (inflate σ) hr⟩
theorem witness_inflate (σ : Substitution α) (hne : Nonerasing σ)
    {u v : Word α} (h : Witness u v) : Witness (inflate σ u) (inflate σ v) := by
  rcases h with ⟨p,q,c,hb,hp,hq⟩
  obtain ⟨d,r,hd⟩ : ∃ d r, σ c = d :: r := by
    cases hc : σ c with
    | nil => exact False.elim (hne c hc)
    | cons d r => exact ⟨d,r,rfl⟩
  have hh (w : Word α) : (inflate σ w ++ [d]).IsPrefix (inflate σ (w ++ [c])) := by
    refine ⟨r,?_⟩
    simp [hd,List.append_assoc]
  exact ⟨inflate σ p,inflate σ q,d,balanced_inflate σ hb,
    (hh p).trans (prefix_inflate σ hp),(hh q).trans (prefix_inflate σ hq)⟩
theorem witness_iterate (σ : Substitution α) (hne : Nonerasing σ) (n : ℕ)
    {u v : Word α} (h : Witness u v) : Witness (iterate σ n u) (iterate σ n v) := by
  induction n with
  | zero => exact h
  | succ n ih => exact witness_inflate σ hne ih

end FiniteMathKernels.Words
