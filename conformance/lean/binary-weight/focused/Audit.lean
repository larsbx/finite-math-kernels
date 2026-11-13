import FiniteMathKernels.BinaryWeight
import FiniteMathKernels.BinaryWeightContracts
import BinaryWeightControls
import Lean.Elab.Command
import Lean.Util.CollectAxioms
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let targets : Array Name := #[`FiniteMathKernels.BinaryWeight, `FiniteMathKernels.BinaryWeightContracts, `BinaryWeightControls]
  let allowed := #[`propext, `Classical.choice, `Quot.sound]
  for moduleName in targets do
    let some idx := env.getModuleIdx? moduleName | throwError "Missing audited module"
    let data := env.header.moduleData[idx.toNat]!
    for info in data.constants do
      if info.isAxiom then throwError "Local audited axiom"
    let mut count := 0
    let mut proofs := 0
    for info in data.constants do
      let name := info.name
      let axs ← collectAxioms name
      for ax in axs do
        if !allowed.contains ax then throwError "Nonstandard transitive axiom"
      count := count + 1
      if info.isTheorem then proofs := proofs + 1
      let names := String.intercalate "," (axs.toList.map toString)
      liftIO <| IO.println s!"FMK_AXIOMS	{moduleName}	{name}	{info.isTheorem}	{names}"
    if proofs == 0 then throwError "Missing compiled proofs"
    liftIO <| IO.println s!"FMK_COMPLETE	{moduleName}	{count}	{proofs}"

#check FiniteMathKernels.BinaryWeightContracts.zero
#check FiniteMathKernels.BinaryWeightContracts.one
#check FiniteMathKernels.BinaryWeightContracts.lowZero
#check FiniteMathKernels.BinaryWeightContracts.lowOne
#check FiniteMathKernels.BinaryWeightContracts.successor
#check FiniteMathKernels.BinaryWeightContracts.addition
#check FiniteMathKernels.BinaryWeightContracts.leftShift
#check FiniteMathKernels.BinaryWeightContracts.rightFactor
#check FiniteMathKernels.BinaryWeightContracts.dropBit
#check FiniteMathKernels.BinaryWeightContracts.dropBits
#check FiniteMathKernels.BinaryWeightContracts.lowOnes
#check FiniteMathKernels.BinaryWeightContracts.square
