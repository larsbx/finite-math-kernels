import FiniteMathKernels.Words
import FiniteMathKernels.CheckedInt
import FiniteMathKernels.AcceptedField

namespace FiniteMathKernels.Conformance
open Words
def parikhVector (size : ℕ) (w : List ℕ) : List ℕ :=
  (List.range size).map (parikh w)
def pairVector (size : ℕ) (w : List ℕ) : List ℕ :=
  (List.range size).flatMap fun i => (List.range size).map (pairs w i)
def tripleVector (size : ℕ) (w : List ℕ) : List ℕ :=
  (List.range size).flatMap fun i => (List.range size).flatMap fun j =>
    (List.range size).map (triples w i j)
def substitution (images : List (List ℕ)) (c : ℕ) : List ℕ := images[c]?.getD []
def incidenceVector (images : List (List ℕ)) : List ℕ :=
  (List.range images.length).flatMap fun i =>
    (List.range images.length).map fun j => incidence (substitution images) i j
def prefixLengths (images : List (List ℕ)) (w : List ℕ) : List ℕ :=
  (List.range (w.length+1)).map fun k => (inflate (substitution images) (w.take k)).length
def zeroReturns (size : ℕ) (u v : List ℕ) : List ℕ :=
  (List.range (u.length+1)).filter fun k => parikhVector size (u.take k) == parikhVector size (v.take k)
end FiniteMathKernels.Conformance
