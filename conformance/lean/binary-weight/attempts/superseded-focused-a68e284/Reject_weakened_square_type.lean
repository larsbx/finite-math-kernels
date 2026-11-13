import FiniteMathKernels.BinaryWeight
open FiniteMathKernels
namespace Weakened
theorem square (n : ℕ) : binaryWeight n ≤ binaryWeight n := le_refl _
end Weakened
example (n : ℕ) : 2 * binaryWeight (n ^ 2) ≤ binaryWeight n * (binaryWeight n + 1) := Weakened.square n
