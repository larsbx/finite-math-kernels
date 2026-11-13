import FiniteMathKernels.BinaryWeight
open FiniteMathKernels
example : 2 * binaryWeight (5 ^ 2) ≤ binaryWeight 5 ^ 2 := by decide
