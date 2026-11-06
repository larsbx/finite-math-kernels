import FiniteMathKernels
open FiniteMathKernels
example : AcceptedField.eqAccepted (none : Option (ZMod 7)) none = true := by decide
