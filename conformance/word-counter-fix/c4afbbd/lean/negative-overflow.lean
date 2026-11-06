import FiniteMathKernels
open FiniteMathKernels
example : CheckedInt.accept64 (CheckedInt.upper64+1) = some CheckedInt.lower64 := by decide
